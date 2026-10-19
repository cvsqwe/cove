import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Звук")
    subtitle: I18n.tr("Эквалайзер, громкость и обработка микрофона прямо в PipeWire. EasyEffects для этого не нужен.")

    readonly property var s: Settings.sound
    readonly property var band: curve.selected >= 0 ? SoundFx.bands[curve.selected] ?? null : null
    readonly property string sinkLabel: Pipewire.defaultAudioSink?.description || Pipewire.defaultAudioSink?.nickname || ""

    Component.onCompleted: SoundFx.recheck()

    // EasyEffects перехватывает все потоки — пока он запущен, эффекты Cove не слышно
    Rectangle {
        Layout.fillWidth: true
        visible: SoundFx.eeRunning
        implicitHeight: eeRow.implicitHeight + 24
        radius: Theme.radius
        color: Theme.alpha(Theme.yellow, 0.14)
        border.width: 1
        border.color: Theme.alpha(Theme.yellow, 0.4)
        RowLayout {
            id: eeRow
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            MIcon { icon: "warning"; color: Theme.yellow; size: 20 }
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: I18n.tr("Запущен EasyEffects: он забирает себе весь звук, и эффекты Cove не работают. Настройки эквалайзера можно перенести ниже.")
            }
            SButton { text: I18n.tr("Закрыть EasyEffects"); onClicked: SoundFx.quitEasyEffects() }
        }
    }

    SCard {
        title: I18n.tr("Выход")
        icon: "graphic_eq"
        SRow {
            icon: "graphic_eq"
            title: I18n.tr("Эффекты для всего звука")
            desc: page.s.enabled ? I18n.tr("Сейчас звучит через: ") + (page.sinkLabel || I18n.tr("устройство по умолчанию")) : I18n.tr("Звук идёт как есть")
            SSwitch { checked: page.s.enabled; onToggled: v => page.s.enabled = v }
        }
        SRow {
            icon: "tune"
            title: I18n.tr("Предусиление")
            desc: I18n.tr("Убавьте, если с подъёмом эквалайзера звук хрипит")
            SSlider { from: -24; to: 12; step: 0.5; decimals: 1; suffix: I18n.tr(" дБ"); value: page.s.preamp; onMoved: v => page.s.preamp = v }
        }
        SRow {
            icon: "speaker"
            title: I18n.tr("Бас")
            desc: I18n.tr("Мягкий подъём всего ниже 100 Гц")
            separator: false
            SSlider { from: -6; to: 15; step: 0.5; decimals: 1; suffix: I18n.tr(" дБ"); value: page.s.bass; onMoved: v => page.s.bass = v }
        }
    }

    SCard {
        title: I18n.tr("Эквалайзер")
        icon: "equalizer"

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 12

            // наборы: встроенные + свои; выбранный запоминается за текущим выходом
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: SoundFx.builtin
                    Chip {
                        required property var modelData
                        text: modelData.label
                        active: page.s.preset === modelData.id
                        dim: active && SoundFx.modified
                        onClicked: SoundFx.load(modelData.id)
                    }
                }
                Repeater {
                    model: SoundFx.customNames
                    Chip {
                        required property string modelData
                        icon: "bookmark"
                        text: modelData
                        active: page.s.preset === modelData
                        dim: active && SoundFx.modified
                        removable: true
                        onClicked: SoundFx.load(modelData)
                        onRemoved: SoundFx.remove(modelData)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 260
                radius: Theme.radiusSmall
                color: Theme.crust
                EqCurve {
                    id: curve
                    anchors.fill: parent
                    anchors.margins: 8
                }
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall
                text: I18n.tr("Тяните точки мышью: в стороны — частота, вверх-вниз — громкость, колесо — ширина. Двойной клик — новая полоса, правый клик — убрать.")
            }

            // выбранная полоса
            RowLayout {
                Layout.fillWidth: true
                visible: page.band !== null
                spacing: 12
                SDropdown {
                    implicitWidth: 170
                    options: SoundFx.types
                    current: page.band?.type ?? "bell"
                    onPicked: v => SoundFx.setBand(curve.selected, { type: v, q: v === "lowshelf" || v === "highshelf" ? 0.71 : page.band.q })
                }
                StyledText { text: I18n.tr("Ширина"); color: Theme.subtext1 }
                SSlider {
                    from: 0.1; to: 12; step: 0.05; decimals: 2
                    value: page.band?.q ?? 1
                    onMoved: v => SoundFx.setBand(curve.selected, { q: v })
                }
                Item { Layout.fillWidth: true }
                SButton { icon: "delete"; text: I18n.tr("Убрать"); onClicked: { SoundFx.removeBand(curve.selected); curve.selected = -1; } }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                SButton { icon: "add"; text: I18n.tr("Полоса"); onClicked: curve.selected = SoundFx.addBand(1000, 0) }
                SButton { icon: "restart_alt"; text: I18n.tr("Сбросить"); onClicked: { SoundFx.load("flat"); curve.selected = -1; } }
                Item { Layout.fillWidth: true }
                SField {
                    id: saveName
                    implicitWidth: 200
                    placeholderText: I18n.tr("Имя набора…")
                    onAccepted: { SoundFx.save(text); text = ""; }
                }
                SButton { icon: "bookmark_add"; text: I18n.tr("Сохранить"); enabled_: saveName.text.trim() !== ""; onClicked: { SoundFx.save(saveName.text); saveName.text = ""; } }
            }

            StyledText {
                Layout.fillWidth: true
                visible: page.sinkLabel !== ""
                wrapMode: Text.Wrap
                color: Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall
                text: I18n.tr("Набор запоминается за выходом: при переключении на «{0}» вернётся «{1}».", page.sinkLabel, SoundFx.presetLabel((page.s.devices ?? {})[Pipewire.defaultAudioSink?.name ?? ""] ?? page.s.preset))
            }
        }
    }

    SCard {
        title: I18n.tr("Громкость")
        icon: "volume_up"
        SRow {
            icon: "balance"
            title: I18n.tr("Выравнивать громкость")
            desc: SoundFx.lsp ? I18n.tr("Тихие ролики громче, громкая реклама тише") : I18n.tr("Нужен пакет lsp-plugins-lv2")
            SSwitch { opacity: SoundFx.lsp ? 1 : 0.4; checked: page.s.loudness; onToggled: v => { if (SoundFx.lsp) page.s.loudness = v; } }
        }
        SRow {
            visible: page.s.loudness && SoundFx.lsp
            icon: "speed"
            title: I18n.tr("Целевая громкость")
            desc: I18n.tr("Меньше — тише и спокойнее, больше — громче")
            SSlider { from: -30; to: -10; step: 1; suffix: " LUFS"; value: page.s.loudnessLevel; onMoved: v => page.s.loudnessLevel = v }
        }
        SRow {
            icon: "shield"
            title: I18n.tr("Защита от перегруза")
            desc: SoundFx.lsp ? I18n.tr("Лимитер на −1 дБ: сильный подъём эквалайзера не хрипит") : I18n.tr("Нужен пакет lsp-plugins-lv2")
            separator: false
            SSwitch { opacity: SoundFx.lsp ? 1 : 0.4; checked: page.s.limiter; onToggled: v => { if (SoundFx.lsp) page.s.limiter = v; } }
        }
    }

    SCard {
        title: I18n.tr("Микрофон")
        icon: "mic"
        SRow {
            icon: "mic"
            title: I18n.tr("Обработка микрофона")
            desc: I18n.tr("Для всех программ сразу. Эхоподавление включено всегда: звук колонок не попадает в микрофон")
            SSwitch { checked: page.s.mic; onToggled: v => page.s.mic = v }
        }
        SRow {
            visible: page.s.mic
            icon: "noise_control_off"
            title: I18n.tr("Шумоподавление")
            desc: I18n.tr("Убирает вентиляторы, клавиатуру, улицу")
            SSwitch { checked: page.s.micNoise; onToggled: v => page.s.micNoise = v }
        }
        SRow {
            visible: page.s.mic
            icon: "graphic_eq"
            title: I18n.tr("Автогромкость")
            desc: I18n.tr("Ровный уровень голоса, близко вы к микрофону или далеко")
            SSwitch { checked: page.s.micGain; onToggled: v => page.s.micGain = v }
        }
        SRow {
            visible: page.s.mic
            icon: "filter_alt"
            title: I18n.tr("Срез гула")
            desc: I18n.tr("Убирает низкий гул и стуки по столу")
            separator: false
            SSwitch { checked: page.s.micHighpass; onToggled: v => page.s.micHighpass = v }
        }
    }

    SCard {
        visible: SoundFx.eeData
        title: I18n.tr("Перенос из EasyEffects")
        icon: "move_down"
        SRow {
            icon: "move_down"
            title: I18n.tr("Найти настройки эквалайзера")
            desc: I18n.tr("Текущее состояние и сохранённые пресеты станут наборами Cove")
            separator: SoundFx.imported.length > 0
            SButton { text: SoundFx.importing ? I18n.tr("Ищу…") : I18n.tr("Найти"); onClicked: SoundFx.scanEasyEffects() }
        }
        Repeater {
            model: SoundFx.imported
            SRow {
                required property var modelData
                required property int index
                icon: "equalizer"
                title: modelData.name
                desc: I18n.tr("{0} полос", modelData.bands.length)
                    + (modelData.skipped.length ? I18n.tr(" · не переносится: ") + modelData.skipped.join(", ") : "")
                separator: index < SoundFx.imported.length - 1
                SButton { text: I18n.tr("Взять"); primary: true; onClicked: SoundFx.takeImported(modelData) }
            }
        }
    }
}
