import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.components
import qs.services

Item {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)
    implicitWidth: 300
    implicitHeight: 240
    readonly property string path: Notes.files[0]?.path ?? ""
    FileView { id: nf; path: root.path; watchChanges: true; printErrors: false; onFileChanged: reload() }

  ColumnLayout {
    anchors.fill: parent
    spacing: 8
    StyledText { text: "" + (Notes.files[0]?.name ?? I18n.tr("Заметок нет")); color: Theme.accent; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
    StyledText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        text: (nf.text() ?? "").replace(/^#.*\n+/, "")
        color: Theme.text
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        font.pixelSize: Theme.fontSizeSmall + 1
    }
  }
}
