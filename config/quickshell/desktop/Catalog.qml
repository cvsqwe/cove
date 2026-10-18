pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Каталог виджетов рабочего стола. Каждый тип — файл desktop/widgets/<file>.qml с
// property var opts / bool editing / bool shown и signal setOpt(key, value).
// style — фон по умолчанию: glass | solid | none; interactive — клики работают вне редактора.
// schema — поля инспектора: bool | seg (options) | text | num (from, to, step) | items (список задач).
Singleton {
    readonly property var types: ({
        clock: { label: I18n.tr("Часы"), icon: "󰥔", desc: I18n.tr("Большое время и дата"), file: "Clock", style: "none",
            opts: { format: "24", seconds: false, date: true, align: "left", weight: "bold" },
            schema: [
                { key: "format", label: I18n.tr("Формат"), kind: "seg", options: [{ value: "24", label: I18n.tr("24 ч") }, { value: "12", label: I18n.tr("12 ч") }] },
                { key: "weight", label: I18n.tr("Начертание"), kind: "seg", options: [{ value: "bold", label: I18n.tr("Жирное") }, { value: "light", label: I18n.tr("Тонкое") }] },
                { key: "align", label: I18n.tr("Выравнивание"), kind: "seg", options: [{ value: "left", label: I18n.tr("Слева") }, { value: "center", label: I18n.tr("Центр") }, { value: "right", label: I18n.tr("Справа") }] },
                { key: "seconds", label: I18n.tr("Секунды"), kind: "bool" },
                { key: "date", label: I18n.tr("Дата"), kind: "bool" }
            ] },
        analog: { label: I18n.tr("Стрелочные часы"), icon: "󰅐", desc: I18n.tr("Циферблат со стрелками"), file: "Analog", style: "glass",
            opts: { seconds: true, numbers: false },
            schema: [
                { key: "seconds", label: I18n.tr("Секундная стрелка"), kind: "bool" },
                { key: "numbers", label: I18n.tr("Цифры"), kind: "bool" }
            ] },
        greeting: { label: I18n.tr("Приветствие"), icon: "󰣐", desc: I18n.tr("«Добрый вечер, …», дата и погода"), file: "Greeting", style: "none",
            opts: { weather: true },
            schema: [{ key: "weather", label: I18n.tr("Погода в строке"), kind: "bool" }] },
        weather: { label: I18n.tr("Погода"), icon: "󰖐", desc: I18n.tr("Сейчас и прогноз на дни"), file: "Weather", style: "glass",
            opts: { forecast: true },
            schema: [{ key: "forecast", label: I18n.tr("Прогноз"), kind: "bool" }] },
        media: { label: I18n.tr("Плеер"), icon: "󰎆", desc: I18n.tr("Обложка, трек и кнопки"), file: "Media", style: "glass", interactive: true,
            opts: { visualizer: true },
            schema: [{ key: "visualizer", label: I18n.tr("Спектр"), kind: "bool" }] },
        visualizer: { label: I18n.tr("Спектр"), icon: "󰎇", desc: I18n.tr("Большой эквалайзер под музыку"), file: "Spectrum", style: "none",
            opts: { mirrored: true, height: 120, bars: 48 },
            schema: [
                { key: "mirrored", label: I18n.tr("От центра"), kind: "bool" },
                { key: "height", label: I18n.tr("Высота"), kind: "num", from: 40, to: 300, step: 10 }
            ] },
        rings: { label: I18n.tr("Кольца системы"), icon: "󰾆", desc: I18n.tr("CPU, RAM, GPU и температура"), file: "Rings", style: "glass",
            opts: { gpu: true, temp: true },
            schema: [
                { key: "gpu", label: "GPU", kind: "bool" },
                { key: "temp", label: I18n.tr("Температура CPU"), kind: "bool" }
            ] },
        sysmon: { label: I18n.tr("Графики системы"), icon: "󰍛", desc: I18n.tr("Нагрузка с историей"), file: "Graphs", style: "none", opts: {}, schema: [] },
        info: { label: I18n.tr("О системе"), icon: "󰣇", desc: I18n.tr("ОС, ядро, аптайм — как fastfetch"), file: "Info", style: "glass", opts: {}, schema: [] },
        calendar: { label: I18n.tr("Календарь"), icon: "󰃭", desc: I18n.tr("Месяц, листается стрелками"), file: "CalendarW", style: "none", interactive: true, opts: {}, schema: [] },
        todo: { label: I18n.tr("Задачи"), icon: "󰄲", desc: I18n.tr("Список дел с галочками"), file: "Todo", style: "glass", interactive: true,
            opts: { title: I18n.tr("Задачи"), items: [{ t: I18n.tr("Отметь меня"), d: false }, { t: I18n.tr("Добавляй задачи в редакторе"), d: false }] },
            schema: [
                { key: "title", label: I18n.tr("Заголовок"), kind: "text" },
                { key: "items", label: I18n.tr("Пункты"), kind: "items" }
            ] },
        notes: { label: I18n.tr("Заметка"), icon: "󰎞", desc: I18n.tr("Последняя заметка из ~/Notes"), file: "Note", style: "glass", opts: {}, schema: [] },
        text: { label: I18n.tr("Текст"), icon: "󰊄", desc: I18n.tr("Цитата, девиз или подпись"), file: "Text", style: "none",
            opts: { text: "Stay hungry, stay foolish", author: "", size: 34, align: "left", italic: true, accent: false },
            schema: [
                { key: "text", label: I18n.tr("Текст"), kind: "text" },
                { key: "author", label: I18n.tr("Подпись"), kind: "text" },
                { key: "size", label: I18n.tr("Размер шрифта"), kind: "num", from: 14, to: 96, step: 2 },
                { key: "align", label: I18n.tr("Выравнивание"), kind: "seg", options: [{ value: "left", label: I18n.tr("Слева") }, { value: "center", label: I18n.tr("Центр") }, { value: "right", label: I18n.tr("Справа") }] },
                { key: "italic", label: I18n.tr("Курсив"), kind: "bool" },
                { key: "accent", label: I18n.tr("Цвет акцента"), kind: "bool" }
            ] },
        countdown: { label: I18n.tr("Обратный отсчёт"), icon: "󰔟", desc: I18n.tr("Сколько дней до события"), file: "Countdown", style: "glass",
            opts: { title: I18n.tr("Новый год"), date: "2027-01-01" },
            schema: [
                { key: "title", label: I18n.tr("Событие"), kind: "text" },
                { key: "date", label: I18n.tr("Дата (ГГГГ-ММ-ДД)"), kind: "text" }
            ] },
        focus: { label: "Pomodoro", icon: "󰔛", desc: I18n.tr("Фокус-таймер, клик — старт/стоп"), file: "FocusW", style: "glass", interactive: true, opts: {}, schema: [] },
        photo: { label: I18n.tr("Фото"), icon: "󰋩", desc: I18n.tr("Картинка в рамке"), file: "Photo", style: "none",
            opts: { path: "", size: 260, shape: "rounded" },
            schema: [
                { key: "path", label: I18n.tr("Путь к файлу"), kind: "text" },
                { key: "size", label: I18n.tr("Размер"), kind: "num", from: 100, to: 600, step: 10 },
                { key: "shape", label: I18n.tr("Форма"), kind: "seg", options: [{ value: "rounded", label: I18n.tr("Скруглённая") }, { value: "circle", label: I18n.tr("Круг") }, { value: "square", label: I18n.tr("Квадрат") }] }
            ] }
,
        agenda: { label: I18n.tr("События"), icon: "calendar_month", desc: I18n.tr("Ближайшее из ваших календарей"), file: "AgendaW", style: "glass",
            opts: { title: "", days: 3, count: 6 },
            schema: [
                { key: "title", label: I18n.tr("Заголовок"), kind: "text" },
                { key: "days", label: I18n.tr("Дней вперёд"), kind: "num", from: 1, to: 14, step: 1 },
                { key: "count", label: I18n.tr("Сколько событий"), kind: "num", from: 1, to: 12, step: 1 }
            ] },
        net: { label: I18n.tr("Сеть"), icon: "lan", desc: I18n.tr("График приёма и отдачи"), file: "NetGraph", style: "glass",
            opts: { height: 90 },
            schema: [{ key: "height", label: I18n.tr("Высота графика"), kind: "num", from: 40, to: 240, step: 10 }] },
        quote: { label: I18n.tr("Цитата дня"), icon: "format_quote", desc: I18n.tr("Каждый день новая, клик — следующая"), file: "Quote", style: "none", interactive: true,
            opts: { size: 22, width: 380 },
            schema: [
                { key: "size", label: I18n.tr("Размер шрифта"), kind: "num", from: 14, to: 48, step: 2 },
                { key: "width", label: I18n.tr("Ширина"), kind: "num", from: 240, to: 800, step: 20 }
            ] }
    })

    // порядок в галерее «Добавить»
    readonly property var order: ["clock", "analog", "greeting", "weather", "media", "visualizer", "rings", "sysmon", "info",
        "calendar", "agenda", "todo", "notes", "text", "quote", "countdown", "focus", "photo", "net"]
}
