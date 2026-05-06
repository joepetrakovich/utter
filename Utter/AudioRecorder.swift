//
//  AudioRecorder.swift
//  Utter
//
//  Created by Joe Petrakovich on 2026/04/27.
//

import AVFoundation

class AudioRecorder {
    private let engine = AVAudioEngine()
    private var accumulatedSamples = [Float]()
    private var format: AVAudioFormat?
    
    var isRunning: Bool { engine.isRunning }

    func start() {
        let inputNode = engine.inputNode
        let bus = 0
        format = inputNode.inputFormat(forBus: bus)
        accumulatedSamples.removeAll()
        
        inputNode.removeTap(onBus: bus)
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
            guard let self = self, let channelData = buffer.floatChannelData else { return }
            
            let frameCount = Int(buffer.frameLength)
            // Assuming mono for simplicity; for stereo, you'd handle both channels
            let channel0 = channelData[0]
            
            for i in 0..<frameCount {
                self.accumulatedSamples.append(channel0[i])
            }
        }
        
        do {
            print("starting engine")
            try engine.start()
        } catch {
            print(error) //TODO maybe best to throw
        }
    }
    
    func stopAndGetBuffer() -> AVAudioPCMBuffer? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        guard let format = self.format else { return nil }
        
        let frameCount = UInt32(accumulatedSamples.count)
        guard let finalBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        
        finalBuffer.frameLength = frameCount
        let channelData = finalBuffer.floatChannelData?[0]
        
        for i in 0..<Int(frameCount) {
            channelData?[i] = accumulatedSamples[i]
        }
        
        return finalBuffer
    }
}
