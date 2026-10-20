.pragma library
// Буква клавиши по её физическому положению, а не по раскладке: на русской раскладке
// R приходит как «К» (Qt.Key_Cyrillic_KA), и проверки вида e.key === Qt.Key_R не срабатывают.
// В Wayland nativeScanCode — код xkb = код evdev + 8.
const codes = {
    16: "q", 17: "w", 18: "e", 19: "r", 20: "t", 21: "y", 22: "u", 23: "i", 24: "o", 25: "p",
    30: "a", 31: "s", 32: "d", 33: "f", 34: "g", 35: "h", 36: "j", 37: "k", 38: "l",
    44: "z", 45: "x", 46: "c", 47: "v", 48: "b", 49: "n", 50: "m"
};
function letter(e) { return codes[e.nativeScanCode - 8] ?? ""; }
