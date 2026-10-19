#!/usr/bin/env bash
# Cove VPN — системная часть (один раз, от root): служба и правило polkit.
#
#   pkexec bash install.sh install <пользователь>   поставить (шелл зовёт сам: Настройки → VPN)
#   pkexec bash install.sh remove                   убрать
#   bash install.sh status <пользователь>           что стоит (без root)
#
# Служба cove-vpn@<пользователь> запускает ядро Mihomo ОТ ИМЕНИ пользователя, но с правами на сеть
# (CAP_NET_ADMIN — TUN и маршруты), root ядру не нужен. Конфиг — ~/.local/state/cove/vpn/config.yaml,
# его пишет шелл. Правило polkit разрешает этому пользователю только start/stop/restart своей службы
# без пароля — больше ничего.
set -euo pipefail

UNIT=/etc/systemd/system/cove-vpn@.service
RULE=/etc/polkit-1/rules.d/50-cove-vpn.rules

case "${1:-}" in
install)
    user="${2:?пользователь}"
    getent passwd "$user" >/dev/null || { echo "нет пользователя $user" >&2; exit 1; }
    bin=$(command -v mihomo || true)
    [ -n "$bin" ] || { echo "нет ядра mihomo: поставьте пакет mihomo-bin (AUR)" >&2; exit 2; }
    install -d -m 755 /etc/systemd/system /etc/polkit-1/rules.d
    cat > "$UNIT" <<EOF
# Cove VPN (Mihomo) — ставит system/vpn/install.sh из репозитория Cove
[Unit]
Description=Cove VPN (Mihomo) для %i
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=%i
# папка конфига — в домашней папке пользователя, где бы она ни была ($$ — systemd сам раскрывает «$»)
ExecStart=/bin/sh -c 'exec $bin -d "\$\$(getent passwd %i | cut -d: -f6)/.local/state/cove/vpn"'
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    cat > "$RULE" <<'EOF'
// Cove VPN: пользователь включает и выключает свою службу cove-vpn@<имя> без пароля (и только её)
polkit.addRule(function (action, subject) {
    if (action.id === "org.freedesktop.systemd1.manage-units"
        && action.lookup("unit") === "cove-vpn@" + subject.user + ".service"
        && ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0
        && subject.local && subject.active) {
        return polkit.Result.YES;
    }
});
EOF
    chmod 644 "$UNIT" "$RULE"
    systemctl daemon-reload
    echo "ok"
    ;;
remove)
    for u in $(systemctl list-units --plain --no-legend 'cove-vpn@*' | awk '{print $1}'); do systemctl stop "$u" || true; done
    rm -f "$UNIT" "$RULE"
    systemctl daemon-reload
    echo "ok"
    ;;
status)
    printf 'mihomo=%s\n' "$(command -v mihomo || true)"
    printf 'unit=%s\n' "$([ -f "$UNIT" ] && echo yes || echo no)"
    printf 'rule=%s\n' "$([ -f "$RULE" ] && echo yes || echo no)"
    ;;
*)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
