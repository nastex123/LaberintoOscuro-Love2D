extern vec2 playerPos;
extern float radius;
extern float angleA;
extern float angleB;
extern float arcWidth;

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord) {
    vec2 dir = pixcoord - playerPos;
    float dist = length(dir);
    float pixelAngle = atan(dir.y, dir.x);

    float edge = arcWidth * 0.5;
    float radDist = abs(dist - radius);
    if (radDist > edge) return vec4(0.0);

    float pi = 3.14159265;
    float a = mod(angleA + pi, 2.0 * pi);
    float b = mod(angleB + pi, 2.0 * pi);
    float p = mod(pixelAngle + pi, 2.0 * pi);

    float span = b - a;
    if (span > pi) span = span - 2.0 * pi;
    if (span < -pi) span = span + 2.0 * pi;

    if (abs(span) < 0.001) return vec4(0.0);

    float angDist = p - a;
    if (angDist > pi) angDist = angDist - 2.0 * pi;
    if (angDist < -pi) angDist = angDist + 2.0 * pi;

    float t = angDist / span;
    if (t < 0.0 || t > 1.0) return vec4(0.0);

    float radFade = 1.0 - radDist / edge;
    float angFade = smoothstep(0.0, 1.0, t);
    vec3 arcColor = mix(vec3(1.0, 0.3, 0.0), vec3(1.0, 1.0, 0.9), angFade);
    float alpha = radFade * 0.6 * (0.3 + 0.7 * angFade);

    return vec4(arcColor, alpha);
}
