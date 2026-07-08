// splash1.glsl - Water splash/ripple overlay (blend mode: add)
extern float u_time;
extern vec2 u_resolution;
extern vec2 u_camera;
extern vec2 u_playerWorld;
extern float u_inWater;
extern float u_splashProgress;
extern vec2 u_splashWorld;
extern Image u_waterMask;
extern float u_splashPixelCount;
extern float u_splashCenterRadius;
extern float u_ringBaseRadius;
extern float u_ringPulseSpeed;
extern float u_splashScale;
extern float u_ringScale;

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord)
{
    vec2 uv = (pixcoord + u_camera) / u_resolution;
    float aspect = u_resolution.x / u_resolution.y;
    vec2 gridSize = vec2(u_splashPixelCount * aspect, u_splashPixelCount);
    vec2 pixelUv = floor(uv * gridSize) / gridSize;

    vec3 splashColor = vec3(0.0);
    float splashAlpha = 0.0;

    // 1. SPLASH de entrada (centro que se expande y desvanece)
    if (u_splashProgress >= 0.0) {
        vec2 splashUV = u_splashWorld / u_resolution;
        vec2 splashPixelUv = floor(splashUV * gridSize) / gridSize;
        float p = u_splashProgress;

        float dCenter = distance(pixelUv, splashPixelUv);
        float centerRadius = u_splashCenterRadius * u_splashScale * (1.0 - p * 0.5);
        if (dCenter < centerRadius && p < 0.8) {
            float intensity = (1.0 - p) * (1.0 - dCenter / centerRadius);
            splashColor = max(splashColor, vec3(0.6, 0.8, 1.0) * intensity);
            splashAlpha = max(splashAlpha, intensity * 0.8);
        }
    }

    // 2. ANILLO mientras el jugador esta en agua (solo sobre tiles de agua)
    if (u_inWater > 0.01) {
        vec2 playerUV = u_playerWorld / u_resolution;
        vec2 playerPixelUv = floor(playerUV * gridSize) / gridSize;
        float waterAlpha = u_inWater;

        vec2 maskUV = pixcoord / u_resolution;
        float isWater = Texel(u_waterMask, maskUV).r;
        float maskedAlpha = waterAlpha * step(0.5, isWater);

        if (maskedAlpha > 0.01) {
            float distToPlayer = distance(pixelUv, playerPixelUv);
            float ringRadius = u_ringBaseRadius * u_ringScale * (1.0 + sin(u_time * u_ringPulseSpeed) * 0.3);
            float ring = abs(distToPlayer - ringRadius) - 0.01;

            if (ring < 0.0 && distToPlayer < 0.3 * u_ringScale) {
                float intensity = maskedAlpha * 0.7 * (1.0 - distToPlayer / (0.3 * u_ringScale));
                splashColor = max(splashColor, vec3(0.8, 0.9, 1.0) * intensity);
                splashAlpha = max(splashAlpha, intensity);
            }

            for (int j = 0; j < 5; j++) {
                float angle2 = float(j) * 1.256 + u_time * 2.0;
                float radius2 = 0.04 * u_ringScale + sin(u_time * 4.0 + float(j)) * 0.02 * u_ringScale;
                vec2 pos2 = playerPixelUv + vec2(cos(angle2), sin(angle2)) * radius2
                          + vec2(0.0, sin(u_time * 5.0 + float(j)) * 0.02);
                float d2 = distance(pixelUv, pos2);
                if (d2 < 0.015) {
                    float intensity = maskedAlpha * 0.9;
                    splashColor = max(splashColor, vec3(1.0, 1.0, 1.0) * intensity);
                    splashAlpha = max(splashAlpha, intensity);
                }
            }
        }
    }

    return vec4(splashColor * 0.9, splashAlpha);
}
