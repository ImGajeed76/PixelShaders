import {writable} from "svelte/store";

export const adapter = writable<GPUAdapter | null>(null)
export const device = writable<GPUDevice | null>(null)

export async function init(navigator: Navigator): Promise<boolean> {
    if (!navigator.gpu) {
        console.error("WebGPU is not supported in your browser");
        return false;
    }

    const a = await navigator.gpu.requestAdapter();
    if (a === null) {
        console.error("No GPU adapter found");
        return false;
    }

    adapter.set(a);
    device.set(await a.requestDevice());
    return true;
}