// shaders/shine.glsl
extern float u_time;
extern float u_width;
extern vec4 u_color;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
    vec4 texColor = Texel(texture, texture_coords);
    
    // Calcular la posición local en el ancho del ítem
    float localX = texture_coords.x * u_width;
    
    // El punto brillante se mueve de izquierda a derecha (sin(u_time) oscila entre -1 y 1)
    float center = (sin(u_time * 2.0) * 0.5 + 0.5) * u_width;
    
    // Crear un pico de luz usando una campana de Gauss (más pequeña es la división, más estrecho es el brillo)
    float shine = exp(-pow((localX - center), 2.0) / 100.0);
    
    // Mezclar el color original con el brillo blanco (usando blend mode additive o sumando)
    vec4 shineColor = vec4(1.0, 1.0, 1.0, shine * 0.8);
    
    // Si el píxel es transparente, no aplicar el brillo
    return texColor + shineColor * texColor.a;
}
