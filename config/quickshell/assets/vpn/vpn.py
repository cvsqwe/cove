#!/usr/bin/env python3
"""Cove VPN — конфиг для ядра Mihomo (services/Vpn.qml).

vpn.py gen            JSON настроек на stdin → ~/.local/state/cove/vpn/config.yaml; печатает {"ok", "secret", "port"}
vpn.py secret         печатает секрет контроллера (создаёт при первом запуске)
vpn.py scan-prizrak   подписки и профили Prizrak-Box: [{"name", "url"} | {"name", "path"}]

Источники (settings.vpn.sources):
  {"name": "Мой VPN", "url": "https://…"}   — подписка: Mihomo сам качает и обновляет (proxy-providers),
                                              понимает и Clash YAML, и списки ссылок vless:// vmess:// …
  {"name": "Профиль", "path": "/…/x.yaml"}  — готовый конфиг Clash: берём из него только серверы
Маршрут (settings.vpn.route): "ru" — российские сайты напрямую, остальное через VPN; "all" — всё через VPN.
"""
import json
import os
import re
import secrets
import shutil
import sys

import yaml

HOME = os.path.expanduser("~")
DIR = os.path.join(HOME, ".local/state/cove/vpn")
CONTROLLER = "127.0.0.1:9097"
MIXED_PORT = 7897
GROUP = "VPN"
AUTO = "Авто"
TEST_URL = "https://www.gstatic.com/generate_204"
PRIZRAK = os.path.join(HOME, "Prizrak-Box-V3")


def secret():
    os.makedirs(DIR, exist_ok=True)
    path = os.path.join(DIR, "secret")
    if not os.path.exists(path):
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(secrets.token_urlsafe(24))
    return open(path).read().strip()


def slug(name, used):
    s = re.sub(r"[^A-Za-z0-9_-]+", "-", name).strip("-").lower() or "sub"
    base, n = s, 2
    while s in used:
        s, n = f"{base}-{n}", n + 1
    used.add(s)
    return s


def proxies_from_file(path):
    try:
        data = yaml.safe_load(open(os.path.expanduser(path))) or {}
    except Exception:
        return [], {}
    proxies = [p for p in (data.get("proxies") or []) if isinstance(p, dict) and p.get("name")]
    providers = data.get("proxy-providers") or {}
    return proxies, providers if isinstance(providers, dict) else {}


def read_first(*paths):
    for p in paths:
        try:
            v = open(p).read().strip()
        except OSError:
            continue
        if v:
            return v
    return ""


def device_headers():
    # Remnawave и похожие панели с привязкой к устройству без x-hwid отвечают 404.
    # Значения те же, что шлёт Prizrak-Box (machine-id), чтобы не занимать второй слот устройства.
    h = {"User-Agent": ["clash.meta", "mihomo"]}
    hwid = read_first("/etc/machine-id", "/var/lib/dbus/machine-id")
    if hwid:
        h["x-hwid"] = [hwid]
        h["x-device-os"] = ["Linux"]
        h["x-ver-os"] = [os.uname().release]
        model = read_first("/sys/devices/virtual/dmi/id/product_name", "/sys/devices/virtual/dmi/id/board_name")
        if model:
            h["x-device-model"] = [model]
    return h


def geodata():
    # базы стран для правила «Россия напрямую»: берём у Prizrak-Box, если есть, иначе Mihomo скачает сам
    for name in ("geoip.metadb", "ASN.mmdb"):
        src, dst = os.path.join(PRIZRAK, name), os.path.join(DIR, name)
        if os.path.exists(src) and not os.path.exists(dst):
            try:
                shutil.copyfile(src, dst)
            except OSError:
                pass


def gen(s):
    os.makedirs(DIR, exist_ok=True)
    os.makedirs(os.path.join(DIR, "providers"), exist_ok=True)
    key = secret()
    used, providers, proxies = set(), {}, []
    for src in s.get("sources") or []:
        if src.get("enabled") is False:
            continue
        name = src.get("name") or "VPN"
        if src.get("url"):
            sid = slug(name, used)
            providers[sid] = {
                "type": "http",
                "url": src["url"],
                "path": f"./providers/{sid}.yaml",
                "interval": 3600,
                # многие панели (Marzban, 3x-ui, Remnawave) по такому User-Agent отдают формат Clash
                "header": device_headers(),
                "health-check": {"enable": True, "url": TEST_URL, "interval": 600, "timeout": 4000, "lazy": True},
            }
        elif src.get("path"):
            px, pv = proxies_from_file(src["path"])
            names = {p["name"] for p in proxies}
            proxies += [p for p in px if p["name"] not in names]
            for k, v in pv.items():
                if isinstance(v, dict) and v.get("url"):
                    sid = slug(f"{name}-{k}", used)
                    v = dict(v, path=f"./providers/{sid}.yaml")
                    v["header"] = {**device_headers(), **(v.get("header") or {})}
                    providers[sid] = v

    rules = ["GEOIP,private,DIRECT,no-resolve", "DOMAIN-SUFFIX,local,DIRECT"]
    if s.get("route", "ru") == "ru":
        rules += ["DOMAIN-SUFFIX,ru,DIRECT", "DOMAIN-SUFFIX,su,DIRECT", "DOMAIN-SUFFIX,xn--p1ai,DIRECT",
                  "GEOIP,RU,DIRECT"]
    for d in s.get("direct") or []:   # свои «всегда напрямую»
        d = str(d).strip()
        if d:
            rules.append(f"DOMAIN-SUFFIX,{d},DIRECT")
    rules.append(f"MATCH,{GROUP}")

    has = bool(proxies or providers)
    cfg = {
        "mixed-port": MIXED_PORT,
        "allow-lan": False,
        "bind-address": "127.0.0.1",
        "mode": "rule",
        "log-level": "warning",
        "ipv6": False,
        "unified-delay": True,
        "tcp-concurrent": True,
        "find-process-mode": "off",
        "external-controller": CONTROLLER,
        "secret": key,
        "geodata-mode": False,      # GEOIP по базе MMDB (geoip.metadb), GeoSite не нужен
        "geo-auto-update": True,
        "geo-update-interval": 168,
        "profile": {"store-selected": True, "store-fake-ip": True},
        "sniffer": {"enable": True, "sniff": {"HTTP": {"ports": [80, "8080-8880"]}, "TLS": {"ports": [443, 8443]}, "QUIC": {"ports": [443]}}},
        "tun": {
            "enable": True,
            "stack": "mixed",
            "auto-route": True,
            "auto-redirect": True,
            "auto-detect-interface": True,
            "strict-route": False,
            "dns-hijack": ["any:53", "tcp://any:53"],
        },
        "dns": {
            "enable": True,
            "ipv6": False,
            "enhanced-mode": "fake-ip",
            "fake-ip-range": "198.18.0.1/16",
            "fake-ip-filter": ["*.lan", "*.local", "+.msftconnecttest.com", "+.msftncsi.com", "time.*.com", "ntp.*.com"],
            "default-nameserver": ["77.88.8.8", "1.1.1.1"],
            "nameserver": ["https://1.1.1.1/dns-query", "https://dns.google/dns-query"],
            "proxy-server-nameserver": ["77.88.8.8", "1.1.1.1"],
            "nameserver-policy": {"+.ru,+.su,+.xn--p1ai": ["77.88.8.8", "77.88.8.1"]} if s.get("route", "ru") == "ru" else {},
        },
        "proxies": proxies,
        "proxy-providers": providers,
        "proxy-groups": [
            {"name": GROUP, "type": "select", "proxies": [AUTO], "include-all": True} if has
            else {"name": GROUP, "type": "select", "proxies": ["DIRECT"]},
            {"name": AUTO, "type": "url-test", "include-all": True, "url": TEST_URL, "interval": 300, "tolerance": 60, "lazy": True} if has
            else {"name": AUTO, "type": "select", "proxies": ["DIRECT"]},
        ],
        "rules": rules,
    }
    geodata()
    tmp = os.path.join(DIR, "config.yaml.tmp")
    with open(tmp, "w") as f:
        f.write("# Сгенерировано Cove (assets/vpn/vpn.py) — меняется в Настройки → VPN\n")
        yaml.safe_dump(cfg, f, allow_unicode=True, sort_keys=False)
    os.chmod(tmp, 0o600)   # внутри ключи серверов и секрет
    os.replace(tmp, os.path.join(DIR, "config.yaml"))
    return {"ok": True, "empty": not has, "secret": key, "controller": CONTROLLER, "port": MIXED_PORT, "group": GROUP}


def scan_prizrak():
    out = []
    db = os.path.join(PRIZRAK, "px-server.db")
    if os.path.exists(db):
        raw = open(db, "rb").read().decode("utf-8", "replace")
        seen = set()
        for m in re.finditer(r'\{"id":"Profile_\d+"[^{}]*\}', raw):
            try:
                p = json.loads(m.group(0))
            except ValueError:
                continue
            url = p.get("content") or ""
            if p.get("type") == 1 and url.startswith("http") and url not in seen:
                seen.add(url)
                out.append({"name": p.get("headerTitle") or p.get("title") or "Prizrak-Box", "url": url})
    prof = os.path.join(PRIZRAK, "profiles")
    if not out and os.path.isdir(prof):
        for root, _, files in os.walk(prof):
            for f in files:
                if f.endswith((".yaml", ".yml")):
                    out.append({"name": os.path.splitext(f)[0], "path": os.path.join(root, f)})
    return out


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "gen":
        try:
            s = json.loads(sys.stdin.read() or "{}")
            print(json.dumps(gen(s), ensure_ascii=False))
        except Exception as e:
            print(json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
    elif cmd == "secret":
        print(secret())
    elif cmd == "scan-prizrak":
        print(json.dumps(scan_prizrak(), ensure_ascii=False))
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
