import QtQuick
import Quickshell.Widgets
import qs.config

// Миниатюра панели для пресета: те же правила, что у настоящей (bar/BarSide.qml),
// и те же токены темы — на текущих обоях и с текущей палитрой.
ClippingRectangle {
    id: root

    property var cfg: ({})
    readonly property bool islands: cfg.style === "islands"
    readonly property bool compact: cfg.style === "compact"
    readonly property bool line: cfg.style === "line"
    readonly property bool floating: cfg.style === "floating" || islands || compact || line
    readonly property bool drops: cfg.style === "drops"
    readonly property bool notch: cfg.style === "notch"
    readonly property bool round: cfg.shape !== "soft"
    readonly property bool bare: cfg.capsules === "none" || islands
    readonly property int m: floating ? 6 : 0
    readonly property int capH: 14
    readonly property color capFill: notch ? "transparent" : drops ? Theme.base : bare ? "transparent"
        : cfg.capsuleFill === "light" ? Theme.surface0 : cfg.capsuleFill === "outline" ? "transparent" : Theme.mantle
    readonly property color capBorder: cfg.capsuleFill === "light" ? Theme.surface1 : cfg.capsuleFill === "outline" ? Theme.surface2 : Theme.surface0
    function tint(c: color): color { return cfg.iconColors === "colorful" ? c : cfg.iconColors === "accent" ? Theme.accent : Theme.subtext1; }

    // сегменты: kind — launch | ws | text | icons; n — сколько иконок, colors — их «родные» цвета
    readonly property var leftSegs: [{ kind: "launch" }, { kind: "ws" }, { kind: "text" }]
    readonly property var rightSegs: cfg.capsules === "groups"
        ? [{ kind: "icons", colors: [Theme.accent2, Theme.yellow] }, { kind: "icons", colors: [Theme.lavender, Theme.accent2, Theme.accent] }, { kind: "icons", colors: [Theme.subtext0] }]
        : [Theme.accent2, Theme.yellow, Theme.lavender, Theme.accent2, Theme.accent, Theme.subtext0].map(c => ({ kind: "icons", colors: [c] }))

    implicitWidth: 232
    implicitHeight: 58
    radius: Theme.radiusSmall
    color: Theme.crust

    Image {
        anchors.fill: parent
        source: Store.still ? "file://" + Store.still : ""
        sourceSize: Qt.size(320, 90)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // полоса
    Rectangle {
        id: bar
        visible: !root.drops && !root.notch
        x: root.compact ? 34 : root.m
        y: root.m
        width: root.width - 2 * x
        height: 20
        radius: root.floating ? (root.round ? 10 : Theme.radiusSmall) : 0
        color: root.islands || root.line ? "transparent" : Theme.alpha(Theme.base, root.cfg.bodyOpacity ?? 1)
        border.width: root.floating && !root.islands && !root.line && (root.cfg.bodyOpacity ?? 1) > 0.02 ? 1 : 0
        border.color: Theme.surface0
    }

    component Segments: Row {
        id: segs
        property var model: []
        spacing: root.bare ? (root.cfg.separators ? 8 : 4) : 3
        Repeater {
            model: segs.model
            Rectangle {
                id: seg
                required property var modelData
                required property int index
                readonly property var colors: modelData.colors ?? []
                width: modelData.kind === "launch" ? root.capH
                    : modelData.kind === "ws" ? 38
                    : modelData.kind === "text" ? 32
                    : colors.length * 9 + 5
                height: root.drops ? root.capH + 3 : root.capH
                radius: root.drops ? 0 : root.round ? height / 2 : 3
                bottomLeftRadius: root.drops ? 6 : radius
                bottomRightRadius: bottomLeftRadius
                color: root.capFill
                border.width: root.bare || root.drops || root.notch ? 0 : 1
                border.color: root.capBorder

                InvertedCorner { visible: root.drops; x: -radius; radius: 4; corner: "topRight"; color: Theme.base }
                InvertedCorner { visible: root.drops; x: seg.width; radius: 4; corner: "topLeft"; color: Theme.base }
                Rectangle {   // разделитель
                    visible: root.bare && root.cfg.separators && seg.index > 0
                    width: 2; height: 2; radius: 1
                    x: -segs.spacing / 2 - 1
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.overlay0
                }
                Rectangle {
                    visible: seg.modelData.kind === "launch"
                    anchors.centerIn: parent
                    width: 6; height: 6; radius: 3
                    color: Theme.accent
                }
                Row {
                    visible: seg.modelData.kind === "ws"
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            width: index === 0 ? 8 : 3; height: 3; radius: 1.5
                            color: index === 0 ? Theme.accent : Theme.surface2
                        }
                    }
                }
                Rectangle {
                    visible: seg.modelData.kind === "text"
                    anchors.centerIn: parent
                    width: 20; height: 3; radius: 1.5
                    color: Theme.subtext0
                }
                Row {
                    visible: seg.modelData.kind === "icons"
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                        model: seg.colors
                        Rectangle {
                            required property color modelData
                            width: 5; height: 5; radius: 2.5
                            color: root.tint(modelData)
                        }
                    }
                }
            }
        }
    }

    Rectangle { visible: root.notch; x: 4; y: 3; width: lseg.width + 10; height: root.capH + 2; radius: height / 2; color: Theme.alpha(Theme.base, 0.8) }
    Rectangle { visible: root.notch; x: rseg.x - 5; y: 3; width: rseg.width + 10; height: root.capH + 2; radius: height / 2; color: Theme.alpha(Theme.base, 0.8) }
    // «Таблетки»: у каждой стороны своя
    Rectangle { visible: root.islands; x: lseg.x - 5; y: bar.y; width: lseg.width + 10; height: bar.height; radius: root.round ? 10 : Theme.radiusSmall; color: Theme.base; border.width: 1; border.color: Theme.surface0 }
    Rectangle { visible: root.islands; x: rseg.x - 5; y: bar.y; width: rseg.width + 10; height: bar.height; radius: root.round ? 10 : Theme.radiusSmall; color: Theme.base; border.width: 1; border.color: Theme.surface0 }
    // «Линия»
    Rectangle {
        visible: root.line
        x: bar.x; y: bar.y + bar.height - 1
        width: bar.width; height: 1.5
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.accent }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Segments {
        id: lseg
        model: root.leftSegs
        x: root.drops ? 8 : root.notch ? 9 : bar.x + 3
        y: root.drops ? 0 : root.notch ? 4 : bar.y + (bar.height - root.capH) / 2
    }
    Rectangle {   // капсула острова
        anchors.horizontalCenter: bar.horizontalCenter
        y: root.drops || root.notch ? 0 : bar.y + (bar.height - height) / 2
        width: root.notch ? 60 : 44
        height: root.drops || root.notch ? root.capH + 3 : root.capH
        radius: root.drops || root.notch ? 0 : root.round ? height / 2 : 3
        bottomLeftRadius: root.drops || root.notch ? 6 : radius
        bottomRightRadius: bottomLeftRadius
        color: root.notch ? (Theme.light ? Theme.base : "#000000") : root.drops ? Theme.base : root.cfg.capsuleFill === "light" ? Theme.surface0 : root.cfg.capsuleFill === "outline" ? "transparent" : Theme.mantle
        InvertedCorner { visible: root.drops || root.notch; x: -radius; radius: 4; corner: "topRight"; color: parent.color }
        InvertedCorner { visible: root.drops || root.notch; x: parent.width; radius: 4; corner: "topLeft"; color: parent.color }
        border.width: root.drops || root.notch ? 0 : 1
        border.color: root.capBorder
        Rectangle { anchors.centerIn: parent; width: 22; height: 3; radius: 1.5; color: Theme.text }
    }
    Segments {
        id: rseg
        model: root.rightSegs
        anchors.right: bar.right
        anchors.rightMargin: root.drops ? 8 - root.m : root.notch ? 9 : 3
        y: root.drops ? 0 : root.notch ? 4 : bar.y + (bar.height - root.capH) / 2
    }
}
