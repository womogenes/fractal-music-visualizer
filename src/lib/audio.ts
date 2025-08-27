// Create audio and analyze

export class AudioController {
  FFT_SIZE = 1024;

  audioCtx: AudioContext | undefined;
  analyzer: AnalyserNode | undefined;
  source: MediaStreamAudioSourceNode | undefined;
  freqDataArray: Uint8Array = new Uint8Array();
  workletNode!: AudioWorkletNode;
  lastAudioData: { color: number[]; volume: number } | null = null;
  updateCallbacks: ((data: { color: number[]; volume: number }) => void)[] = [];

  renderData: { color: number[]; volume: number } = {
    color: [0, 0, 0],
    volume: 0,
  };

  isReady: boolean = false;

  bassFilter = new Uint8Array(this.FFT_SIZE);
  midFilter = new Uint8Array(this.FFT_SIZE);
  trebleFilter = new Uint8Array(this.FFT_SIZE);

  constructor() {
    console.log('Initialized AudioController');

    navigator.mediaDevices
      .getUserMedia({ audio: true })
      .then(async (stream) => {
        // Request low latency for the audio context
        this.audioCtx = new (window.AudioContext ||
          (window as any).webkitAudioContext)({
          latencyHint: 'interactive',
        });

        await this.audioCtx.audioWorklet.addModule('audio-processor.js');

        this.source = this.audioCtx.createMediaStreamSource(stream);

        this.analyzer = this.audioCtx.createAnalyser();
        this.analyzer.fftSize = this.FFT_SIZE;
        this.analyzer.smoothingTimeConstant = 0.8;

        this.workletNode = new AudioWorkletNode(
          this.audioCtx,
          'audio-analyzer-processor',
        );

        this.workletNode.port.onmessage = (event) => {
          if (!event.data) return;
          this.processData();
        };

        this.source.connect(this.analyzer);
        this.analyzer.connect(this.workletNode);
        // this.workletNode.connect(this.audioCtx.destination);

        const bufferLen = this.analyzer.frequencyBinCount;
        this.freqDataArray = new Uint8Array(bufferLen);

        // Make kernels
        for (let [filterArr, mean, std] of [
          [200, 300, this.bassFilter],
          [1000, 500, this.midFilter],
          [10000, 1000, this.trebleFilter],
        ]) {
          // @ts-ignore
          this.createGuassianKernel(filterArr, mean, std);
        }

        this.isReady = true;
        console.log('Audio setup complete');
      });
  }

  createGuassianKernel(mean: number, std: number, out: Uint8Array) {
    if (!this.audioCtx) throw Error('No audio context initialized');

    const sigma = std / mean;
    const mu = Math.log(mean);

    for (let i = 0; i < out.length; i++) {
      const x = ((i + 1) / out.length) * this.audioCtx.sampleRate;
      out[i] = Math.exp(-((Math.log(x) - mu) ** 2) / (2 * sigma ** 2)) * 256;
    }
  }

  processData() {
    if (!this.isReady) return;

    // this.analyzer?.getByteFrequencyData(this.dataArray);
    this.analyzer?.getByteFrequencyData(this.freqDataArray);

    // Optimized energy calculation using for loops instead of reduce
    let bassSum = 0,
      midSum = 0,
      trebleSum = 0;
    const length = this.freqDataArray.length;

    for (let i = 0; i < length; i++) {
      const value = this.freqDataArray[i];
      bassSum += value * this.bassFilter[i];
      midSum += value * this.midFilter[i];
      trebleSum += value * this.trebleFilter[i];
    }

    const bassEnergy = bassSum / length;
    const midEnergy = midSum / length;
    const trebleEnergy = trebleSum / length;

    const maxEnergy = (256 * this.freqDataArray.length) / 32;
    let volume = Math.max(bassEnergy, midEnergy, trebleEnergy) / maxEnergy;

    this.renderData = {
      color: [
        bassEnergy / maxEnergy,
        midEnergy / maxEnergy,
        trebleEnergy / maxEnergy,
      ],
      volume: volume,
    };
  }

  destroy() {
    console.log('Destroyed AudioController');
    this.audioCtx?.close();
  }
}
