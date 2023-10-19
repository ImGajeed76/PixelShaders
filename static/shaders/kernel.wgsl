struct TimeUniforms {
    Time: f32,
};

@group(0) @binding(0) var color_buffer: texture_storage_2d<rgba8unorm, write>;
@group(0) @binding(1) var<uniform> timeData: TimeUniforms;

@compute @workgroup_size(1,1,1)
fn main(@builtin(global_invocation_id) GlobalInvocationID: vec3<u32>) {

    let screen_size: vec2<u32> = textureDimensions(color_buffer);
    let screen_pos: vec2<i32> = vec2<i32>(i32(GlobalInvocationID.x), i32(GlobalInvocationID.y));

    let zoom: f32 = 200.0;
    let scaled_pos: vec2<f32> = vec2<f32>((f32(screen_pos.x) - f32(screen_size.x) / 2) / zoom, (f32(screen_pos.y) - f32(screen_size.y) / 2) / zoom);

    let pixel_color: vec3<f32> = pixel_shader(scaled_pos, timeData.Time);

    textureStore(color_buffer, screen_pos, vec4<f32>(pixel_color, 1.0));
}

