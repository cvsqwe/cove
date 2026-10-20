import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Печать на скорость, как MonkeyType: время идёт с первой буквы, пробел — следующее слово,
// Backspace — стереть (Ctrl — слово), Tab — заново. Рекорд — WPM для каждого языка и длительности.
Item {
    id: root
    property bool active: false
    property string lang: Settings.general.language === "en" ? "en" : "ru"
    property int duration: 30
    readonly property string status: running ? Math.ceil(remain) + I18n.tr(" с · ") + liveWpm + " WPM"
        : finished ? "" : (lang === "ru" ? I18n.tr("Русский") : "English") + " · " + duration + I18n.tr(" с")
    readonly property string bestKey: "typing-" + lang + "-" + duration
    readonly property bool lowerBetter: false
    function bestText(v: real): string { return Math.round(v) + " WPM"; }
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)

    focus: true
    onLangChanged: restart()
    onDurationChanged: restart()

    readonly property var dict: ({
        ru: ("и в не на я быть он с что а по это она этот к но они мы как из у который то за свой весь год от так о для ты же все тот мочь вы человек такой его сказать только или ещё бы себя один как уже до время если сам когда другой вот говорить наш мой знать стать при чтобы дело жизнь кто первый очень два день её новый рука даже во со раз где там под можно ну какой после их работа без самый потом надо хотеть ли слово идти большой должен место иметь ничто то сейчас тут лицо каждый друг нет теперь ни глаз тоже тогда видеть вопрос через да здесь дом да потому сторона какой-то думать сделать страна жить чем мир об последний случай голова более делать что-то смотреть ребёнок просто конечно сила российский конец перед несколько вид система всегда работать между три нет понять пойти часть спросить город дать также никто понимать получить отношение лишь второй именно значит дорога вода ночь утро свет окно путь слово книга музыка море небо игра шаг лес ветер снег дождь звезда")
            .split(" "),
        en: ("the be to of and a in that have i it for not on with he as you do at this but his by from they we say her she or an will my one all would there their what so up out if about who get which go me when make can like time no just him know take people into year your good some could them see other than then now look only come its over think also back after use two how our work first well way even new want because any these give day most us is was are been has had were said did made find long down call may part world still life great place man thing tell hand high keep last never start city show play small house run point light group read word home open water night book")
            .split(" ")
    })

    property var words: []
    property var typed: []          // набранное по словам
    property int wi: 0              // текущее слово
    property bool running: false
    property bool finished: false
    property real startedAt: 0
    property real remain: duration
    property int keys: 0
    property int keysOk: 0
    property int rev: 0

    function gen(n: int): var {
        const d = dict[lang], out = [];
        for (let i = 0; i < n; i++) {
            let w;
            do { w = d[Math.floor(Math.random() * d.length)]; } while (out.length && out[out.length - 1] === w);
            out.push(w);
        }
        return out;
    }
    function restart(): void {
        words = gen(120);
        typed = [""];
        wi = 0; running = false; finished = false; remain = duration; keys = 0; keysOk = 0;
        rev++;
        root.forceActiveFocus();
    }
    Component.onCompleted: restart()

    // правильные символы: целиком верные слова + пробелы между ними, плюс верный префикс текущего
    function correctChars(): int {
        let n = 0;
        for (let i = 0; i < wi; i++) if (typed[i] === words[i]) n += words[i].length + 1;
        const cur = typed[wi] ?? "";
        for (let k = 0; k < cur.length && k < words[wi].length && cur[k] === words[wi][k]; k++) n++;
        return n;
    }
    function elapsed(): real { return running || finished ? Math.max(0.5, (finished ? duration : (Date.now() - startedAt) / 1000)) : 0; }
    readonly property int liveWpm: { void rev; void remain; const e = elapsed(); return e > 0 ? Math.round(correctChars() / 5 / (e / 60)) : 0; }
    property int resWpm: 0
    property int resRaw: 0
    property int resAcc: 0

    function finish(): void {
        running = false;
        finished = true;
        let all = 0;
        for (let i = 0; i <= wi; i++) all += (typed[i] ?? "").length + (i < wi ? 1 : 0);
        resWpm = Math.round(correctChars() / 5 / (duration / 60));
        resRaw = Math.round(all / 5 / (duration / 60));
        resAcc = keys > 0 ? Math.round(keysOk / keys * 100) : 0;
        sfx("win");
        record(resWpm);
    }
    Timer {
        running: root.active && root.running
        interval: 100
        repeat: true
        onTriggered: {
            root.remain = Math.max(0, root.duration - (Date.now() - root.startedAt) / 1000);
            if (root.remain <= 0) root.finish();
        }
    }

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Tab) { restart(); e.accepted = true; return; }
        if (finished) { if (e.key === Qt.Key_Return || e.key === Qt.Key_Space) restart(); e.accepted = true; return; }
        const t = typed.slice();
        let cur = t[wi] ?? "";
        if (e.key === Qt.Key_Backspace) {
            if (e.modifiers & Qt.ControlModifier) cur = "";
            else if (cur.length) cur = cur.slice(0, -1);
            else if (wi > 0 && t[wi - 1] !== words[wi - 1]) { t.pop(); wi--; typed = t; rev++; e.accepted = true; return; }   // вернуться в слово с ошибкой
            t[wi] = cur; typed = t; rev++; e.accepted = true; return;
        }
        if (e.key === Qt.Key_Space) {
            if (cur.length === 0) { e.accepted = true; return; }
            keys++;
            if (cur === words[wi]) keysOk++;
            else sfx("err");
            t.push("");
            wi++;
            typed = t;
            if (wi > words.length - 30) words = words.concat(gen(60));
            rev++;
            e.accepted = true;
            return;
        }
        const ch = e.text;
        if (!ch || ch.length !== 1 || ch < " " || (e.modifiers & (Qt.ControlModifier | Qt.AltModifier))) return;
        if (!running) { running = true; startedAt = Date.now(); }
        keys++;
        if (ch === words[wi][cur.length]) { keysOk++; sfx("key"); }
        else sfx("err");
        if (cur.length < words[wi].length + 12) cur += ch;
        t[wi] = cur;
        typed = t;
        rev++;
        e.accepted = true;
    }

    // раскладка не та: печатаешь латиницей по русским словам или наоборот
    readonly property bool wrongLayout: (lang === "ru" && Hypr.layout !== "RU") || (lang === "en" && Hypr.layout === "RU")

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(900, parent.width - 80)
        spacing: 26
        visible: !root.finished

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            SSegment {
                options: [{ value: "ru", label: "RU" }, { value: "en", label: "EN" }]
                current: root.lang
                onPicked: v => root.lang = v
            }
            SSegment {
                options: [{ value: 15, label: "15" }, { value: 30, label: "30" }, { value: 60, label: "60" }, { value: 120, label: "120" }]
                current: root.duration
                onPicked: v => root.duration = v
            }
        }

        // таймер крупно, как у MonkeyType
        StyledText {
            Layout.preferredHeight: 40
            text: root.running ? Math.ceil(root.remain) : ""
            font.pixelSize: 32
            font.bold: true
            color: Theme.accent
        }

        // слова: три строки, текущая — вторая
        Item {
            id: viewport
            readonly property real lineH: Math.round(fontPx * 1.75)
            readonly property int fontPx: 28
            Layout.fillWidth: true
            implicitHeight: lineH * 3 + flow.spacing * 2
            clip: true

            Flow {
                id: flow
                width: parent.width
                spacing: 14
                readonly property Item curItem: { void root.rev; return rep.itemAt(root.wi); }
                y: -Math.max(0, (curItem?.y ?? 0) - viewport.lineH - spacing)
                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Repeater {
                    id: rep
                    model: root.words
                    Row {
                        id: word
                        required property string modelData
                        required property int index
                        readonly property string got: { void root.rev; return root.typed[index] ?? ""; }
                        readonly property bool current: { void root.rev; return index === root.wi; }
                        readonly property bool past: { void root.rev; return index < root.wi; }
                        height: viewport.lineH
                        // буквы слова
                        Repeater {
                            model: Math.max(word.modelData.length, word.got.length)
                            Item {
                                required property int index
                                readonly property string want: word.modelData[index] ?? ""
                                readonly property string have: word.got[index] ?? ""
                                width: ch.implicitWidth
                                height: viewport.lineH
                                StyledText {
                                    id: ch
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.want || parent.have
                                    font.pixelSize: viewport.fontPx
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: parent.have === "" ? (word.past ? Theme.red : Theme.overlay0)
                                        : parent.want === "" ? Theme.alpha(Theme.red, 0.7)          // лишние буквы
                                        : parent.have === parent.want ? Theme.text : Theme.red
                                }
                                // каретка перед буквой
                                Rectangle {
                                    visible: word.current && index === word.got.length
                                    x: -1
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2.5
                                    height: viewport.fontPx * 1.15
                                    radius: 1
                                    color: Theme.accent
                                    SequentialAnimation on opacity {
                                        running: !root.running
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1; to: 0; duration: 500 }
                                        NumberAnimation { from: 0; to: 1; duration: 500 }
                                    }
                                }
                            }
                        }
                        // каретка в конце слова
                        Rectangle {
                            visible: word.current && word.got.length >= word.modelData.length
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2.5
                            height: viewport.fontPx * 1.15
                            radius: 1
                            color: Theme.accent
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.wrongLayout ? I18n.tr("Раскладка сейчас ") + Hypr.layout + I18n.tr(" — переключи на ") + root.lang.toUpperCase()
                : I18n.tr("Tab — заново · пробел — следующее слово")
            color: root.wrongLayout ? Theme.yellow : Theme.overlay0
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // ---- результат ----
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.finished
        spacing: 18
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 48
            Repeater {
                model: [["wpm", root.resWpm, Theme.accent], [I18n.tr("точность"), root.resAcc + "%", Theme.green], ["raw", root.resRaw, Theme.subtext0]]
                ColumnLayout {
                    required property var modelData
                    spacing: 0
                    StyledText { text: parent.modelData[0]; color: Theme.overlay1; font.pixelSize: 18 }
                    StyledText { text: parent.modelData[1]; color: parent.modelData[2]; font.pixelSize: 64; font.bold: true }
                }
            }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: (root.lang === "ru" ? I18n.tr("Русский") : "English") + " · " + root.duration + I18n.tr(" с · слов: ") + root.wi
            color: Theme.subtext0
        }
        SButton { Layout.alignment: Qt.AlignHCenter; primary: true; icon: "refresh"; text: I18n.tr("Ещё раз (Tab)"); onClicked: root.restart() }
    }
}
