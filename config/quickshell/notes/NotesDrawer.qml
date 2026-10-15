import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Заметки — ящик справа (Super+Shift+N). Обычные .md в ~/Notes, сохраняются сами при вводе.
Drawer {
    id: root

    side: "right"
    drawerWidth: 640
    drawerHeight: 620
    grabKeyboard: true
    open: Panels.notes
    onCloseRequested: Panels.notes = false

    property string current: ""

    onOpenChanged: if (open) {
        Notes.refresh();
        if (!current && Notes.files.length) current = Notes.files[0].path;
        editor.forceActiveFocus();
    }

    FileView {
        id: file
        path: root.current
        blockLoading: true
        printErrors: false   // новая заметка создаётся в фоне — первое чтение может не найти файл
        onLoaded: if (!editor.activeFocus || editor.text === "") editor.text = text()
    }
    // файл новой заметки появился — дочитываем
    Connections {
        target: Notes
        function onFilesChanged(): void { if (root.current && !file.loaded) file.reload(); }
    }
    Timer {
        id: save
        interval: 600
        onTriggered: if (root.current) { file.setText(editor.text); Notes.refresh(); }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: 10
        spacing: 12

        // список
        ColumnLayout {
            Layout.preferredWidth: 200
            Layout.maximumWidth: 200
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                StyledText { Layout.fillWidth: true; text: I18n.tr("Заметки"); font.bold: true }
                IconButton {
                    size: 30; iconSize: 14; icon: "󰐕"; active: true
                    onClicked: { save.stop(); root.current = Notes.create(); editor.text = I18n.tr("# Новая заметка\n\n"); editor.forceActiveFocus(); editor.cursorPosition = editor.length; }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: Notes.files
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 50
                    radius: Theme.radiusSmall
                    color: root.current === modelData.path ? Theme.alpha(Theme.accent, 0.18) : m.containsMouse ? Theme.surface0 : "transparent"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 0
                        StyledText { Layout.fillWidth: true; text: parent.parent.modelData.name; elide: Text.ElideRight; font.pixelSize: Theme.fontSizeSmall + 1 }
                        StyledText { text: I18n.locale.toString(parent.parent.modelData.mtime, "d MMM, HH:mm"); color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall - 1 }
                    }
                    MouseArea {
                        id: m
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (save.running) { save.stop(); file.setText(editor.text); } editor.text = ""; root.current = parent.modelData.path; }
                    }
                }
                StyledText { anchors.centerIn: parent; visible: Notes.files.length === 0; text: I18n.tr("Пока пусто"); color: Theme.overlay0 }
            }
        }

        // редактор
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radius
            color: Theme.mantle

            ScrollView {
                anchors.fill: parent
                anchors.margins: 6
                TextArea {
                    id: editor
                    enabled: root.current !== ""
                    placeholderText: root.current ? "" : I18n.tr("Создайте заметку кнопкой +")
                    placeholderTextColor: Theme.overlay0
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    wrapMode: TextEdit.Wrap
                    background: null
                    onTextChanged: if (activeFocus) save.restart()
                    Keys.onEscapePressed: Panels.notes = false
                }
            }

            RowLayout {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                spacing: 6
                StyledText { text: save.running ? I18n.tr("сохраняю…") : root.current ? I18n.tr("сохранено") : ""; color: Theme.overlay0; font.pixelSize: Theme.fontSizeSmall - 1 }
                IconButton {
                    visible: root.current !== ""
                    size: 28; iconSize: 13; icon: "󰆴"; iconColor: Theme.red
                    onClicked: { Notes.remove(root.current); root.current = ""; editor.text = ""; }
                }
            }
        }
    }
}
