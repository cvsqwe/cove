import QtQuick

// Три точки «загрузка»
Row {
    spacing: 7
    Repeater {
        model: 3
        Rectangle {
            required property int index
            width: 9
            height: 9
            radius: 4.5
            color: Cove.accent
            opacity: 0.25
            SequentialAnimation on opacity {
                running: parent.visible
                loops: Animation.Infinite
                PauseAnimation { duration: index * 150 }
                NumberAnimation { to: 1; duration: 300 }
                NumberAnimation { to: 0.25; duration: 300 }
                PauseAnimation { duration: (2 - index) * 150 }
            }
        }
    }
}
