#!/usr/bin/env python3
"""Ассистент лаунчера: один ход разговора через выбранного провайдера.

assistant.py <provider> <model> <base_url> '<messages json>'
  provider: claude (Claude Code, `claude -p`) | anthropic (API, SDK из venv) | openai (совместимый API) | ollama
  messages: [{"role": "user"|"assistant", "content": "..."}], последний — вопрос.

Пишет в stdout JSON-строки: {"t": "text", "v": кусок} … {"t": "done"} или {"t": "error", "v": текст}.
Ключ API — в ~/.local/state/cove/assistant.key (права 600), в settings.json его нет.
"""
import json
import os
import shutil
import subprocess
import sys
import urllib.request

KEY_FILE = os.path.expanduser("~/.local/state/cove/assistant.key")
VENV = os.path.expanduser("~/.local/share/cove/assistant-venv")
SYSTEM = ("Ты ассистент в лаунчере рабочего стола Cove (Arch Linux, Hyprland). "
          "Отвечай кратко и по делу, на языке вопроса. Можно Markdown; команды — в блоках кода.")


def out(t, v=None):
    print(json.dumps({"t": t, "v": v} if v is not None else {"t": t}, ensure_ascii=False), flush=True)


def key():
    try:
        with open(KEY_FILE) as f:
            return f.read().strip()
    except OSError:
        return ""


def transcript(messages):
    """Claude Code в режиме -p берёт одну строку: склеиваем историю в текст."""
    if len(messages) == 1:
        return messages[0]["content"]
    parts = [("Пользователь: " if m["role"] == "user" else "Ассистент: ") + m["content"] for m in messages[:-1]]
    return "Предыдущий разговор:\n\n" + "\n\n".join(parts) + "\n\nНовый вопрос: " + messages[-1]["content"]


def run_claude(model, messages):
    exe = shutil.which("claude")
    if not exe:
        return out("error", "Claude Code не найден. Поставьте его или выберите другого провайдера: Настройки → Лаунчер → Ассистент.")
    # без инструментов, MCP, хуков и сохранения сессий — просто ответ
    cmd = [exe, "-p", "--tools", "", "--no-session-persistence", "--strict-mcp-config", "--setting-sources", "",
           "--system-prompt", SYSTEM, "--output-format", "stream-json", "--verbose", "--include-partial-messages"]
    if model:
        cmd += ["--model", model]
    cwd = os.path.expanduser("~/.cache/cove/assistant")   # не домашняя папка: там свой CLAUDE.md
    os.makedirs(cwd, exist_ok=True)
    p = subprocess.Popen(cmd + [transcript(messages)], cwd=cwd, stdin=subprocess.DEVNULL,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    for line in p.stdout:
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if d.get("type") == "stream_event":
            e = d.get("event", {})
            if e.get("type") == "content_block_delta" and e.get("delta", {}).get("type") == "text_delta":
                out("text", e["delta"]["text"])
        elif d.get("type") == "result":
            if d.get("is_error"):
                return out("error", str(d.get("result") or "Claude Code вернул ошибку"))
            return out("done")
    err = p.stderr.read().strip()
    p.wait()
    out("error", err.splitlines()[-1] if err else f"Claude Code завершился с кодом {p.returncode}")


def run_anthropic(model, messages):
    try:
        import anthropic
    except ImportError:
        return out("error", "Нет библиотеки anthropic. Настройки → Лаунчер → Ассистент → «Установить».")
    # без ключа SDK сам ищет ANTHROPIC_API_KEY или профиль `ant auth login`
    client = anthropic.Anthropic(api_key=key()) if key() else anthropic.Anthropic()
    try:
        # fallbacks: отказ классификатора безопасности переспрашивается у рекомендованной модели, а не обрывает ответ
        with client.beta.messages.stream(
            model=model or "claude-opus-5-5",
            max_tokens=16000,
            system=SYSTEM,
            messages=messages,
            output_config={"effort": "low"},
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
        ) as stream:
            for text in stream.text_stream:
                out("text", text)
            msg = stream.get_final_message()
        if msg.stop_reason == "refusal":
            return out("error", "Модель отказалась отвечать на этот вопрос.")
        out("done")
    except TypeError:   # SDK не нашёл ни ключа, ни профиля `ant auth login`
        out("error", "Не задан ключ API Anthropic: Настройки → Лаунчер → Ассистент.")
    except anthropic.AuthenticationError:
        out("error", "Неверный ключ API Anthropic.")
    except anthropic.RateLimitError:
        out("error", "Слишком много запросов — попробуйте через минуту.")
    except anthropic.APIStatusError as e:
        out("error", f"Ошибка API {e.status_code}: {e.message}")
    except anthropic.APIConnectionError:
        out("error", "Нет связи с api.anthropic.com.")


def run_openai(model, base, messages, need_key):
    k = key()
    if need_key and not k:
        return out("error", "Не задан ключ API: Настройки → Лаунчер → Ассистент.")
    if not model:
        return out("error", "Не задана модель: Настройки → Лаунчер → Ассистент.")
    body = json.dumps({"model": model, "stream": True,
                       "messages": [{"role": "system", "content": SYSTEM}] + messages}).encode()
    req = urllib.request.Request(base.rstrip("/") + "/chat/completions", data=body,
                                 headers={"Content-Type": "application/json", **({"Authorization": "Bearer " + k} if k else {})})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            for raw in r:
                line = raw.decode("utf-8", "replace").strip()
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if data == "[DONE]":
                    break
                try:
                    delta = json.loads(data)["choices"][0].get("delta", {}).get("content")
                except (ValueError, KeyError, IndexError):
                    continue
                if delta:
                    out("text", delta)
        out("done")
    except urllib.error.HTTPError as e:
        out("error", f"Ошибка {e.code}: {e.read().decode('utf-8', 'replace')[:300]}")
    except (urllib.error.URLError, OSError) as e:
        out("error", f"Нет связи с {base}: {getattr(e, 'reason', e)}")


def main():
    provider, model, base, messages = sys.argv[1], sys.argv[2], sys.argv[3], json.loads(sys.argv[4])
    if provider == "claude":
        run_claude(model, messages)
    elif provider == "anthropic":
        run_anthropic(model, messages)
    elif provider == "ollama":
        run_openai(model, base or "http://localhost:11434/v1", messages, False)
    elif provider == "openai":
        run_openai(model, base or "https://api.openai.com/v1", messages, True)
    else:
        out("error", "Ассистент выключен: Настройки → Лаунчер → Ассистент.")


if __name__ == "__main__":
    main()
