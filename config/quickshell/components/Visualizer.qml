import QtQuick
import qs.config
import qs.services

// Столбики спектра из Media.bars.
// bands > 0 — столько полос, каждая берёт максимум своего участка спектра (живее, чем выборка);
// иначе — каждый step-й столбик. Размер постоянный и не зависит от текущих высот:
// иначе раскладка вокруг (остров, карточки) дрожит каждый кадр.
Item {
    id: root

    property int step: 1
    property int bands: 0
    property real barWidth: 3
    property real spacing: 2
    property real maxHeight: 16
    property real minHeight: 2
    property color color: Media.accent
    property bool mirrored: false // true — растут от центра в обе стороны
    property bool fade: false     // тихие полосы почти прозрачные — без ряда «чёрточек» в тишине

    readonly property int count: bands > 0 ? bands : Math.floor(Media.barCount / step)
    implicitWidth: count * barWidth + Math.max(0, count - 1) * spacing
    implicitHeight: maxHeight

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            model: root.count

            Rectangle {
                required property int index
                readonly property real v: {
                    if (root.bands <= 0) return Media.bars[index * root.step] ?? 0;
                    const from = Math.floor(index * Media.barCount / root.bands);
                    const to = Math.max(from + 1, Math.floor((index + 1) * Media.barCount / root.bands));
                    let m = 0;
                    for (let i = from; i < to; i++) m = Math.max(m, Media.bars[i] ?? 0);
                    return m;
                }
                y: root.mirrored ? (root.height - height) / 2 : root.height - height
                width: root.barWidth
                height: root.minHeight + Math.min(1, v) * (root.maxHeight - root.minHeight)
                radius: width / 2
                color: root.color
                opacity: root.fade ? 0.22 + 0.78 * Math.min(1, v * 2.5) : 1
                Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
            }
        }
    }
}
