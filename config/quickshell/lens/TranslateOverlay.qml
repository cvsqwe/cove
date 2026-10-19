import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Перевод с экрана: карточка поверх выделенной области (Lens.tr).
// Клик мимо или Esc — закрыть; «Оригинал» — показать распознанный текст.
PanelWindow {
    id: win

    readonly property var tr: Lens.tr
    // монитор, на котором выделяли: slurp даёт глобальные координаты
    screen: {
        const t = tr;
        if (!t) return Panels.screen;
        return Quickshell.screens.find(s => t.x >= s.x && t.x < s.x + s.width && t.y >= s.y && t.y < s.y + s.height) ?? Panels.screen;
    }
    visible: tr !== null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-translate"
    WlrLayershell.keyboardFocus: tr ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool original: false
    onTrChanged: if (!tr) original = false

    // затемнение вокруг, клик — закрыть
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.25)
        MouseArea { anchors.fill: parent; onClicked: Lens.closeTranslate() }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Lens.closeTranslate()
        Keys.onPressed: e => {
            if (e.key === Qt.Key_C && (e.modifiers & Qt.ControlModifier)) { win.copy(); e.accepted = true; }
        }
    }

    function copy(): void {
        const t = win.original ? (tr?.original ?? "") : (tr?.text ?? "");
        if (t) Quickshell.execDetached(["wl-copy", t]);
        copied.restart();
    }
    Timer { id: copied; interval: 1400 }

    Rectangle {
        id: card
        readonly property real sx: (win.tr?.x ?? 0) - (win.screen?.x ?? 0)
        readonly property real sy: (win.tr?.y ?? 0) - (win.screen?.y ?? 0)
        // поверх области; узкую растягиваем, у края — сдвигаем внутрь экрана
        width: Math.min(win.width - 32, Math.max(320, Math.min(720, win.tr?.w ?? 320)))
        height: Math.min(win.height - 32, body.implicitHeight + 28)
        x: Math.max(16, Math.min(win.width - width - 16, sx))
        y: Math.max(16, Math.min(win.height - height - 16, sy))
        radius: Theme.radius
        color: Theme.panel
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.5)
        scale: win.tr ? 1 : 0.95
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
        MouseArea { anchors.fill: parent }   // клики по карточке не закрывают её

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MIcon { icon: "translate"; color: Theme.accent; size: 18 }
                StyledText {
                    Layout.fillWidth: true
                    text: win.tr?.busy ? I18n.tr("Перевожу…")
                        : win.original ? I18n.tr("Оригинал")
                        : I18n.tr("Перевод") + (win.tr?.engine ? " · " + (win.tr.engine === "google" ? "Google" : "MyMemory") : "")
                    color: Theme.subtext1
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
                Chip {
                    implicitHeight: 26
                    visible: !win.tr?.busy && !win.tr?.error
                    text: win.original ? I18n.tr("Перевод") : I18n.tr("Оригинал")
                    onClicked: win.original = !win.original
                }
                Chip {
                    implicitHeight: 26
                    icon: copied.running ? "check" : "content_copy"
                    text: copied.running ? I18n.tr("Скопировано") : I18n.tr("Копировать")
                    visible: !win.tr?.busy
                    onClicked: win.copy()
                }
                IconButton { size: 26; iconSize: 14; icon: "close"; onClicked: Lens.closeTranslate() }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.min(480, txt.implicitHeight)
                contentHeight: txt.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: txt
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: win.tr?.error ? Theme.red : win.original ? Theme.subtext0 : Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    text: win.tr?.error || (win.original || win.tr?.busy ? (win.tr?.original ?? "") : (win.tr?.text ?? ""))
                    opacity: win.tr?.busy ? 0.5 : 1
                }
            }
        }
    }
}
