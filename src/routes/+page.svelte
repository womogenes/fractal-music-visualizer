<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import fragShaderSource from './shader.frag?raw';
  import { createAudioController } from '$lib/audio';

  import GlslCanvas from 'glslCanvas';

  let canvasEl: any;
  let sandbox: any;

  const audioController = createAudioController();

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

    const render = () => {
      // const a = performance.now() * 0.001 + Math.PI * 0.75;
      // const a = (mouseX / window.innerWidth) * Math.PI * 2;

      // const a = Math.PI * 1.0 + Math.sin(performance.now() * 0.0005) * 1.0;
      const a = Math.PI * 1.5;
      const c = [0.7885 * Math.cos(a), 0.7885 * Math.sin(a)];
      const color = [0.1, 0.5, 0.4];

      // let c = [-0.835, -0.2321];
      // c[0] += Math.cos(a) * 0.1;
      // c[1] += Math.sin(a) * 0.1;

      sandbox.setUniform('c', c[0], c[1]);
      sandbox.setUniform('color', color[0], color[1], color[2]);
      requestAnimationFrame(render);
    };
    requestAnimationFrame(render);
  });
</script>

<main class="flex h-full w-full">
  <canvas class="glslCanvas h-full w-full" bind:this={canvasEl}></canvas>
</main>
