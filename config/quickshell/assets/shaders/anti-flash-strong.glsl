#version 300 es
// Защита от вспышки (Cove, Система → Ночной свет): затемняет экран, когда он в целом очень светлый
// (белый сайт ночью). Тёмные окна не трогает. Средняя яркость — по сетке 5×5 точек.
precision mediump float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float STRENGTH = 0.6;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    vec3 sum = vec3(0.0);
    for (float x = 0.1; x < 1.0; x += 0.2)
        for (float y = 0.1; y < 1.0; y += 0.2)
            sum += texture(tex, vec2(x, y)).rgb;
    float bright = dot(sum / 25.0, vec3(0.2126, 0.7152, 0.0722));
    float k = smoothstep(0.45, 0.92, bright) * STRENGTH;
    fragColor = vec4(pix.rgb * (1.0 - k), pix.a);
}
