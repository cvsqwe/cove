import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

SPage {
    id: page
    title: I18n.tr("Динамический остров")
    subtitle: I18n.tr("Капсула в центре панели. Здесь — что она показывает и на что реагирует.")

    readonly property var i: Settings.island

    SCard {
        title: I18n.tr("В покое")
        icon: "󰥔"

        SRow {
            icon: "󰋜"
            title: I18n.tr("Что показывать")
            SSegment {
                options: [{ value: "clock", label: I18n.tr("Часы") }, { value: "weather", label: I18n.tr("Погода") }, { value: "greeting", label: I18n.tr("Приветствие") }]
                current: page.i.idle
                onPicked: v => page.i.idle = v
            }
        }
        SRow {
            icon: "󰥔"
            title: I18n.tr("Формат времени")
            SSegment {
                options: [{ value: "HH:mm", label: "14:05" }, { value: "HH:mm:ss", label: "14:05:09" }, { value: "h:mm AP", label: "2:05 PM" }]
                current: page.i.clockFormat
                onPicked: v => page.i.clockFormat = v
            }
        }
        SRow {
            icon: "󰃭"
            title: I18n.tr("Дата")
            SSwitch { checked: page.i.showDate; onToggled: v => page.i.showDate = v }
        }
        SRow {
            visible: page.i.showDate
            icon: "󰸗"
            title: I18n.tr("Формат даты")
            separator: false
            SDropdown {
                options: [
                    { value: "ddd, d MMMM", label: I18n.tr("чт, 15 октября") },
                    { value: "dddd, d MMMM", label: I18n.tr("четверг, 15 октября") },
                    { value: "d MMM", label: I18n.tr("15 окт") },
                    { value: "dd.MM.yyyy", label: "15.10.2026" },
                    { value: "ddd dd.MM", label: I18n.tr("чт 15.10") }
                ]
                current: page.i.dateFormat
                onPicked: v => page.i.dateFormat = v
            }
        }
    }

    SCard {
        title: I18n.tr("Реакции")
        icon: "󱐋"

        SRow {
            icon: "󰎆"
            title: I18n.tr("Спектр в капсуле")
            desc: I18n.tr("Живой эквалайзер рядом с названием трека")
            SSwitch { checked: page.i.visualizer; onToggled: v => page.i.visualizer = v }
        }
        SRow {
            icon: "󰕾"
            title: I18n.tr("Громкость в острове")
            SSwitch { checked: page.i.osd; onToggled: v => page.i.osd = v }
        }
        SRow {
            icon: "󰍹"
            title: I18n.tr("Номер воркспейса при переключении")
            SSwitch { checked: page.i.workspaceToast; onToggled: v => page.i.workspaceToast = v }
        }
        SRow {
            icon: "󰌌"
            title: I18n.tr("Флаг раскладки при смене")
            SSwitch { checked: page.i.layoutToast; onToggled: v => page.i.layoutToast = v }
        }
        SRow {
            icon: "󰪛"
            title: "Caps Lock"
            SSwitch { checked: page.i.capsToast; onToggled: v => page.i.capsToast = v }
        }
        SRow {
            icon: "󰹑"
            title: I18n.tr("Превью скриншота")
            desc: I18n.tr("Миниатюра с кнопками «Открыть», «Изменить», «Папка», «Удалить»")
            SSwitch { checked: page.i.screenshotPreview; onToggled: v => page.i.screenshotPreview = v }
        }
        SRow {
            icon: "󰁌"
            title: I18n.tr("Раскрывать при наведении")
            desc: I18n.tr("Кнопки плеера и быстрые действия: скриншот, запись, пипетка, «Не беспокоить»…")
            SSwitch { checked: page.i.peek; onToggled: v => page.i.peek = v }
        }
        SRow {
            icon: "󰏫"
            title: I18n.tr("Редактор после скриншота")
            desc: I18n.tr("Сразу открывать satty: стрелки, текст, размытие, обрезка")
            SSwitch { checked: page.i.screenshotEditor; onToggled: v => page.i.screenshotEditor = v }
        }
        SRow {
            icon: "event"
            title: I18n.tr("Ближайшее событие календаря")
            desc: I18n.tr("За час до начала — «через 25 мин» в капсуле (календари — в разделе «Время»)")
            SSwitch { checked: page.i.agenda; onToggled: v => page.i.agenda = v }
        }
        SRow {
            icon: "music_note"
            title: I18n.tr("Плеер в острове")
            desc: I18n.tr("Трек и обложка в капсуле; выключите, например, на время записи экрана")
            SSwitch { checked: page.i.media; onToggled: v => page.i.media = v }
        }
        SRow {
            visible: page.i.media
            icon: "lyrics"
            title: I18n.tr("Текст песни")
            desc: I18n.tr("Звучащая строка вместо названия трека. Тексты — из открытой базы LRCLIB")
            SSwitch { checked: page.i.lyrics; onToggled: v => page.i.lyrics = v }
        }
        SRow {
            icon: "privacy_tip"
            title: I18n.tr("Кто включил микрофон или камеру")
            desc: I18n.tr("Имя приложения на пару секунд; точки-индикаторы видны всегда")
            SSwitch { checked: page.i.privacyToast; onToggled: v => page.i.privacyToast = v }
        }
        SRow {
            icon: "󰣐"
            title: I18n.tr("Приветствие при входе")
            desc: I18n.tr("«Доброе утро, …» на пару секунд после запуска")
            separator: false
            SSwitch { checked: page.i.greeting; onToggled: v => page.i.greeting = v }
        }
    }

    SCard {
        title: I18n.tr("Полка")
        icon: "inventory_2"
        SRow {
            icon: "drag_pan"
            title: I18n.tr("Полка для файлов")
            desc: I18n.tr("Перетащите файл, текст или ссылку на остров, потом вытащите в нужное окно")
            SSwitch { checked: page.i.shelf; onToggled: v => page.i.shelf = v }
        }
        SRow {
            visible: page.i.shelf
            icon: "output"
            title: I18n.tr("Убирать с полки после перетаскивания")
            desc: I18n.tr("Вернули плитку на остров — останется. Выключено — лежит, пока не уберёте сами")
            SSwitch { checked: page.i.shelfRemove; onToggled: v => page.i.shelfRemove = v }
        }
        SRow {
            visible: page.i.shelf
            icon: "stacks"
            title: I18n.tr("Сколько держать на полке")
            separator: false
            SSlider { from: 5; to: 100; step: 5; value: page.i.shelfMax; onMoved: v => page.i.shelfMax = v }
        }
    }

    SCard {
        title: I18n.tr("Уведомления в острове")
        icon: "󰂚"
        SRow {
            icon: "󱎫"
            title: I18n.tr("Сколько показывать")
            separator: false
            SSlider { from: 1; to: 20; step: 1; value: page.i.notifTimeout; suffix: I18n.tr(" с"); onMoved: v => page.i.notifTimeout = v }
        }
    }
}
