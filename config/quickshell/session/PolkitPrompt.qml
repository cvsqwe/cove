import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Запрос прав администратора от polkit (services/PolkitAuth.qml): затемнение, карточка
// с программой и полем пароля как на экране блокировки. Enter — разрешить, Esc — отмена.
Scope {
    id: root

    readonly property var flow: PolkitAuth.flow
    readonly property bool open: flow !== null && !flow.isCompleted
    property string password: ""
    property bool submitted: false
    property bool failed: false
    readonly property bool busy: submitted && !(flow?.isResponseRequired ?? false)

    // имя программы: у pkexec — команда из сообщения («…to run `/usr/bin/gparted' as…»),
    // иначе из action id: org.freedesktop.udisks2.filesystem-mount → Udisks2
    readonly property string appName: {
        const cmd = (flow?.message ?? "").match(/[`']([^`'\s]+)[^`']*['`]/);
        const name = cmd ? cmd[1].split("/").pop() : "";
        if (name) return name.charAt(0).toUpperCase() + name.slice(1);
        const parts = (flow?.actionId ?? "").split(".");
        const skip = ["org", "com", "net", "io", "freedesktop", "gnome", "kde", "policykit", "pkexec", "exec", "run", "policy"];
        const p = parts.find((s, i) => i > 0 && !skip.includes(s.toLowerCase()));
        return p ? p.charAt(0).toUpperCase() + p.slice(1) : I18n.tr("Программа");
    }
    readonly property string iconSource: flow?.iconName ? Quickshell.iconPath(flow.iconName, true) : ""

    function submit(): void {
        if (!flow || !flow.isResponseRequired || busy) return;
        submitted = true;
        failed = false;
        PolkitAuth.submit(password);
    }
    function cancel(): void {
        password = "";
        PolkitAuth.cancel();
    }

    onFlowChanged: {
        password = "";
        submitted = false;
        failed = false;
    }

    Connections {
        target: PolkitAuth
        function onFailed(): void {
            root.password = "";
            root.submitted = false;
            root.failed = true;
            shakeAnim.restart();
        }
    }
    Connections {
        target: root.flow
        // новый запрос пароля после неудачи или следующий шаг PAM
        function onIsResponseRequiredChanged(): void { if (root.flow?.isResponseRequired) root.submitted = false; }
    }

    PanelWindow {
        id: win
        visible: root.open || fade.running
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "qs-polkit"
        color: "transparent"

        Rectangle {
            id: dim
            anchors.fill: parent
            color: Theme.alpha(Theme.crust, 0.72)
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { id: fade; duration: Theme.anim; easing.type: Easing.OutCubic } }
        }

        // клик мимо карточки ничего не делает: запрос прав не закрывается случайно
        MouseArea { anchors.fill: parent }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 420
            height: col.implicitHeight + 56
            radius: Theme.radius + 8
            color: Theme.base
            border.width: 1
            border.color: Theme.surface0
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.92
            Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }

            transform: Translate { id: shake }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shake; property: "x"; to: -14; duration: 50 }
                NumberAnimation { target: shake; property: "x"; to: 12; duration: 60 }
                NumberAnimation { target: shake; property: "x"; to: -8; duration: 60 }
                NumberAnimation { target: shake; property: "x"; to: 0; duration: 60 }
            }

            ColumnLayout {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 28
                spacing: 14

                // значок программы со щитом
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 72
                    implicitHeight: 72
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius + 4
                        color: Theme.alpha(Theme.accent, 0.16)
                    }
                    Image {
                        id: appIcon
                        anchors.centerIn: parent
                        width: 44
                        height: 44
                        source: root.iconSource
                        sourceSize: Qt.size(88, 88)
                        visible: status === Image.Ready
                    }
                    MIcon {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        icon: "admin_panel_settings"
                        fill: true
                        size: 38
                        color: Theme.accent
                    }
                    Rectangle {
                        visible: appIcon.visible
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -4
                        width: 28; height: 28; radius: 14
                        color: Theme.accent
                        border.width: 3
                        border.color: Theme.base
                        MIcon { anchors.centerIn: parent; icon: "shield"; fill: true; size: 13; color: Theme.onAccent }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.tr("{0} запрашивает права администратора", root.appName)
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== ""
                    text: root.flow?.message ?? ""
                    color: Theme.subtext0
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

                // от чьего имени (если polkit предлагает несколько учётных записей)
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    visible: (root.flow?.identities.length ?? 0) > 0
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "person"; color: Theme.overlay1; size: Theme.fontSizeSmall }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.flow?.selectedIdentity?.displayName ?? ""
                        color: Theme.overlay1
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    MouseArea {
                        visible: (root.flow?.identities.length ?? 0) > 1
                        width: 20; height: 20
                        cursorShape: Qt.PointingHandCursor
                        MIcon { anchors.centerIn: parent; icon: "swap_horiz"; color: Theme.accent; size: Theme.fontSizeSmall }
                        // следующая учётная запись по кругу
                        onClicked: {
                            const ids = root.flow.identities;
                            const i = ids.indexOf(root.flow.selectedIdentity);
                            root.flow.selectedIdentity = ids[(i + 1) % ids.length];
                        }
                    }
                }

                // поле пароля
                Rectangle {
                    id: field
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    implicitHeight: 50
                    radius: height / 2
                    color: Theme.mantle
                    border.width: 2
                    border.color: root.failed ? Theme.red : root.busy ? Theme.yellow : input.activeFocus ? Theme.accent : Theme.surface1
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        verticalAlignment: TextInput.AlignVCenter
                        focus: root.open
                        // видимый ввод (не пароль) показываем как есть, пароль — точками
                        opacity: root.flow?.responseVisible ? 1 : 0
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        readOnly: root.busy
                        text: root.password
                        onTextChanged: {
                            root.password = text;
                            if (text !== "") root.failed = false;
                        }
                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                        Keys.onEscapePressed: root.cancel()
                        Connections {
                            target: root
                            function onOpenChanged(): void { if (root.open) input.forceActiveFocus(); }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: !(root.flow?.responseVisible) && root.password.length > 0
                        Repeater {
                            model: Math.min(root.password.length, 22)
                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: Theme.accent
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: root.password.length === 0
                        text: root.busy ? I18n.tr("Проверка…")
                            : root.failed ? I18n.tr("Неверный пароль")
                            : root.prompt
                        color: root.failed ? Theme.red : Theme.overlay1
                    }

                    MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }
                }

                // подсказка PAM (например «осталось 2 попытки») и раскладка
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    StyledText {
                        Layout.fillWidth: true
                        text: root.flow?.supplementaryMessage ?? ""
                        color: root.flow?.supplementaryIsError ? Theme.red : Theme.overlay1
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                    MIcon { icon: Keyboard.caps ? "keyboard_capslock" : "keyboard"; color: Keyboard.caps ? Theme.peach : Theme.overlay1; size: Theme.fontSizeSmall }
                    StyledText { text: Hypr.layout; color: Keyboard.caps ? Theme.peach : Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 10
                    SButton {
                        Layout.fillWidth: true
                        text: I18n.tr("Отмена")
                        onClicked: root.cancel()
                    }
                    SButton {
                        Layout.fillWidth: true
                        primary: true
                        icon: "lock_open"
                        text: I18n.tr("Разрешить")
                        enabled_: root.password !== "" && !root.busy
                        onClicked: root.submit()
                    }
                }
            }
        }
    }

    // «Password:» от PAM переводим, остальные подсказки показываем как есть
    readonly property string prompt: {
        const p = (flow?.inputPrompt ?? "").trim().replace(/:$/, "");
        return p === "" || /^password$/i.test(p) ? I18n.tr("Введите пароль") : p;
    }
}
