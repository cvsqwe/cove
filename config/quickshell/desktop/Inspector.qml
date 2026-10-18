import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Инспектор выбранного виджета: фон, размер и поля из схемы каталога.
Rectangle {
    id: root

    property var entry: ({})
    property var cat: ({})
    readonly property var o: Object.assign({}, cat?.opts ?? {}, entry?.opts ?? {})

    signal patch(var p)
    signal opt(string key, var value)
    signal duplicate()
    signal remove()
    signal raise()
    signal close()

    width: 340
    height: Math.min(col.implicitHeight + 32, parent.height - Theme.barBottom - 140)
    radius: Theme.radius + 6
    color: Theme.panel
    border.width: 1
    border.color: Theme.surface0

    // поглощаем клики, чтобы не снимать выделение
    MouseArea { anchors.fill: parent }

    Flickable {
        anchors.fill: parent
        anchors.margins: 16
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                MIcon { icon: root.cat?.icon ?? ""; color: Theme.accent; size: Theme.iconSize }
                StyledText { Layout.fillWidth: true; text: root.cat?.label ?? ""; font.bold: true; font.pixelSize: Theme.fontSizeLarge; elide: Text.ElideRight }
                IconButton { size: 28; iconSize: 14; icon: "󰅖"; onClicked: root.close() }
            }

            component Field: ColumnLayout {
                property string label
                default property alias content: holder.data
                Layout.fillWidth: true
                spacing: 6
                StyledText { text: parent.label; color: Theme.subtext0; font.pixelSize: Theme.fontSizeSmall }
                Item { id: holder; Layout.fillWidth: true; implicitHeight: childrenRect.height }
            }

            Field {
                label: I18n.tr("Фон")
                SSegment {
                    options: [{ value: "glass", label: I18n.tr("Стекло") }, { value: "solid", label: I18n.tr("Сплошной") }, { value: "none", label: I18n.tr("Без фона") }]
                    current: root.entry?.style ?? root.cat?.style ?? "glass"
                    onPicked: v => root.patch({ style: v })
                }
            }
            Field {
                label: I18n.tr("Размер")
                SSlider { from: 0.4; to: 3; step: 0.05; percent: true; value: root.entry?.scale ?? 1; onMoved: v => root.patch({ scale: v }) }
            }

            Rectangle { visible: (root.cat?.schema ?? []).length > 0; Layout.fillWidth: true; implicitHeight: 1; color: Theme.surface0 }

            Repeater {
                model: root.cat?.schema ?? []
                Field {
                    id: f
                    required property var modelData
                    label: modelData.kind === "bool" ? "" : modelData.label

                    // bool
                    RowLayout {
                        visible: f.modelData.kind === "bool"
                        width: parent.width
                        StyledText { Layout.fillWidth: true; text: f.modelData.label }
                        SSwitch { checked: !!root.o[f.modelData.key]; onToggled: v => root.opt(f.modelData.key, v) }
                    }
                    // seg
                    SSegment {
                        visible: f.modelData.kind === "seg"
                        options: f.modelData.options ?? []
                        current: root.o[f.modelData.key]
                        onPicked: v => root.opt(f.modelData.key, v)
                    }
                    // text
                    SField {
                        visible: f.modelData.kind === "text"
                        width: parent.width
                        text: f.modelData.kind === "text" ? String(root.o[f.modelData.key] ?? "") : ""
                        onEdited: t => root.opt(f.modelData.key, t)
                    }
                    // num
                    SSlider {
                        visible: f.modelData.kind === "num"
                        from: f.modelData.from ?? 0
                        to: f.modelData.to ?? 100
                        step: f.modelData.step ?? 1
                        value: Number(root.o[f.modelData.key] ?? 0)
                        onMoved: v => root.opt(f.modelData.key, v)
                    }
                    // items — пункты списка задач
                    ColumnLayout {
                        visible: f.modelData.kind === "items"
                        width: parent.width
                        spacing: 4
                        readonly property var items: f.modelData.kind === "items" ? (root.o[f.modelData.key] ?? []) : []
                        Repeater {
                            model: parent.items
                            RowLayout {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                MIcon { icon: modelData.d ? "check_box" : "check_box_outline_blank"; color: modelData.d ? Theme.overlay0 : Theme.subtext0; size: Theme.fontSize }
                                StyledText { Layout.fillWidth: true; text: modelData.t; color: modelData.d ? Theme.overlay0 : Theme.text; elide: Text.ElideRight }
                                IconButton {
                                    size: 26; iconSize: 12; icon: "󰅖"; iconColor: Theme.red
                                    onClicked: { const l = JSON.parse(JSON.stringify(root.o[f.modelData.key] ?? [])); l.splice(index, 1); root.opt(f.modelData.key, l); }
                                }
                            }
                        }
                        SField {
                            Layout.fillWidth: true
                            placeholderText: I18n.tr("Новый пункт + Enter")
                            onAccepted: {
                                if (!text.trim()) return;
                                const l = JSON.parse(JSON.stringify(root.o[f.modelData.key] ?? []));
                                l.push({ t: text.trim(), d: false });
                                root.opt(f.modelData.key, l);
                                text = "";
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surface0 }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                SButton { icon: "󰆏"; text: I18n.tr("Копия"); onClicked: root.duplicate() }
                SButton { icon: "󰁝"; text: I18n.tr("Наверх"); onClicked: root.raise() }
                SButton { icon: "󰆴"; text: I18n.tr("Удалить"); danger: true; onClicked: root.remove() }
            }
        }
    }
}
