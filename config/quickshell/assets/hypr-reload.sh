#!/bin/sh
# Перезагрузка Hyprland с сохранением текущей раскладки клавиатуры.
# Печатает ошибки конфига (пусто — всё хорошо).
idx=$(hyprctl devices -j | python3 -c 'import json,sys; k=json.load(sys.stdin)["keyboards"]; m=[x for x in k if x.get("main")] or k; print(m[0]["active_layout_index"] if m else 0)' 2>/dev/null)
hyprctl reload >/dev/null
sleep 0.4
[ -n "$idx" ] && [ "$idx" != "0" ] && hyprctl switchxkblayout all "$idx" >/dev/null
hyprctl configerrors
