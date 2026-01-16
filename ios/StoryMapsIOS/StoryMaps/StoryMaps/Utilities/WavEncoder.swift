/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct WavEncoder {
    /// Convert PCM audio data (base64 encoded) to WAV format
    static func pcmToWav(base64PCM: String, sampleRate: Int = 24000) -> Data? {
        guard let pcmData = Data(base64Encoded: base64PCM) else {
            return nil
        }
        
        return pcmToWav(pcmData: pcmData, sampleRate: sampleRate)
    }
    
    /// Convert raw PCM data to WAV format
    static func pcmToWav(pcmData: Data, sampleRate: Int = 24000) -> Data {
        let numChannels: UInt16 = 1 // Mono
        let bitsPerSample: UInt16 = 16 // 16-bit PCM
        let byteRate = UInt32(sampleRate * Int(numChannels) * Int(bitsPerSample) / 8)
        let blockAlign = UInt16(numChannels * bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        let chunkSize = 36 + dataSize
        
        var wavData = Data()
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt subchunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // Subchunk1Size
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // AudioFormat (PCM)
        wavData.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        
        // data subchunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        wavData.append(pcmData)
        
        return wavData
    }
}
