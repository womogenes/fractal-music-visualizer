// src/lib/audio-processor.js
class AudioAnalyzerProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.prevTime = 0;
  }
  
  static get parameterDescriptors() {
    return [];
  }

  process(inputs, outputs, parameters) {
    // This method is called whenever there's new audio data
    // We'll just pass the raw audio data to the main thread
    const input = inputs[0];
    this.prevTime = currentTime;
    this.port.postMessage({data: null});
    return true; // Keep the processor alive
  }
}

registerProcessor('audio-analyzer-processor', AudioAnalyzerProcessor);
