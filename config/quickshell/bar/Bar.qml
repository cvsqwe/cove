import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Панель, сросшаяся с верхним краем экрана. Модули и их порядок — из Settings.bar (Настройки → Панель).
// Центр панели занимает динамический остров (island/Island.qml).
PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barBottom + (Theme.barFloating ? 24 : Theme.barDrops ? 14 : Theme.frameRadius)   // + тень / оттяжка капель
    exclusiveZone: Theme.barBottom
    color: "transparent"
    // в «каплях» клики между каплями проходят к окнам
    mask: Region { item: Theme.barDrops || Theme.barNotch ? null : body; regions: Theme.barDrops ? bar.dropRegions : Theme.barNotch ? [leftWingReg, rightWingReg] : [] }
    Region { id: leftWingReg; item: leftWing }
    Region { id: rightWingReg; item: rightWing }
    property list<Region> dropRegions: {
        const out = [];
        for (const s of [leftSide, rightSide])
            for (let i = 0; i < s.regions.length; i++) out.push(s.regions[i]);
        return out;
    }
    WlrLayershell.namespace: "qs-bar"

    IdleInhibitor {
        window: bar
        enabled: Store.caffeine
    }

    readonly property var modules: ({
        launcher: launcherC, workspaces: workspacesC, window: windowC, tray: trayC, sysmon: sysmonC,
        weather: weatherC, layout: layoutC, network: networkC, bluetooth: bluetoothC, volume: volumeC,
        mic: micC, notifs: notifsC, clock: clockC, focus: focusC, power: powerC, updates: updatesC, battery: batteryC, vpn: vpnC
    })

    Component {
        id: launcherC
        Pill {
            readonly property var b: Settings.bar
            icon: b.launcherStyle === "text" ? "" : b.launcherIcon
            label: b.launcherStyle === "icon" ? "" : b.launcherText
            pinLabel: true
            iconColor: b.launcherColor === "mono" ? Theme.barIcon : Theme.accent
            textColor: b.launcherColor === "mono" ? Theme.text : Theme.accent
            onClicked: Panels.toggle(b.launcherAction)
        }
    }
    Component { id: workspacesC; Workspaces {} }
    Component { id: windowC; ActiveWindow {
        // ровно до острова: половина экрана − половина острова − всё, что левее заголовка, − отступы
        maxWidth: Math.min(480, Math.max(0, bar.width / 2 - Panels.islandWidth / 2 - leftSide.x - leftSide.fixedWidth - 64))
    }  }
    Component { id: trayC; Tray { barWindow: bar } }
    Component { id: sysmonC; SysmonPill {} }
    Component { id: weatherC; WeatherPill {} }
    Component { id: layoutC; KbLayout {} }
    Component { id: networkC; Network {} }
    Component { id: bluetoothC; BluetoothPill {} }
    Component { id: volumeC; Volume {} }
    Component { id: micC; MicPill {} }
    Component { id: notifsC; NotifButton {} }
    Component { id: clockC; ClockPill {} }
    Component { id: focusC; FocusPill {} }
    Component { id: powerC; PowerPill {} }
    Component { id: updatesC; UpdatesPill {} }
    Component { id: batteryC; BatteryPill {} }
    Component { id: vpnC; VpnPill {} }

    RectangularShadow {
        anchors.fill: body
        visible: Theme.barFloating && Settings.bar.bodyOpacity > 0.9   // под прозрачной полосой тень видна насквозь
        radius: body.radius
        offset.y: 3
        blur: 18
        spread: 0
        color: Qt.rgba(0, 0, 0, 0.38)
    }

    Rectangle {
        id: body
        x: Theme.barMargin
        y: Theme.barTop
        width: parent.width - 2 * Theme.barMargin
        height: Theme.barHeight
        radius: Theme.barFloating ? Theme.barRadius : 0
        color: Theme.barBody
        border.width: Theme.barFloating && !Theme.barless ? 1 : 0
        border.color: Theme.surface0

        // спектр вдоль нижней кромки панели
        Visualizer {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            // только на сплошной полосе: в «Чёлке» и «Каплях» полосы нет — спектр висел бы над обоями пунктиром
            visible: Media.playing && Settings.bar.visualizerStrip && !GameMode.active
                && !Theme.barDrops && !Theme.barNotch && Settings.bar.bodyOpacity > 0.3
            opacity: 0.35
            step: 1
            spacing: (parent.width - Media.barCount * barWidth) / Media.barCount
            barWidth: 6
            maxHeight: 5
            minHeight: 0
        }

        // «Чёлка»: два стеклянных крыла под модулями
        Wing { id: leftWing; target: leftSide }
        Wing { id: rightWing; target: rightSide }

        BarSide {
            id: leftSide
            modules: bar.modules
            anchors.left: parent.left
            anchors.leftMargin: Theme.barNotch ? Theme.cardMargin + 12 : Theme.barDrops ? Theme.dropRadius + 6 : (Theme.barHeight - Theme.capsuleHeight) / 2
            anchors.verticalCenter: Theme.barDrops ? undefined : parent.verticalCenter
            anchors.verticalCenterOffset: Theme.barNotch ? -(Theme.barHeight - Theme.dropHeight) / 2 : 0
            anchors.top: Theme.barDrops ? parent.top : undefined
            names: Settings.bar.left
        }
        BarSide {
            id: rightSide
            modules: bar.modules
            anchors.right: parent.right
            anchors.rightMargin: Theme.barNotch ? Theme.cardMargin + 12 : Theme.barDrops ? Theme.dropRadius + 6 : (Theme.barHeight - Theme.capsuleHeight) / 2
            anchors.verticalCenter: Theme.barDrops ? undefined : parent.verticalCenter
            anchors.verticalCenterOffset: Theme.barNotch ? -(Theme.barHeight - Theme.dropHeight) / 2 : 0
            anchors.top: Theme.barDrops ? parent.top : undefined
            names: Settings.bar.right
        }
    }

    InvertedCorner {
        anchors.top: body.bottom
        anchors.left: parent.left
        corner: "topLeft"
        radius: Theme.frameRadius
        visible: radius > 0
        color: Theme.barBody
    }
    InvertedCorner {
        anchors.top: body.bottom
        anchors.right: parent.right
        corner: "topRight"
        radius: Theme.frameRadius
        visible: radius > 0
        color: Theme.barBody
    }
}
