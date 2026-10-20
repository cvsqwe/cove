import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.components

// Прокачка: перки (слоты по уровню), скины по играм и лента наград по уровням.
Item {
    id: root
    property var games: []
    signal back()

    readonly property var kindIcon: ({ perk: "bolt", skin: "palette", mode: "sports_esports", slot: "add_box" })

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 12

        RowLayout {
            spacing: 14
            IconButton { icon: "arrow_back"; onClicked: root.back() }
            ProfileBadge {}
            Item { Layout.fillWidth: true }
            StyledText { text: I18n.tr("Опыт: ") + Profile.xp; color: Theme.overlay1 }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: 14

                // ---- перки ----
                RowLayout {
                    StyledText { text: I18n.tr("Перки"); font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                    StyledText {
                        text: Profile.perkSlots > 0 ? I18n.tr("надето ") + Profile.perks.filter(x => Profile.has(x)).length + I18n.tr(" из ") + Profile.perkSlots
                            : I18n.tr("первый слот — на 3 уровне")
                        color: Theme.overlay1
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8
                    Repeater {
                        model: Profile.perkList
                        Rectangle {
                            id: pk
                            required property var modelData
                            readonly property bool open: Profile.has(modelData.id)
                            readonly property bool on: Profile.perkOn(modelData.id)
                            Layout.fillWidth: true
                            implicitHeight: 62
                            radius: Theme.radius
                            color: on ? Theme.alpha(Theme.accent, 0.14) : Theme.mantle
                            border.width: on ? 2 : 1
                            border.color: on ? Theme.accent : Theme.surface0
                            opacity: open ? 1 : 0.5
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12
                                MIcon { icon: pk.open ? "bolt" : "lock"; fill: pk.on; size: 22; color: pk.on ? Theme.accent : Theme.overlay1 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    StyledText { Layout.fillWidth: true; text: pk.modelData.name; font.bold: true; elide: Text.ElideRight }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: pk.open ? pk.modelData.desc : I18n.tr("Откроется на ") + pk.modelData.level + I18n.tr(" уровне")
                                        color: Theme.overlay1
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                    }
                                }
                                SSwitch {
                                    visible: pk.open
                                    checked: pk.on
                                    onToggled: Profile.togglePerk(pk.modelData.id)
                                }
                            }
                        }
                    }
                }

                // ---- скины ----
                StyledText { Layout.topMargin: 8; text: I18n.tr("Скины"); font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                Repeater {
                    model: root.games.filter(g => Profile.skinsFor(g.id).length > 0)
                    RowLayout {
                        id: sr
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        MIcon { icon: sr.modelData.icon; color: sr.modelData.color; fill: true; size: 18 }
                        StyledText { Layout.preferredWidth: 90; text: sr.modelData.name }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [{ id: "", name: I18n.tr("Обычный"), level: 0 }].concat(Profile.skinsFor(sr.modelData.id))
                                Rectangle {
                                    id: sk
                                    required property var modelData
                                    readonly property bool open: modelData.level <= Profile.level
                                    readonly property bool on: Profile.skinOf(sr.modelData.id) === modelData.id
                                    width: skT.implicitWidth + 22
                                    height: 30
                                    radius: 15
                                    color: on ? Theme.accent : skM.containsMouse && open ? Theme.surface1 : Theme.surface0
                                    opacity: open ? 1 : 0.45
                                    StyledText {
                                        id: skT
                                        anchors.centerIn: parent
                                        text: (sk.open ? "" : "🔒 ") + (sk.modelData.id ? sk.modelData.name.split(": ").slice(-1)[0] : sk.modelData.name) + (sk.open ? "" : " · " + sk.modelData.level)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: sk.on ? Theme.onAccent : Theme.text
                                    }
                                    MouseArea {
                                        id: skM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: sk.open ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: if (sk.open) Profile.setSkin(sr.modelData.id, sk.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- лента наград ----
                StyledText { Layout.topMargin: 8; text: I18n.tr("Награды за уровни"); font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                Repeater {
                    model: Profile.rewards
                    RowLayout {
                        id: rw
                        required property var modelData
                        readonly property bool open: modelData.level <= Profile.level
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            implicitWidth: 36; implicitHeight: 26; radius: 13
                            color: rw.open ? Theme.alpha(Profile.frameOf(rw.modelData.level), 0.25) : Theme.surface0
                            StyledText { anchors.centerIn: parent; text: rw.modelData.level; font.bold: true; font.pixelSize: Theme.fontSizeSmall; color: rw.open ? Profile.frameOf(rw.modelData.level) : Theme.overlay1 }
                        }
                        MIcon { icon: root.kindIcon[rw.modelData.kind]; size: 16; color: rw.open ? Theme.accent : Theme.overlay0 }
                        StyledText { Layout.fillWidth: true; text: rw.modelData.name; color: rw.open ? Theme.text : Theme.overlay1 }
                        MIcon { icon: rw.open ? "check_circle" : "lock"; size: 16; fill: rw.open; color: rw.open ? Theme.green : Theme.overlay0 }
                    }
                }
            }
        }
    }
}
