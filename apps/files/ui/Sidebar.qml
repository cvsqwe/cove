import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.kit
import qs.services

// Боковая панель: места, закладки, устройства, корзина. На папки и корзину можно бросать файлы.
Rectangle {
    id: root
    property var pane: null
    signal navigate(string path)
    signal openTrash()
    signal newTab(string path)
    signal dropped(var urls, string dest, int action)
    signal menu(var item, real x, real y)

    color: Cove.mantle

    Flickable {
        anchors.fill: parent
        anchors.topMargin: 8
        contentHeight: col.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: KScrollBar {}

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 1

            Head { text: "Места" }
            SideRow { side: root; icon: "home"; label: "Домашняя"; path: Cove.home }
            Repeater {
                model: Places.userDirs
                SideRow { side: root; required property var modelData; icon: modelData.icon; label: modelData.name; path: modelData.path }
            }
            SideRow { side: root;
                icon: "delete"
                label: "Корзина"
                trash: true
                badge: Places.trashCount > 0 ? Places.trashCount : 0
            }

            Head { text: "Закладки"; visible: Places.bookmarks.length > 0 }
            Repeater {
                model: Places.bookmarks
                SideRow { side: root;
                    required property var modelData
                    icon: "bookmark"
                    label: modelData.name
                    path: modelData.path
                    bookmark: true
                }
            }

            Head { text: "Устройства" }
            SideRow { side: root; icon: "computer"; label: "Компьютер"; path: "/" }
            Repeater {
                model: Places.devices
                SideRow { side: root;
                    required property var modelData
                    icon: modelData.removable ? "usb" : "hard_drive"
                    label: modelData.label
                    sub: Fmt.size(modelData.size)
                    path: modelData.mount
                    device: modelData
                }
            }
        }
    }

    component Head: KText {
        Layout.fillWidth: true
        Layout.leftMargin: 18
        Layout.topMargin: 12
        Layout.bottomMargin: 4
        color: Cove.overlay1
        font.pixelSize: Cove.fontSizeSmall
        font.bold: true
    }
}
