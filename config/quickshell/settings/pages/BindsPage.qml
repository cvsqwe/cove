import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Хоткеи")
    subtitle: I18n.tr("Все сочетания клавиш. Нажмите на строку, чтобы изменить, или «Добавить». Конфликты подсвечиваются.")

    property string filter: ""
    readonly property var items: (Settings.binds ?? []).map((b, i) => ({ b, i, a: Actions.get(b.action) }))
        .filter(x => {
            if (page.filter === "") return true;
            const f = page.filter.toLowerCase();
            return Actions.describe(x.b).toLowerCase().includes(f) || Binds.combo(x.b).toLowerCase().includes(f);
        })
    readonly property var grouped: Actions.groups.map(g => ({ g, list: items.filter(x => (x.a?.group ?? I18n.tr("Своё")) === g) })).filter(x => x.list.length > 0)

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        SField {
            Layout.fillWidth: true
            placeholderText: I18n.tr("Поиск по действию или клавишам…")
            onTextChanged: page.filter = text
        }
        SButton { icon: "󰐕"; text: I18n.tr("Добавить"); primary: true; onClicked: editor.open(-1) }
        SButton { icon: "󰑓"; text: I18n.tr("Сбросить"); onClicked: confirmReset.visible = true }
    }

    Rectangle {
        id: confirmReset
        visible: false
        Layout.fillWidth: true
        implicitHeight: 54
        radius: Theme.radius
        color: Theme.alpha(Theme.red, 0.12)
        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            StyledText { Layout.fillWidth: true; text: I18n.tr("Вернуть стандартные хоткеи? Ваши изменения пропадут."); color: Theme.red }
            SButton { text: I18n.tr("Отмена"); onClicked: confirmReset.visible = false }
            SButton { text: I18n.tr("Сбросить"); danger: true; onClicked: { Binds.reset(); confirmReset.visible = false; } }
        }
    }

    Repeater {
        model: page.grouped

        SCard {
            id: groupCard
            required property var modelData
            title: modelData.g
            icon: modelData.list[0].a?.icon ?? ""

            Repeater {
                model: groupCard.modelData.list

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool conflict: Binds.conflicts(modelData.b, modelData.i).length > 0
                    readonly property bool on: modelData.b.enabled !== false
                    Layout.fillWidth: true
                    implicitHeight: 48

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.radiusSmall
                        color: rowMouse.containsMouse ? Theme.alpha(Theme.surface0, 0.6) : "transparent"
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editor.open(row.modelData.i)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 12

                        MIcon {
                            Layout.preferredWidth: 20
                            icon: row.modelData.a?.icon ?? "?"
                            color: row.on ? Theme.accent : Theme.overlay0
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Actions.describe(row.modelData.b)
                            color: row.on ? Theme.text : Theme.overlay0
                            elide: Text.ElideRight
                        }
                        StyledText {
                            visible: row.conflict
                            text: I18n.tr("конфликт")
                            color: Theme.red
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        KeyCaps { keys: Binds.keycaps(row.modelData.b); dim: !row.on }
                        SSwitch {
                            checked: row.on
                            onToggled: v => { const b = Object.assign({}, row.modelData.b, { enabled: v }); Binds.update(row.modelData.i, b); }
                        }
                    }
                }
            }
        }
    }

    // ---------- редактор бинда ----------
    Popup {
        id: editor
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 620
        modal: true
        padding: 22
        closePolicy: capturing ? Popup.NoAutoClose : Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property int index: -1
        property var draft: ({})
        property bool capturing: false
        readonly property var act: Actions.get(draft.action ?? "")
        readonly property var clash: draft.key ? Binds.conflicts(draft, index) : []

        function open(i: int): void {
            index = i;
            draft = i >= 0 ? Object.assign({}, Settings.binds[i]) : Binds.b("SUPER", "", "shell.launcher", "");
            capturing = i < 0;
            visible = true;
            if (capturing) capture.forceActiveFocus();
        }
        function set(k: string, v): void { const d = Object.assign({}, draft); d[k] = v; draft = d; }
        function save(): void {
            if (!draft.key) return;
            Binds.update(index, draft);
            visible = false;
        }

        ShortcutInhibitor {
            window: QsWindow.window
            enabled: editor.capturing
        }

        background: Rectangle {
            radius: Theme.radius + 6
            color: Theme.base
            border.width: 1
            border.color: Theme.surface1
        }
        Overlay.modal: Rectangle { color: Theme.alpha(Theme.crust, 0.6) }

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            StyledText { text: editor.index < 0 ? I18n.tr("Новый хоткей") : I18n.tr("Изменить хоткей"); font.pixelSize: 20; font.bold: true }

            // захват сочетания
            Rectangle {
                id: capture
                Layout.fillWidth: true
                implicitHeight: 76
                radius: Theme.radius
                color: editor.capturing ? Theme.alpha(Theme.accent, 0.12) : Theme.mantle
                border.width: 2
                border.color: editor.capturing ? Theme.accent : editor.clash.length ? Theme.red : Theme.surface0
                focus: editor.capturing

                SequentialAnimation on border.color {
                    running: editor.capturing
                    loops: Animation.Infinite
                    ColorAnimation { to: Theme.accent2; duration: 700 }
                    ColorAnimation { to: Theme.accent; duration: 700 }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    KeyCaps {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !!editor.draft.key
                        keys: editor.draft.key ? Binds.keycaps(editor.draft) : []
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: editor.capturing ? I18n.tr("Нажмите сочетание… (Esc — отмена)") : editor.draft.key ? I18n.tr("Нажмите здесь, чтобы записать заново") : I18n.tr("Нажмите, чтобы записать сочетание")
                        color: editor.capturing ? Theme.accent : Theme.overlay1
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { editor.capturing = true; capture.forceActiveFocus(); }
                }

                Keys.onPressed: e => {
                    if (!editor.capturing) return;
                    e.accepted = true;
                    if (e.key === Qt.Key_Escape && e.modifiers === Qt.NoModifier) { editor.capturing = false; return; }
                    if (Binds.isModifierKey(e.key)) return;
                    const k = Binds.keyName(e.key, e.text);
                    if (!k) return;
                    const d = Object.assign({}, editor.draft, { mods: Binds.modsFromEvent(e.modifiers), key: k });
                    editor.draft = d;
                    editor.capturing = false;
                }
            }

            StyledText {
                visible: editor.clash.length > 0
                Layout.fillWidth: true
                text: I18n.tr("Уже занято: ") + editor.clash.map(c => Actions.describe(c.x)).join(", ") + I18n.tr(". Сохранение заменит конфликт — старый бинд отключится.")
                color: Theme.red
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            // мышь
            RowLayout {
                spacing: 8
                StyledText { text: I18n.tr("Или мышь:"); color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
                Repeater {
                    model: [["mouse:272", I18n.tr("ЛКМ")], ["mouse:273", I18n.tr("ПКМ")], ["mouse:274", I18n.tr("СКМ")], ["mouse_up", I18n.tr("Колесо ↑")], ["mouse_down", I18n.tr("Колесо ↓")]]
                    SButton {
                        required property var modelData
                        text: modelData[1]
                        implicitHeight: 28
                        onClicked: editor.set("key", modelData[0])
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 14
                rowSpacing: 10

                StyledText { text: I18n.tr("Действие"); color: Theme.subtext0 }
                SDropdown {
                    Layout.fillWidth: true
                    popupWidth: 380
                    options: Actions.list.map(a => ({ value: a.id, label: a.label, icon: a.icon, group: a.group }))
                    current: editor.draft.action
                    searchable: true
                    onPicked: v => editor.set("action", v)
                }

                StyledText { visible: !!editor.act?.arg; text: I18n.tr("Параметр"); color: Theme.subtext0 }
                Loader {
                    visible: !!editor.act?.arg
                    Layout.fillWidth: true
                    sourceComponent: editor.act?.arg === "dir" ? dirArg
                        : editor.act?.arg === "ws" ? wsArg
                        : editor.act?.arg === "app" ? appArg
                        : editor.act?.arg ? textArg : null
                }

                StyledText { text: I18n.tr("Подпись"); color: Theme.subtext0 }
                SField {
                    Layout.fillWidth: true
                    placeholderText: editor.act ? Actions.describe(Object.assign({}, editor.draft, { label: "" })) : ""
                    text: editor.draft.label ?? ""
                    onTextChanged: if (text !== (editor.draft.label ?? "")) editor.set("label", text)
                }

                StyledText { text: I18n.tr("Флаги"); color: Theme.subtext0 }
                RowLayout {
                    spacing: 16
                    RowLayout { SSwitch { checked: !!editor.draft.repeating; onToggled: v => editor.set("repeating", v) } StyledText { text: I18n.tr("повтор при удержании"); font.pixelSize: Theme.fontSizeSmall } }
                    RowLayout { SSwitch { checked: !!editor.draft.locked; onToggled: v => editor.set("locked", v) } StyledText { text: I18n.tr("на экране блокировки"); font.pixelSize: Theme.fontSizeSmall } }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                SButton {
                    visible: editor.index >= 0
                    icon: "󰆴"
                    text: I18n.tr("Удалить")
                    danger: true
                    onClicked: { Binds.remove(editor.index); editor.visible = false; }
                }
                Item { Layout.fillWidth: true }
                SButton { text: I18n.tr("Отмена"); onClicked: editor.visible = false }
                SButton {
                    text: I18n.tr("Сохранить")
                    primary: true
                    enabled_: !!editor.draft.key
                    onClicked: {
                        // отключаем конфликтующие
                        for (const c of editor.clash) Binds.update(c.i, Object.assign({}, c.x, { enabled: false }));
                        editor.save();
                    }
                }
            }
        }

        Component {
            id: dirArg
            SSegment {
                options: Actions.dirs
                current: editor.draft.arg
                onPicked: v => editor.set("arg", v)
            }
        }
        Component {
            id: wsArg
            SSlider {
                from: 1; to: 10; step: 1
                value: Number(editor.draft.arg || 1)
                onMoved: v => editor.set("arg", String(v))
            }
        }
        Component {
            id: appArg
            SDropdown {
                popupWidth: 380
                searchable: true
                options: DesktopEntries.applications.values.filter(e => !e.noDisplay)
                    .sort((x, y) => x.name.localeCompare(y.name))
                    .map(e => ({ value: e.id, label: e.name }))
                current: editor.draft.arg
                onPicked: v => editor.set("arg", v)
            }
        }
        Component {
            id: textArg
            SField {
                placeholderText: editor.act?.arg === "special" ? "magic" : I18n.tr("команда, например: kitty -e htop")
                text: editor.draft.arg ?? ""
                onTextChanged: if (text !== (editor.draft.arg ?? "")) editor.set("arg", text)
            }
        }
    }
}
