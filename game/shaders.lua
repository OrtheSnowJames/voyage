local shaders = {}

function shaders.create()
    local shore_shader = love.graphics.newShader([[
    extern vec3 greenPixel;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 texcolor = Texel(tex, texture_coords);

        // Check if this pixel is close to green (0, 255, 0)
        if (abs(texcolor.r - greenPixel.r) < 0.1 &&
            abs(texcolor.g - greenPixel.g) < 0.1 &&
            abs(texcolor.b - greenPixel.b) < 0.1) {
            // Discard the pixel to make it transparent
            discard;
        }

        // Keep other pixels unchanged
        return texcolor * color;
    }
]])

    local water_shader = love.graphics.newShader([[
    extern number time;
    extern vec3 waterColor;
    extern number shoreY;
    extern vec2 camera; // x, y
    extern vec2 resolution; // width, height

    // Ripple data from the boat
    extern int ripple_count;
    extern float ripple_sources_x[10];
    extern float ripple_sources_y[10];
    extern float ripple_spawn_times[10];
    extern float ripple_intensities[10];

    // 2D Random function
    float random(vec2 st) {
        return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
    }

    // 2D Noise function
    float noise(vec2 st) {
        vec2 i = floor(st);
        vec2 f = fract(st);
        float a = random(i);
        float b = random(i + vec2(1.0, 0.0));
        float c = random(i + vec2(0.0, 1.0));
        float d = random(i + vec2(1.0, 1.0));
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.y * u.x;
    }

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec2 uv = screen_coords / resolution;

        // Approximate world coordinates for foam calculation
        float world_y = camera.y + screen_coords.y;
        float world_x = camera.x + screen_coords.x;
        vec2 world_pos = vec2(world_x, world_y);

        // Base water color
        vec3 final_color = waterColor;

        // Wave simulation using multiple layers of noise
        float wave1 = noise(uv * vec2(8.0, 4.0) + vec2(time * 0.1, time * 0.05));
        float wave2 = noise(uv * vec2(20.0, 10.0) + vec2(time * -0.05, time * 0.15));
        float wave_total = wave1 * 0.7 + wave2 * 0.3;

        // --- boat ripples ---
        float total_ripple_displacement = 0.0;
        for (int i = 0; i < ripple_count; i++) {
            vec2 ripple_source = vec2(ripple_sources_x[i], ripple_sources_y[i]);
            float dist = length(world_pos - ripple_source);
            float time_alive = time - ripple_spawn_times[i];

            if (time_alive > 0.0 && time_alive < 4.0) { // Ripples last 4 seconds
                float circle_radius = time_alive * 60.0; // speed of expansion
                float circle_width = 30.0;

                if (dist > circle_radius - circle_width && dist < circle_radius + circle_width) {
                    float ripple_shape = (dist - circle_radius) / circle_width; // -1 to 1
                    float displacement = sin(ripple_shape * 3.14159);
                    float falloff = (1.0 - smoothstep(0.0, 4.0, time_alive)) * ripple_intensities[i];
                    total_ripple_displacement += displacement * falloff;
                }
            }
        }

        float wave_total_with_ripples = wave_total + total_ripple_displacement * 0.35;

        // Add color variation based on waves
        final_color += vec(wave_total_with_ripples * 0.05);

        // Specular highlights on wave crests
        float specular = pow(noise(uv * vec2(10.0, 5.0) - vec2(time * 0.12, time * 0.08)), 18.0);
        specular *= smoothstep(0.4, 0.7, wave_total_with_ripples); // Highlights on crests
        final_color += vec3(1.0) * specular * 0.6;

        // Foam near the shore
        float dist_to_shore = world_y - (shoreY + 40.0); // Add offset to bring foam down
        if (dist_to_shore < 50.0 && dist_to_shore > 0.0) {
            float foam_factor = 1.0 - (dist_to_shore / 50.0);
            float foam_noise = noise(vec2(world_x / 30.0 + time * 0.2, time * 0.1));

            if (foam_noise > 0.65) {
                float foam_intensity = smoothstep(0.65, 0.8, foam_noise) * foam_factor;
                final_color = mix(final_color, vec3(0.9, 0.9, 1.0), foam_intensity);
            }
        }

        // Clamp final color to avoid overly bright spots
        final_color = clamp(final_color, 0.0, 1.0);

        return vec4(final_color, 1.0);
    }
]])

    return shore_shader, water_shader
end

return shaders
