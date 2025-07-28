<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import fragShaderSource from './shader.frag?raw';
  import { AudioController } from '$lib/audio';

  import GlslCanvas from 'glslCanvas';

  console.log('hello world');

  let canvasEl: any;
  let sandbox: any;

  let audioController: AudioController;
  let audioData: any;

  // Animation loop, for canceling when we don't need anymore
  let renderLoopId: number | null = null;

  // Render uniforms
  let zoom = 1;
  let color = [1, 1, 1];
  let arg = 0;

  onMount(() => {
    if (!canvasEl) return;

    const handleResize = () => {
      const dpr = window.devicePixelRatio || 1;
      const width = window.innerWidth * dpr;
      const height = window.innerHeight * dpr;
      canvasEl.width = width;
      canvasEl.height = height;
    };
    window.onresize = handleResize;
    handleResize();

    sandbox = new GlslCanvas(canvasEl);
    sandbox.load(fragShaderSource);
    sandbox.setUniform('zoom', 4.0);

    let mouseX = 0;
    let mouseY = 0;
    window.onmousemove = (e: MouseEvent) => {
      mouseX = e.clientX;
      mouseY = e.clientY;
    };

    // Audio setup
    audioController = new AudioController();

    // Visual render loop
    const render = () => {
      // Update audio
      audioData = audioController.update();
      if (audioData) {
        color = audioData.color;
      }

      // const a = performance.now() * 0.001 + Math.PI * 0.75;
      // const a = (mouseX / window.innerWidth) * Math.PI * 2;

      // const a = Math.PI * 1.0 + Math.sin(performance.now() * 0.0005) * 1.0;
      // const a = Math.PI * 1.5;
      if (audioData) arg += audioData?.volume;
      const a = Math.PI * 1.0 + Math.sin(arg * 0.1) * 1.0;
      const c = [0.7885 * Math.cos(a), 0.7885 * Math.sin(a)];
      // const color = [0.1, 0.5, 0.4];

      // let c = [-0.835, -0.2321];
      // c[0] += Math.cos(a) * 0.1;
      // c[1] += Math.sin(a) * 0.1;

      sandbox.setUniform('c', c[0], c[1]);
      sandbox.setUniform('color', color[0], color[1], color[2]);
      renderLoopId = requestAnimationFrame(render);
    };
    renderLoopId = requestAnimationFrame(render);
  });

  onDestroy(() => {
    if (renderLoopId) cancelAnimationFrame(renderLoopId);
    audioController?.destroy();
  });
</script>

<main class="relative flex h-full w-full bg-black">
  <div class="absolute top-4 left-4 rounded-md text-white tabular-nums">
    <p>bass: {audioData?.color[0].toFixed(3)}</p>
    <p>mid: {audioData?.color[1].toFixed(3)}</p>
    <p>treble: {audioData?.color[2].toFixed(3)}</p>
    <p>energy: {audioData?.volume.toFixed(3)}</p>
  </div>
  <canvas class="glslCanvas h-full w-full" bind:this={canvasEl}></canvas>
</main>
