#!/usr/bin/env python3
"""ICS → тот же ICS, но время с TZID=… переведено в UTC (…Z). Для services/Agenda.qml:
в JS-движке QML нет базы часовых поясов. Неизвестную зону оставляем как есть (будет местным временем)."""
import re, sys
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

text = open(sys.argv[1], encoding="utf-8", errors="replace").read().replace("\r\n", "\n")
text = re.sub(r"\n[ \t]", "", text)  # склеиваем перенесённые строки

def fix(m):
    key, params, value = m.group(1), m.group(2), m.group(3)
    tz = re.search(r"TZID=\"?([^;:\"]+)\"?", params)
    if not tz:
        return m.group(0)
    try:
        zone = ZoneInfo(tz.group(1))
    except Exception:
        return m.group(0)
    rest = re.sub(r";?TZID=\"?[^;:\"]+\"?", "", params)
    out = []
    for v in value.split(","):
        try:
            d = datetime.strptime(v.strip(), "%Y%m%dT%H%M%S").replace(tzinfo=zone)
            out.append(d.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
        except ValueError:
            out.append(v)
    return f"{key}{rest}:{','.join(out)}"

text = re.sub(r"^(DTSTART|DTEND|EXDATE|RECURRENCE-ID)((?:;[^:\n]*)?):([^\n]+)$", fix, text, flags=re.M)
sys.stdout.write(text)
