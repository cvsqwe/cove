import QtQuick
import QtQuick.Layouts
import qs.config

// Дашборд: плеер (или приветствие), календарь, погода и курсы.
RowLayout {
    property bool shown: false

    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
    spacing: 14

    MediaCard { Layout.alignment: Qt.AlignTop }
    Calendar { Layout.alignment: Qt.AlignTop }
    WeatherCard { Layout.alignment: Qt.AlignTop }
    SysmonCard { Layout.alignment: Qt.AlignTop }
}
