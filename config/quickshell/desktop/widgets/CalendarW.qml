import QtQuick
import qs.island

Calendar {
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)
}
