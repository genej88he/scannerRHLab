//
//  DatasetReader.swift
//  StrayScanner
//
//  Shared, correct primitives for reading a recorded dataset directory:
//  odometry.csv, depth/*.png (16-bit mm), confidence/*.png and rgb.mp4.
//

import Foundation
import AVFoundation
import CoreGraphics
import simd

struct DatasetOdometryFrame {
    let timestamp: Double
    let frame: Int
    let position: SIMD3<Float>
    let rotation: simd_quatf
    // Intrinsics are in video-resolution pixels; scale before applying to depth maps.
    let fx: Float
    let fy: Float
    let cx: Float
    let cy: Float
}

struct DatasetDepthFrame {
    let width: Int
    let height: Int
    let depthMeters: [Float]
}

enum DatasetReader {

    static func parseOdometry(url: URL) -> [DatasetOdometryFrame]? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        var frames: [DatasetOdometryFrame] = []
        let lines = contents.components(separatedBy: "\n").dropFirst() // skip header
        for line in lines {
            let cols = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count >= 13,
                  let timestamp = Double(cols[0]),
                  let frame = Int(cols[1]),
                  let x = Float(cols[2]), let y = Float(cols[3]), let z = Float(cols[4]),
                  let qx = Float(cols[5]), let qy = Float(cols[6]),
                  let qz = Float(cols[7]), let qw = Float(cols[8]),
                  let fx = Float(cols[9]), let fy = Float(cols[10]),
                  let cx = Float(cols[11]), let cy = Float(cols[12])
            else { continue }
            frames.append(DatasetOdometryFrame(
                timestamp: timestamp,
                frame: frame,
                position: SIMD3<Float>(x, y, z),
                rotation: simd_quatf(ix: qx, iy: qy, iz: qz, r: qw),
                fx: fx, fy: fy, cx: cx, cy: cy))
        }
        return frames.isEmpty ? nil : frames
    }

    static func loadDepthPNG(url: URL) -> DatasetDepthFrame? {
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgImage = CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ),
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow

        var depthMeters = [Float](repeating: 0, count: width * height)
        // 16-bit grayscale PNG decodes big-endian, value is millimeters.
        for v in 0..<height {
            let row = v * bytesPerRow
            for u in 0..<width {
                let high = UInt16(bytes[row + 2 * u])
                let low = UInt16(bytes[row + 2 * u + 1])
                depthMeters[v * width + u] = Float((high << 8) | low) / 1000.0
            }
        }
        return DatasetDepthFrame(width: width, height: height, depthMeters: depthMeters)
    }

    static func loadConfidencePNG(url: URL) -> [UInt8]? {
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgImage = CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ),
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow

        var values = [UInt8](repeating: 0, count: width * height)
        for v in 0..<height {
            let row = v * bytesPerRow
            for u in 0..<width {
                values[v * width + u] = bytes[row + u]
            }
        }
        return values
    }
}

/// Sequential decoder over rgb.mp4. Outputs BGRA pixel buffers with their
/// presentation timestamps so frames can be matched to odometry rows.
final class RGBVideoReader {
    let width: Int
    let height: Int
    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput

    init?(url: URL) {
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first,
              let reader = try? AVAssetReader(asset: asset) else { return nil }
        let size = track.naturalSize
        self.width = Int(size.width)
        self.height = Int(size.height)
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }
        self.reader = reader
        self.output = output
    }

    func nextFrame() -> (buffer: CVPixelBuffer, pts: CMTime)? {
        guard let sample = output.copyNextSampleBuffer(),
              let buffer = CMSampleBufferGetImageBuffer(sample) else { return nil }
        let pts = CMSampleBufferGetPresentationTimeStamp(sample)
        return (buffer, pts)
    }
}
