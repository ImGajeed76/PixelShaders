<script lang="ts">
    import {device, init} from "$lib/gpu";
    import {onMount} from "svelte";
    import {writable} from "svelte/store";

    const canvas = writable<HTMLCanvasElement | null>(null);

    const pixel_function = writable(`
        fn pixel_shader(Position: vec2<f32>, Time: f32) -> vec3<f32> {
            let result: f32 = Position.y - sin(Position.x);

            let distance: f32 = abs(result);
            let threshold: f32 = 0.01;
            let color: f32 = 1-min(distance, threshold) / threshold;
            return vec3<f32>(color, color, color);
        }
    `)

    let currentRun = 0;

    async function draw() {
        if (!$device) return;
        if (!$canvas) return;
        $canvas.width = $canvas.clientWidth;
        $canvas.height = $canvas.clientHeight;

        const context = $canvas.getContext("webgpu");

        if (!context) return;
        const presentationFormat = navigator.gpu.getPreferredCanvasFormat();
        context.configure({
            device: $device,
            format: presentationFormat,
            size: [$canvas.width, $canvas.height]
        });

        let kernel_shader = await fetch("/shaders/kernel.wgsl").then(r => r.text());
        const screen_shader = await fetch("/shaders/shader.wgsl").then(r => r.text());

        kernel_shader += $pixel_function;

        currentRun++;

        // Create Assets
        const color_buffer = $device.createTexture({
            size: [$canvas.width, $canvas.height, 1],
            format: "rgba8unorm",
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING
        });

        const color_buffer_view = color_buffer.createView();

        const sampler = $device.createSampler({
            addressModeU: "repeat",
            addressModeV: "repeat",
            magFilter: "linear",
            minFilter: "nearest",
            mipmapFilter: "nearest",
            maxAnisotropy: 1
        });

        // pipeline
        const timeBuffer = $device.createBuffer({
            size: 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true
        });
        new Float32Array(timeBuffer.getMappedRange()).set([0.0]);
        timeBuffer.unmap();

        const compute_bind_group_layout = $device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba8unorm",
                        viewDimension: "2d"
                    }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: 'uniform'
                    }
                }
            ]
        })

        const compute_bind_group = $device.createBindGroup({
            layout: compute_bind_group_layout,
            entries: [
                {
                    binding: 0,
                    resource: color_buffer_view
                },
                {
                    binding: 1,
                    resource: {
                        buffer: timeBuffer
                    }
                }
            ]
        })

        const compute_pipeline_layout = $device.createPipelineLayout({
            bindGroupLayouts: [compute_bind_group_layout]
        })

        const compute_pipeline = $device.createComputePipeline({
            layout: compute_pipeline_layout,
            compute: {
                module: $device.createShaderModule({
                    code: kernel_shader
                }),
                entryPoint: "main"
            }
        })

        const screen_bind_group_layout = $device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {}
                }
            ]
        })

        const screen_bind_group = $device.createBindGroup({
            layout: screen_bind_group_layout,
            entries: [
                {
                    binding: 0,
                    resource: sampler
                },
                {
                    binding: 1,
                    resource: color_buffer_view
                }
            ]
        })

        const screen_pipeline_layout = $device.createPipelineLayout({
            bindGroupLayouts: [screen_bind_group_layout]
        })

        const screen_pipeline = $device.createRenderPipeline({
            layout: screen_pipeline_layout,
            vertex: {
                module: $device.createShaderModule({
                    code: screen_shader
                }),
                entryPoint: "vs_main",
            },
            fragment: {
                module: $device.createShaderModule({
                    code: screen_shader
                }),
                entryPoint: "fs_main",
                targets: [
                    {
                        format: presentationFormat
                    }
                ]
            },
            primitive: {
                topology: "triangle-list"
            },
        })

        const currentRunId = currentRun;

        const render = (timestamp) => {
            if (!$device) return;
            if (!$canvas) return;
            if (currentRunId !== currentRun) return;

            let timeValue = timestamp * 0.001;
            $device.queue.writeBuffer(timeBuffer, 0, new Float32Array([timeValue]));

            const commandEncoder = $device.createCommandEncoder();

            const computePass = commandEncoder.beginComputePass();
            computePass.setPipeline(compute_pipeline);
            computePass.setBindGroup(0, compute_bind_group);
            computePass.dispatchWorkgroups($canvas.width, $canvas.height, 1);
            computePass.end();

            const textureView = context.getCurrentTexture().createView();
            const renderPass = commandEncoder.beginRenderPass({
                colorAttachments: [
                    {
                        view: textureView,
                        loadValue: {r: 96 / 255, g: 165 / 255, b: 250 / 255, a: 1},
                        storeOp: "store",
                        loadOp: "clear"
                    }
                ]
            });
            renderPass.setPipeline(screen_pipeline);
            renderPass.setBindGroup(0, screen_bind_group);
            renderPass.draw(6, 1, 0, 0);
            renderPass.end();

            $device.queue.submit([commandEncoder.finish()]);

            requestAnimationFrame(render);
        }

        requestAnimationFrame(render);
    }

    onMount(async () => {
        await init(navigator);
        await draw();
    });

    pixel_function.subscribe(() => {
        if (!$canvas) return;
        if (!$device) return;
        draw();
    });
</script>

<div class="h-screen w-screen p-20 grid grid-cols-[auto_1fr]">
    <canvas class="w-full h-full bg-black rounded-2xl shadow-2xl" bind:this={$canvas}></canvas>
    <div class="w-[30rem] ml-5 grid grid-rows-[1fr_auto]">
        <div class="w-full h-full rounded-2xl overflow-hidden">
            <textarea class="w-full h-full bg-gray-800 border-none" bind:value={$pixel_function}></textarea>
        </div>
    </div>
</div>
