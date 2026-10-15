#!/bin/sh
# Вид Firefox в стиле шелла Cove: userChrome/userContent из шаблонов assets/firefox/ и нужные about:config.
# Вызывается из services/FirefoxLook.qml:
#   firefox-theme.sh "<шрифт>" <радиус> <малый радиус> <вид> <меню 1|0> <чистая вкладка 1|0> [<домашняя страница>]
# вид: floating | oneline | island | vertical | classic. Цвета сюда не входят — их на лету ставит Pywalfox.
FONT=${1:-Adwaita Sans}; R=${2:-14}; RS=${3:-8}; LAYOUT=${4:-floating}; MENUS=${5:-1}; CLEAN=${6:-1}; HOMEPAGE=${7:-}
TPL="$(dirname "$0")/firefox"
[ -f "$TPL/layout-$LAYOUT.css" ] || LAYOUT=floating
esc() { printf '%s' "$1" | sed 's/[&|\\]/\\&/g'; }
fill() { sed -e "s|@FONT@|$(esc "$FONT")|g" -e "s|@RADIUS@|$R|g" -e "s|@RADIUS_SMALL@|$RS|g"; }

chrome() {
    cat "$TPL/base.css"
    [ "$MENUS" = 1 ] && cat "$TPL/menus.css"
    [ "$LAYOUT" != classic ] && cat "$TPL/card.css"
    cat "$TPL/layout-$LAYOUT.css"
}
content() {
    cat "$TPL/userContent.css"
    [ "$CLEAN" = 1 ] && cat "$TPL/content-clean.css"
}

for base in "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox" "$HOME/.mozilla/firefox"; do
    [ -n "$base" ] && [ -f "$base/profiles.ini" ] || continue
    # профили по умолчанию: из installs.ini и Default=1 в profiles.ini
    profiles=$( { grep -h '^Default=' "$base/installs.ini" 2>/dev/null | cut -d= -f2;
                  awk -F= '/^\[Profile/{p=""} /^Path=/{p=$2} /^Default=1/{print p}' "$base/profiles.ini"; } | sort -u)
    for p in $profiles; do
        dir="$base/$p"; [ -d "$dir" ] || continue
        mkdir -p "$dir/chrome"
        chrome | fill > "$dir/chrome/userChrome.css.tmp" && mv "$dir/chrome/userChrome.css.tmp" "$dir/chrome/userChrome.css"
        content | fill > "$dir/chrome/userContent.css.tmp" && mv "$dir/chrome/userContent.css.tmp" "$dir/chrome/userContent.css"
        # about:config — свой блок в user.js, остальное не трогаем
        js="$dir/user.js"; touch "$js"
        sed -i '/^\/\/ >>> quickshell/,/^\/\/ <<< quickshell/d' "$js"
        {
            echo '// >>> quickshell — вид Firefox в стиле Cove (assets/firefox-theme.sh)'
            echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
            echo 'user_pref("svg.context-properties.content.enabled", true);'
            echo 'user_pref("extensions.autoDisableScopes", 14);'
            echo 'user_pref("browser.tabs.inTitlebar", 1);'
            if [ "$LAYOUT" = vertical ]; then
                echo 'user_pref("sidebar.revamp", true);'
                echo 'user_pref("sidebar.verticalTabs", true);'
                echo 'user_pref("sidebar.visibility", "expand-on-hover");'
            else
                echo 'user_pref("sidebar.verticalTabs", false);'
            fi
            if [ "$CLEAN" = 1 ]; then
                echo 'user_pref("browser.newtabpage.activity-stream.showSponsored", false);'
                echo 'user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);'
                echo 'user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);'
                echo 'user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);'
                echo 'user_pref("browser.newtabpage.activity-stream.showWeather", false);'
                echo 'user_pref("browser.newtabpage.activity-stream.logowordmark.alwaysVisible", false);'
            fi
            [ -n "$HOMEPAGE" ] && echo "user_pref(\"browser.startup.homepage\", \"file://$HOMEPAGE\");"
            echo '// <<< quickshell'
        } >> "$js"
    done
done
