import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

SPage {
    id: page
    title: I18n.tr("Окна")
    subtitle: I18n.tr("Отступы, рамки, эффекты и раскладка Hyprland. Применяется за полсекунды.")

    readonly property var w: Settings.windows

    SCard {
        title: I18n.tr("Расположение")
        icon: "󰕰"
        SRow {
            icon: "󰕴"
            title: I18n.tr("Раскладка")
            desc: page.w.layout === "dwindle" ? I18n.tr("Окна делят место пополам, спиралью") : page.w.layout === "master" ? I18n.tr("Одно главное окно, остальные — стопкой") : I18n.tr("Окна лентой, листаются вбок")
            SSegment {
                options: [{ value: "dwindle", label: I18n.tr("Спираль") }, { value: "master", label: I18n.tr("Мастер") }, { value: "scrolling", label: I18n.tr("Лента") }]
                current: page.w.layout
                onPicked: v => page.w.layout = v
            }
        }
        SRow {
            icon: "󰹞"
            title: I18n.tr("Отступ между окнами")
            SSlider { from: 0; to: 30; step: 1; value: page.w.gapsIn; suffix: " px"; onMoved: v => page.w.gapsIn = v }
        }
        SRow {
            icon: "󰹟"
            title: I18n.tr("Отступ от краёв экрана")
            separator: false
            SSlider { from: 0; to: 50; step: 1; value: page.w.gapsOut; suffix: " px"; onMoved: v => page.w.gapsOut = v }
        }
    }

    SCard {
        title: I18n.tr("Рамки и формы")
        icon: "󰢡"
        SRow {
            icon: "󰢡"
            title: I18n.tr("Скругление окон")
            SSlider { from: 0; to: 30; step: 1; value: page.w.rounding; suffix: " px"; onMoved: v => page.w.rounding = v }
        }
        SRow {
            icon: "󰝤"
            title: I18n.tr("Толщина рамки")
            SSlider { from: 0; to: 6; step: 1; value: page.w.borderSize; suffix: " px"; onMoved: v => page.w.borderSize = v }
        }
        SRow {
            icon: "󰸌"
            title: I18n.tr("Градиентная рамка")
            desc: I18n.tr("Переход между двумя акцентными цветами")
            SSwitch { checked: page.w.borderGradient; onToggled: v => page.w.borderGradient = v }
        }
        SRow {
            icon: "󱩖"
            title: I18n.tr("Свечение активного окна")
            separator: false
            SSwitch { checked: page.w.glow; onToggled: v => page.w.glow = v }
        }
    }

    SCard {
        title: I18n.tr("Эффекты")
        icon: "󰂵"
        SRow {
            icon: "󰂵"
            title: I18n.tr("Размытие фона")
            SSwitch { checked: page.w.blur; onToggled: v => page.w.blur = v }
        }
        SRow {
            visible: page.w.blur
            icon: "󰋙"
            title: I18n.tr("Сила размытия")
            SSlider { from: 1; to: 16; step: 1; value: page.w.blurSize; onMoved: v => page.w.blurSize = v }
        }
        SRow {
            visible: page.w.blur
            icon: "󰑓"
            title: I18n.tr("Проходов")
            desc: I18n.tr("Больше — мягче, но тяжелее для видеокарты")
            SSlider { from: 1; to: 5; step: 1; value: page.w.blurPasses; onMoved: v => page.w.blurPasses = v }
        }
        SRow {
            icon: "󰘷"
            title: I18n.tr("Тени")
            SSwitch { checked: page.w.shadow; onToggled: v => page.w.shadow = v }
        }
        SRow {
            visible: page.w.shadow
            icon: "󰘷"
            title: I18n.tr("Размер тени")
            SSlider { from: 2; to: 50; step: 1; value: page.w.shadowRange; suffix: " px"; onMoved: v => page.w.shadowRange = v }
        }
        SRow {
            icon: "󰃟"
            title: I18n.tr("Прозрачность активного окна")
            SSlider { from: 0.6; to: 1; step: 0.01; value: page.w.activeOpacity; percent: true; onMoved: v => page.w.activeOpacity = v }
        }
        SRow {
            icon: "󰃝"
            title: I18n.tr("Прозрачность неактивных")
            SSlider { from: 0.5; to: 1; step: 0.01; value: page.w.inactiveOpacity; percent: true; onMoved: v => page.w.inactiveOpacity = v }
        }
        SRow {
            icon: "󰹏"
            title: I18n.tr("Затемнять неактивные")
            SSwitch { checked: page.w.dimInactive; onToggled: v => page.w.dimInactive = v }
        }
        SRow {
            visible: page.w.dimInactive
            icon: "󰹏"
            title: I18n.tr("Сила затемнения")
            separator: false
            SSlider { from: 0.05; to: 0.6; step: 0.01; value: page.w.dimStrength; percent: true; onMoved: v => page.w.dimStrength = v }
        }
    }

    SCard {
        title: I18n.tr("Анимация окон")
        icon: "󰑮"
        SRow {
            icon: "󰑮"
            title: I18n.tr("Появление окон")
            SSegment {
                options: [{ value: "popin", label: I18n.tr("Всплытие") }, { value: "slide", label: I18n.tr("Выезд") }, { value: "gnomed", label: I18n.tr("Джинн") }, { value: "fade", label: I18n.tr("Растворение") }]
                current: page.w.animation
                onPicked: v => page.w.animation = v
            }
        }
        SRow {
            icon: "󰊴"
            title: I18n.tr("Авто-игровой режим")
            desc: I18n.tr("Когда игра на весь экран — без эффектов, анимаций и уведомлений")
            separator: false
            SSwitch { checked: page.w.gameMode; onToggled: v => page.w.gameMode = v }
        }
    }
}
