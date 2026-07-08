// water1.glsl - Animated pixel water shader (world-space stationary)
extern float u_time;
extern vec2 u_resolution;
extern vec2 u_camera;
extern float u_pixelCount;
extern float u_waterSpeed;
extern float u_distortion;
extern float u_waterScale;

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord)
{
    vec2 uv = (pixcoord + u_camera) / u_resolution / u_waterScale;
    float aspect = u_resolution.x / u_resolution.y;
    vec2 gridSize = vec2(u_pixelCount * aspect, u_pixelCount);

    vec2 pixelUv = floor(uv * gridSize) / gridSize;

    float time = u_time * u_waterSpeed;

    float wave1 = sin(pixelUv.x * 8.0 + pixelUv.y * 4.0 + time * 1.5);
    float wave2 = sin(pixelUv.x * 5.0 - pixelUv.y * 7.0 + time * 1.2);

    vec2 distortion = vec2(wave1, wave2) * u_distortion;
    vec2 finalUv = pixelUv + distortion;

    float height = sin(finalUv.x * 10.0 + finalUv.y * 5.0 + time * 2.0);
    height += sin(finalUv.x * 7.0 - finalUv.y * 9.0 + time * 1.8) * 0.5;
    height += sin((finalUv.x + finalUv.y) * 8.0 + time * 2.5) * 0.3;
    height = height / 1.8;

    vec3 waterColor;
    if (height < -0.6) {
        waterColor = vec3(0.02, 0.05, 0.20);
    } else if (height < -0.25) {
        waterColor = vec3(0.05, 0.15, 0.40);
    } else if (height < 0.10) {
        waterColor = vec3(0.10, 0.35, 0.65);
    } else if (height < 0.50) {
        waterColor = vec3(0.40, 0.75, 0.95);
    } else {
        waterColor = vec3(0.90, 0.98, 1.00);
    }

    return vec4(waterColor, 1.0);
}
