import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Окно «Игры»: витрина и сами игры (games/*.qml). `qs ipc call games open [id]`, действие «Игры»,
// ярлык в лаунчере. Рекорды — Store.gameScores.
//
// Игра — Item с:
//   property bool active          — окно на экране и игра открыта (иначе таймеры стоят);
//   property string status        — строка для шапки («Счёт: 120 · Уровень 3»);
//   property string bestKey       — ключ рекорда в Store.gameScores (может зависеть от режима);
//   property bool lowerBetter     — рекорд — меньшее значение (время, ходы);
//   function bestText(v): string  — как показать рекорд (необязательно);
//   function restart()
//   signal record(real value)     — партия закончена с результатом value
//   signal sfx(string name)       — звук (GameFx.names)
//   signal fx(string kind, Item at, real x, real y, string text, color tint)
//                                 — эффект: float | burst | confetti | shake | flash; x, y — в координатах at
//                                   (для burst text — число частиц, для shake — сила)
Scope {
    id: root

    property bool shown: false
    property string current: ""   // id открытой игры; "" — витрина

    readonly property var games: [
        { id: "blocks", file: "Blocks", name: I18n.tr("Блоки"), icon: "grid_view", color: Theme.accent, desc: I18n.tr("Ставь фигуры на поле 8×8, собирай линии") },
        { id: "g2048", file: "Game2048", name: "2048", icon: "filter_9_plus", color: Theme.yellow, desc: I18n.tr("Сдвигай плитки, складывай одинаковые") },
        { id: "tetris", file: "Tetris", name: I18n.tr("Тетрис"), icon: "view_quilt", color: Theme.accent2, desc: I18n.tr("Классика: собирай ряды из падающих фигур") },
        { id: "snake", file: "Snake", name: I18n.tr("Змейка"), icon: "gesture", color: Theme.green, desc: I18n.tr("Ешь и расти, не врезайся в себя") },
        { id: "mines", file: "Mines", name: I18n.tr("Сапёр"), icon: "flag", color: Theme.red, desc: I18n.tr("Открой всё поле и не подорвись") },
        { id: "typing", file: "Typing", name: I18n.tr("Печать"), icon: "keyboard", color: Theme.teal, desc: I18n.tr("Скорость печати, как MonkeyType") },
        { id: "flappy", file: "Flappy", name: "Flappy", icon: "flutter_dash", color: Theme.peach, desc: I18n.tr("Пролети между трубами") },
        { id: "dino", file: "Dino", name: I18n.tr("Динозавр"), icon: "directions_run", color: Theme.lavender, desc: I18n.tr("Беги и прыгай через кактусы") },
        { id: "memory", file: "Memory", name: I18n.tr("Пары"), icon: "style", color: Theme.pink, desc: I18n.tr("Найди все одинаковые карточки") }
    ]
    readonly property var game: games.find(g => g.id === current) ?? null

    function open(id: string): void {
        current = games.some(g => g.id === id) ? id : current;
        shown = true;
        Panels.closeAll();
    }

    // рекорд: true — побит
    function best(key: string): var { return (Store.gameScores ?? {})[key]; }
    function report(key: string, v: real, lowerBetter: bool): bool {
        if (!key || !(v > 0)) return false;
        const old = best(key);
        if (old !== undefined && (lowerBetter ? v >= old : v <= old)) return false;
        const s = Object.assign({}, Store.gameScores ?? {});
        s[key] = v;
        Store.gameScores = s;
        return true;
    }

    IpcHandler {
        target: "games"
        function toggle(): void { root.shown ? (root.shown = false) : root.open(""); }
        function open(id: string): void { root.open(id); }
    }

    FloatingWindow {
        id: win
        visible: root.shown
        title: I18n.tr("Игры Cove")
        implicitWidth: 1060
        implicitHeight: 760
        minimumSize: Qt.size(820, 620)
        color: Theme.base
        onVisibleChanged: if (!visible) root.shown = false

        // Esc: из игры — на витрину, с витрины — закрыть
        Shortcut {
            sequence: "Escape"
            onActivated: root.current !== "" ? (root.current = "") : (root.shown = false)
        }

        // ---------- витрина ----------
        Item {
            anchors.fill: parent
            visible: root.current === ""

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 6

                RowLayout {
                    spacing: 14
                    MIcon { icon: "sports_esports"; size: 34; color: Theme.accent }
                    ColumnLayout {
                        spacing: 0
                        StyledText { text: I18n.tr("Игры"); font.pixelSize: 28; font.bold: true }
                        StyledText { text: I18n.tr("Пока что-то собирается или грузится"); color: Theme.overlay1 }
                    }
                }

                GridLayout {
                    Layout.topMargin: 22
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: 12
                    columnSpacing: 12

                    Repeater {
                        model: root.games
                        Rectangle {
                            id: card
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 150
                            radius: Theme.radius + 4
                            color: cm.containsMouse ? Theme.surface0 : Theme.mantle
                            border.width: 1
                            border.color: cm.containsMouse ? card.modelData.color : Theme.surface0
                            scale: cm.pressed ? 0.98 : 1
                            Behavior on scale { NumberAnimation { duration: 90 } }
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Rectangle {
                                x: 18; y: 18
                                width: 52; height: 52
                                radius: 16
                                color: Theme.alpha(card.modelData.color, 0.16)
                                MIcon { anchors.centerIn: parent; icon: card.modelData.icon; size: 28; color: card.modelData.color; fill: true }
                            }
                            ColumnLayout {
                                x: 18
                                y: 82
                                width: parent.width - 36
                                spacing: 2
                                StyledText { text: card.modelData.name; font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                                StyledText { Layout.fillWidth: true; text: card.modelData.desc; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
                            }
                            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.current = card.modelData.id }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                StyledText {
                    text: I18n.tr("Esc — назад к играм · рекорды сохраняются")
                    color: Theme.overlay0
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // ---------- игра ----------
        Item {
            anchors.fill: parent
            visible: root.current !== ""

            property bool newRecord: false
            Timer { id: recTimer; interval: 2600; onTriggered: parent.newRecord = false }

            // шапка
            Rectangle {
                id: head
                width: parent.width
                height: 60
                color: Theme.mantle
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12
                    IconButton { icon: "arrow_back"; onClicked: root.current = "" }
                    MIcon { icon: root.game?.icon ?? ""; color: root.game?.color ?? Theme.accent; size: 22; fill: true }
                    StyledText { text: root.game?.name ?? ""; font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                    StyledText {
                        Layout.leftMargin: 10
                        text: loader.item?.status ?? ""
                        color: Theme.subtext1
                    }
                    Item { Layout.fillWidth: true }
                    // «Новый рекорд!»
                    Rectangle {
                        visible: opacity > 0
                        opacity: head.parent.newRecord ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                        implicitWidth: nr.implicitWidth + 24
                        implicitHeight: 30
                        radius: 15
                        color: Theme.yellow
                        Row {
                            id: nr
                            anchors.centerIn: parent
                            spacing: 6
                            MIcon { icon: "emoji_events"; fill: true; color: Theme.crust; size: 15; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: I18n.tr("Новый рекорд!"); color: Theme.crust; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Row {
                        spacing: 6
                        readonly property var b: loader.item ? root.best(loader.item.bestKey) : undefined
                        visible: b !== undefined
                        MIcon { icon: "emoji_events"; color: Theme.yellow; size: 16; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.b === undefined ? "" : loader.item.bestText ? loader.item.bestText(parent.b) : String(parent.b)
                            color: Theme.subtext0
                        }
                    }
                    IconButton {
                        icon: Store.gameSound ? "volume_up" : "volume_off"
                        iconColor: Store.gameSound ? Theme.text : Theme.overlay1
                        onClicked: { Store.gameSound = !Store.gameSound; loader.item?.forceActiveFocus(); }
                    }
                    IconButton { icon: "refresh"; onClicked: { loader.item?.restart(); loader.item?.forceActiveFocus(); } }
                }
            }

            Loader {
                id: loader
                anchors.top: head.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                active: root.current !== ""
                source: root.game ? Qt.resolvedUrl(root.game.file + ".qml") : ""
                focus: true
                onLoaded: { item.forceActiveFocus(); fx.sound("start"); }
                transform: Translate { x: fx.dx }
            }
            GameFx {
                id: fx
                anchors.fill: loader
                z: 10
                muted: !Store.gameSound
                volume: Math.max(0.25, Settings.general.soundVolume)
            }
            Binding { target: loader.item; property: "active"; value: win.visible && root.current !== ""; when: loader.status === Loader.Ready }
            Connections {
                target: loader.item
                ignoreUnknownSignals: true
                function onRecord(v: real): void {
                    if (root.report(loader.item.bestKey, v, loader.item.lowerBetter)) {
                        head.parent.newRecord = true;
                        recTimer.restart();
                        fx.sound("record");
                        fx.confetti();
                    }
                }
                function onSfx(name: string): void { fx.sound(name); }
                function onFx(kind: string, at: Item, x: real, y: real, text: string, tint: color): void {
                    const p = at ? at.mapToItem(fx, x, y) : Qt.point(x, y);
                    if (kind === "float") fx.floatText(p.x, p.y, text, tint);
                    else if (kind === "burst") fx.burst(p.x, p.y, tint, Number(text) || 18);
                    else if (kind === "confetti") fx.confetti();
                    else if (kind === "shake") fx.shake(Number(text) || 8);
                    else if (kind === "flash") fx.flash(tint);
                }
            }
        }
    }
}
