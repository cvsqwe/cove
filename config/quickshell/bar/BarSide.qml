import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components

// Одна сторона панели: модули по именам из Settings.bar.left / right.
// Обёртка — по стилю (Settings.bar.capsules): без капсул, капсулы по группам или у каждого модуля.
// В стиле «Капли» каждая обёртка свисает с верхнего края экрана, как остров.
RowLayout {
    id: side
    property var names: []
    property var modules: ({})
    spacing: 0   // отступы между капсулами — leftMargin, чтобы пустые капсулы не оставляли дыр

    readonly property bool drops: Theme.barDrops
    readonly property bool wing: Theme.barNotch || Theme.barIslands   // модули внутри общего крыла / таблетки
    readonly property string mode: (drops || wing) && Settings.bar.capsules === "none" ? "groups" : wing ? "groups" : Settings.bar.capsules
    readonly property bool bare: wing || mode === "none"
    readonly property var groupOf: ({
        sysmon: "info", weather: "info", clock: "info", focus: "info",
        layout: "status", network: "status", bluetooth: "status", volume: "status", mic: "status"
    })
    readonly property var segments: {
        const out = [];
        for (const n of side.names) {
            const g = side.mode === "groups" ? (side.groupOf[n] ?? "") : "", last = out[out.length - 1];
            if (g && last && last.group === g) last.names.push(n);
            else out.push({ group: g, names: [n] });
        }
        return out;
    }
    // сколько занимают модули, кроме заголовка окна (заголовку — остаток до острова, см. Bar.qml)
    readonly property real fixedWidth: {
        let w = 0;
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (it && !it.hasWindow) w += it.width + it.Layout.leftMargin;
        }
        return w;
    }
    // области кликов капель (панель в «каплях» пропускает клики между ними)
    property list<Region> regions: {
        void rep.count;
        const out = [];
        for (let i = 0; i < rep.count; i++) { const it = rep.itemAt(i); if (it) out.push(it.region); }
        return out;
    }

    Repeater {
        id: rep
        model: side.segments

        Rectangle {
            id: cap
            required property var modelData
            required property int index
            // не через visible: у скрытой капсулы и модули считаются скрытыми — замкнутая привязка
            readonly property bool shown: row.implicitWidth > 0.5
            readonly property int gap: side.drops ? 2 * Theme.dropRadius + 8 : side.wing ? 16 : side.bare ? (Settings.bar.separators ? 14 : 6) : 6
            readonly property alias region: reg
            readonly property bool hasWindow: modelData.names.includes("window")
            Region { id: reg; item: cap.shown ? cap : null }

            Layout.alignment: side.drops ? Qt.AlignTop : Qt.AlignVCenter
            Layout.leftMargin: index > 0 && shown ? gap : 0
            Layout.preferredWidth: shown ? row.implicitWidth + (side.drops ? 16 : side.bare ? 0 : 4) : 0
            opacity: shown ? 1 : 0
            // капля «оттягивается» при наведении
            implicitHeight: side.drops ? Theme.dropHeight + (hover.hovered ? 5 : 0) : Theme.capsuleHeight
            Behavior on implicitHeight { SpringAnimation { spring: 4; damping: 0.28; epsilon: 0.2 } }
            radius: side.drops ? 0 : Theme.capsuleRadius
            bottomLeftRadius: side.drops ? Theme.capsuleRadius + 2 : radius
            bottomRightRadius: bottomLeftRadius
            color: side.drops ? Theme.panel : side.bare ? "transparent" : Theme.capsule
            border.width: side.drops || side.bare ? 0 : 1
            border.color: Theme.capsuleBorder

            HoverHandler { id: hover }

            // наплывы, которыми капля «вытекает» из края экрана
            InvertedCorner {
                visible: side.drops && cap.shown
                x: -radius
                y: 0
                radius: Theme.dropRadius
                corner: "topRight"
                color: cap.color
            }
            InvertedCorner {
                visible: side.drops && cap.shown
                x: cap.width
                y: 0
                radius: Theme.dropRadius
                corner: "topLeft"
                color: cap.color
            }

            // без полосы капсулы висят над обоями — даём им тень
            RectangularShadow {
                z: -1
                anchors.fill: parent
                visible: Theme.barless && !side.bare && Theme.capsule.a > 0.5
                radius: cap.radius
                offset.y: 2
                blur: 14
                color: Qt.rgba(0, 0, 0, 0.35 * Theme.shadow)
            }

            // точка-разделитель перед модулем
            Rectangle {
                visible: side.bare && (Settings.bar.separators || side.wing) && cap.index > 0 && cap.shown
                width: 4
                height: 4
                radius: 2
                x: -cap.gap / 2 - 2
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.overlay0
            }

            RowLayout {
                id: row
                anchors.horizontalCenter: parent.horizontalCenter
                // в капле содержимое стоит на месте, оттягивается только низ
                anchors.verticalCenter: side.drops ? undefined : parent.verticalCenter
                y: side.drops ? (Theme.dropHeight - height) / 2 : 0
                spacing: 0
                Repeater {
                    model: cap.modelData.names
                    Loader {
                        required property string modelData
                        Layout.alignment: Qt.AlignVCenter
                        sourceComponent: side.modules[modelData] ?? null
                        Layout.preferredWidth: item && item.visible ? item.implicitWidth : 0
                        Layout.preferredHeight: item ? item.implicitHeight : 0
                    }
                }
            }
        }
    }
}
