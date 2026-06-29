// light_falloff.glsl - Falloff cuadratico mas realista (simula atenuacion de luz real)
extern vec2  lightPos;
extern number radius;
extern vec3  lightColor;
extern number falloff;
vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord) {
    float d = distance(pixcoord, lightPos);
    float norm = clamp(d / radius, 0.0, 1.0);
    float brightness = 1.0 - pow(norm, falloff);
    brightness = max(brightness, 0.0);
    return vec4(brightness * lightColor, 1.0);
}
