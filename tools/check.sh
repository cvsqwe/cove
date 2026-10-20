#!/usr/bin/env bash
# Проверка репозитория без запуска шелла: синтаксис QML, Python, shell-скриптов и JSON.
# Запускается локально (bash tools/check.sh) и в GitHub Actions (.github/workflows/check.yml).
# QML — qmllint из Qt 6 (не /usr/bin/qmllint: там бывает старый из Qt 5); ошибкой считается
# только синтаксис — модули Quickshell вне шелла не видны, остальные предупреждения шумят.
set -u
cd "$(dirname "$0")/.."
fail=0
say() { printf '%s\n' "$*"; }

files() { find . -name "$1" -not -path './.git/*' -not -path '*/venv/*' -not -path '*/.venv/*' -not -path '*/node_modules/*'; }

# --- QML ---
lint=""
for c in /usr/lib/qt6/bin/qmllint /usr/lib64/qt6/bin/qmllint "$(command -v qmllint6 2>/dev/null)"; do
    [ -n "$c" ] && [ -x "$c" ] && { lint=$c; break; }
done
if [ -z "$lint" ]; then
    say "QML: qmllint из Qt 6 не найден — пропускаю"
else
    out=$(mktemp)
    mapfile -t qml < <(files '*.qml')
    "$lint" --json "$out" "${qml[@]}" >/dev/null 2>&1
    bad=$(python3 - "$out" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
for f in d["files"]:
    for w in f["warnings"]:
        if w.get("id") == "syntax" or w.get("type") == "critical":
            print(f"{f['filename']}:{w.get('line')}: {w.get('message')}")
EOF
)
    rm -f "$out"
    if [ -n "$bad" ]; then say "QML: синтаксические ошибки"; say "$bad"; fail=1; else say "QML: ${#qml[@]} файлов, синтаксис в порядке"; fi
fi

# опасный синтаксис: obj[key]?.(…) — опциональный вызов по вычисляемому ключу роняет движок QML
# (Qt 6.12) ещё при загрузке, без единой строки в логе
bad=$(grep -rnE '\]\?\.\(' --include='*.qml' . 2>/dev/null | grep -v '^\./\.git/' | grep -vE ':[0-9]+:[[:space:]]*//')
if [ -n "$bad" ]; then say "QML: obj[key]?.(…) роняет шелл — вызывайте через переменную"; say "$bad"; fail=1; fi

# --- Python ---
mapfile -t py < <(files '*.py')
bad=$(python3 - "${py[@]}" <<'EOF'
import ast, sys
for p in sys.argv[1:]:
    try:
        ast.parse(open(p, encoding="utf-8").read(), p)
    except SyntaxError as e:
        print(f"{p}:{e.lineno}: {e.msg}")
EOF
)
if [ -n "$bad" ]; then say "Python: синтаксические ошибки"; say "$bad"; fail=1; else say "Python: ${#py[@]} файлов, синтаксис в порядке"; fi

# --- shell ---
n=0
while IFS= read -r f; do
    n=$((n + 1))
    sh=bash; head -1 "$f" | grep -qE '^#!.*/(env )?sh$' && sh=sh
    if ! err=$($sh -n "$f" 2>&1); then say "Shell: $err"; fail=1; fi
done < <(files '*.sh')
say "Shell: $n скриптов проверено"

# --- JSON ---
mapfile -t js < <(files '*.json')
bad=$(python3 - "${js[@]}" <<'EOF'
import json, sys
for p in sys.argv[1:]:
    try:
        json.load(open(p, encoding="utf-8"))
    except Exception as e:
        print(f"{p}: {e}")
EOF
)
if [ -n "$bad" ]; then say "JSON: ошибки"; say "$bad"; fail=1; else say "JSON: ${#js[@]} файлов в порядке"; fi

[ $fail -eq 0 ] && say "Проверка пройдена" || say "Проверка не пройдена"
exit $fail
