import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Cove Welcome: первый запуск на свежей установке — язык и имя, обои, вид, главные хоткеи.
// Показывается один раз (Store.welcomed). qs ipc call welcome open — показать снова.
Scope {
    id: root

    property bool shown: false
    property int stepIdx: 0
    readonly property int steps: 4

    function open(): void { stepIdx = 0; shown = true; }
    function finish(): void { shown = false; Store.welcomed = true; }

    // при старте: только на свежей установке (обои ещё стандартные); иначе просто помечаем
    function boot(): void {
        if (Store.welcomed) return;
        if (Store.wallpaper.indexOf("/assets/wallpapers/") < 0) { Store.welcomed = true; return; }
        delay.start();
    }
    Timer { id: delay; interval: 4200; onTriggered: root.open() }   // после заставки

    IpcHandler {
        target: "welcome"
        function open(): void { root.open(); }
    }

    function bindOf(action: string): var { return (Settings.binds ?? []).find(b => b.action === action && b.enabled !== false) ?? null; }

    PanelWindow {
        visible: root.shown
        screen: Displays.primaryScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-welcome"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: Theme.alpha(Theme.crust, 0.72)

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 760
            height: 560
            radius: Theme.radius + 8
            color: Theme.panel
            border.width: 1
            border.color: Theme.surface0
            focus: true
            Keys.onEscapePressed: root.finish()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 18

                // точки шагов
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Repeater {
                        model: root.steps
                        Rectangle {
                            required property int index
                            width: index === root.stepIdx ? 22 : 8; height: 8; radius: 4
                            color: index <= root.stepIdx ? Theme.accent : Theme.surface1
                            Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.stepIdx

                    // 1. привет: язык и имя
                    ColumnLayout {
                        spacing: 16
                        CoveLogo { Layout.alignment: Qt.AlignHCenter; size: 72 }
                        StyledText { Layout.alignment: Qt.AlignHCenter; text: I18n.tr("Добро пожаловать в Cove"); font.pixelSize: 26; font.bold: true }
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: I18n.tr("Пара шагов, и система будет вашей. Всё это потом меняется в Настройках.")
                            color: Theme.subtext0
                        }
                        Item { Layout.preferredHeight: 6 }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12
                            StyledText { text: I18n.tr("Язык"); color: Theme.subtext1 }
                            SSegment {
                                options: [{ value: "ru", label: "Русский" }, { value: "en", label: "English" }]
                                current: Settings.general.language === "auto" ? (I18n.en ? "en" : "ru") : Settings.general.language
                                onPicked: v => Settings.general.language = v
                            }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12
                            StyledText { text: I18n.tr("Как к вам обращаться"); color: Theme.subtext1 }
                            SField {
                                text: Settings.general.name
                                placeholderText: Quickshell.env("USER")
                                onTextChanged: Settings.general.name = text.trim()
                            }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12
                            StyledText { Layout.alignment: Qt.AlignTop; Layout.topMargin: 8; text: I18n.tr("Ваш город"); color: Theme.subtext1 }
                            CitySearch { Layout.preferredWidth: 300 }
                        }
                        Item { Layout.fillHeight: true }
                    }

                    // 2. обои
                    ColumnLayout {
                        spacing: 12
                        StyledText { text: I18n.tr("Обои"); font.pixelSize: 22; font.bold: true }
                        StyledText { text: I18n.tr("Цвета системы подстроятся под картинку. Все обои — Super+W."); color: Theme.subtext0 }
                        GridView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            cellWidth: width / 4
                            cellHeight: cellWidth * 0.62
                            // свои обои Cove — первыми
                            model: Wallpapers.files.filter(f => !Store.isVideo(f)).sort((a, b) => b.includes("/Cove/") - a.includes("/Cove/")).slice(0, 24)
                            delegate: Item {
                                required property string modelData
                                width: GridView.view.cellWidth
                                height: GridView.view.cellHeight
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: Theme.radiusSmall
                                    color: Theme.surface0
                                    border.width: Store.wallpaper === parent.modelData ? 3 : 0
                                    border.color: Theme.accent
                                    clip: true
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        source: "file://" + parent.parent.modelData
                                        sourceSize: Qt.size(240, 150)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Wallpapers.set(parent.parent.modelData) }
                                }
                            }
                        }
                    }

                    // 3. вид
                    ColumnLayout {
                        spacing: 12
                        StyledText { text: I18n.tr("Настроение"); font.pixelSize: 22; font.bold: true }
                        StyledText { text: I18n.tr("Готовые сочетания скруглений, анимаций и цветов"); color: Theme.subtext0 }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: 10
                            rowSpacing: 10
                            Repeater {
                                model: Object.keys(Profiles.presets)
                                Rectangle {
                                    id: pc
                                    required property string modelData
                                    readonly property var p: Profiles.presets[modelData]
                                    Layout.fillWidth: true
                                    implicitHeight: 74
                                    radius: Theme.radiusSmall + 2
                                    color: pm.containsMouse ? Theme.surface1 : Theme.surface0
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 2
                                        RowLayout {
                                            spacing: 8
                                            MIcon { icon: pc.p.icon; color: Theme.accent }
                                            StyledText { text: I18n.tr(pc.modelData); font.bold: true }
                                        }
                                        StyledText { Layout.fillWidth: true; text: pc.p.desc; color: Theme.subtext0; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
                                    }
                                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Profiles.applyNamed(pc.modelData) }
                                }
                            }
                        }
                        StyledText { Layout.topMargin: 6; text: I18n.tr("Панель"); font.bold: true; color: Theme.subtext1 }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: BarStyles.presets
                                SButton {
                                    required property var modelData
                                    text: modelData.name
                                    primary: BarStyles.matches(modelData.cfg)
                                    onClicked: BarStyles.apply(modelData.cfg)
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }

                    // 4. хоткеи
                    ColumnLayout {
                        spacing: 12
                        StyledText { text: I18n.tr("Главное запомнить"); font.pixelSize: 22; font.bold: true }
                        StyledText { text: I18n.tr("Всё остальное — в шпаргалке. Мышью тоже можно: остров, панель, правый клик."); color: Theme.subtext0 }
                        Repeater {
                            model: [
                                { a: "shell.launcher", t: I18n.tr("Приложения, расчёты, файлы, поиск") },
                                { a: "shell.settings", t: I18n.tr("Настройки") },
                                { a: "shell.cheatsheet", t: I18n.tr("Все хоткеи") },
                                { a: "shell.overview", t: I18n.tr("Обзор окон и рабочих столов") },
                                { a: "shell.control", t: I18n.tr("Звук, Wi-Fi, Bluetooth") },
                                { a: "shell.wallpaper", t: I18n.tr("Обои") }
                            ].filter(x => root.bindOf(x.a))
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 14
                                KeyCaps { Layout.preferredWidth: 190; keys: Binds.keycaps(root.bindOf(parent.modelData.a)) }
                                StyledText { Layout.fillWidth: true; text: parent.modelData.t }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                // навигация
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SButton { text: I18n.tr("Пропустить"); visible: root.stepIdx < root.steps - 1; onClicked: root.finish() }
                    Item { Layout.fillWidth: true }
                    SButton { text: I18n.tr("Назад"); visible: root.stepIdx > 0; onClicked: root.stepIdx-- }
                    SButton {
                        primary: true
                        text: root.stepIdx < root.steps - 1 ? I18n.tr("Дальше") : I18n.tr("Готово")
                        onClicked: root.stepIdx < root.steps - 1 ? root.stepIdx++ : root.finish()
                    }
                }
            }
        }
    }
}
