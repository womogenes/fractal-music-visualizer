// Create audio and analyze

export class AudioController {
  FFT_SIZE = 1024;

  audioCtx: AudioContext | undefined;
  analyzer: AnalyserNode | undefined;
  source: MediaStreamAudioSourceNode | undefined;
  dataArray: Uint8Array = new Uint8Array();

  isReady: boolean = false;

  bassFilter = new Uint8Array(this.FFT_SIZE);
  midFilter = new Uint8Array(this.FFT_SIZE);
  trebleFilter = new Uint8Array(this.FFT_SIZE);

  constructor() {
    console.log('Initialized AudioController');

    navigator.mediaDevices.getUserMedia({ audio: true }).then((stream) => {
      this.audioCtx = new window.AudioContext();
      this.source = this.audioCtx.createMediaStreamSource(stream);

      this.analyzer = this.audioCtx.createAnalyser();
      this.analyzer.fftSize = this.FFT_SIZE;

      this.source.connect(this.analyzer);

      const bufferLen = this.analyzer.frequencyBinCount;
      this.dataArray = new Uint8Array(bufferLen);

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

  update() {
    if (!this.isReady) return;

    this.analyzer?.getByteFrequencyData(this.dataArray);

    // console.log(this.dataArray.slice(0, 10));
    // console.log(this.bassFilter.slice(0, 10));
    // console.log(this.bassFilter);

    const bassEnergy =
      this.dataArray.reduce((l, r, i) => l + r * this.bassFilter[i], 0) /
      this.dataArray.length;
    const midEnergy =
      this.dataArray.reduce((l, r, i) => l + r * this.midFilter[i], 0) /
      this.dataArray.length;
    const trebleEnergy =
      this.dataArray.reduce((l, r, i) => l + r * this.trebleFilter[i], 0) /
      this.dataArray.length;

    const maxEnergy = (256 * this.dataArray.length) / 32;
    let volume = Math.max(bassEnergy, midEnergy, trebleEnergy) / maxEnergy;

    return {
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
