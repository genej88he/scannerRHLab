//
//  PointCloudExporter.swift
//  StrayScanner
//
//  Builds a single fused, colored point cloud from a recorded dataset and
//  writes it as a binary little-endian PLY file.
//
//  Fusion: every depth frame is unprojected to world space using its odometry
//  pose, then accumulated into a voxel grid. Points falling in the same voxel
//  are averaged (weighted by LiDAR confidence), which removes the duplicate
//  surfaces produced by overlapping scans.
//

import Foundation
import AVFoundation
import simd

struct PLYExportOptions {
    var voxelSize: Float = 0.002      // 2 mm — wound-scale detail
    var minDepth: Float = 0.05
    var maxDepth: Float = 1.5
    var weightConf1: Float = 0.3      // confidence 2 → 1.0, confidence 0 → dropped
    var maxFusedFrames: Int = 300     // stride frames above this count
    var minObservations: UInt32 = 2   // per-voxel; relaxed to 1 for short recordings
}

final class PointCloudExporter {

    enum ExportError: LocalizedError {
        case missingOdometry
        case missingVideo
        case emptyCloud

        var errorDescription: String? {
            switch self {
            case .missingOdometry: return "Could not read odometry.csv for this recording."
            case .missingVideo: return "Could not open rgb.mp4 for this recording."
            case .emptyCloud: return "No valid points found in this recording."
            }
        }
    }

    private struct VoxelAccumulator {
        var posSum = SIMD3<Float>(repeating: 0)
        var colSum = SIMD3<Float>(repeating: 0)
        var weightSum: Float = 0
        var count: UInt32 = 0
    }

    private let datasetDirectory: URL
    private let options: PLYExportOptions

    init(datasetDirectory: URL, options: PLYExportOptions = PLYExportOptions()) {
        self.datasetDirectory = datasetDirectory
        self.options = options
    }

    /// Builds the fused cloud and returns the URL of the written PLY file in
    /// the temporary directory. Blocking — call off the main thread.
    func export(progress: @escaping (Double) -> Void) throws -> URL {
        let odometryURL = datasetDirectory.appendingPathComponent("odometry.csv")
        guard let odometry = DatasetReader.parseOdometry(url: odometryURL) else {
            throw ExportError.missingOdometry
        }
        guard let video = RGBVideoReader(url: datasetDirectory.appendingPathComponent("rgb.mp4")) else {
            throw ExportError.missingVideo
        }

        let depthDirectory = datasetDirectory.appendingPathComponent("depth")
        let confidenceDirectory = datasetDirectory.appendingPathComponent("confidence")
        let frameStride = max(1, odometry.count / options.maxFusedFrames)

        var voxels = [Int64: VoxelAccumulator]()
        voxels.reserveCapacity(1 << 18)

        // Video PTS for the k-th saved frame is (k * fpsDivider - 1) / 60
        // (DatasetEncoder's frame counter starts at -1). The divider is
        // inferred from the PTS delta between consecutive samples, which also
        // survives the first sample being dropped for its negative timestamp.
        var previousRawIndex: Int?
        var inferredDivider: Int?
        var fusedFrames = 0
        var processedRows = 0

        while true {
            var frame: (buffer: CVPixelBuffer, pts: CMTime)?
            autoreleasepool {
                frame = video.nextFrame()
                guard let (pixels, pts) = frame else { return }

                let rawIndex = Int((pts.seconds * 60).rounded())
                if inferredDivider == nil, let previous = previousRawIndex {
                    inferredDivider = max(1, rawIndex - previous)
                }
                previousRawIndex = rawIndex

                // Until the divider is known, only PTS -1/60 (always row 0) is
                // unambiguous. If the writer dropped that first sample, skip
                // this one rather than risk pairing it with the wrong pose.
                guard let divider = inferredDivider ?? (rawIndex == -1 ? 1 : nil) else {
                    return
                }

                guard (rawIndex + 1) % divider == 0 else { return }
                let row = (rawIndex + 1) / divider
                guard row >= 0, row < odometry.count else { return }
                processedRows = row + 1
                guard row % frameStride == 0 else { return }

                let odo = odometry[row]
                let depthURL = depthDirectory.appendingPathComponent(String(format: "%06d.png", odo.frame))
                guard let depth = DatasetReader.loadDepthPNG(url: depthURL) else { return }
                let confidenceURL = confidenceDirectory.appendingPathComponent(String(format: "%06d.png", odo.frame))
                let confidence = DatasetReader.loadConfidencePNG(url: confidenceURL)

                fuse(depth: depth, confidence: confidence, pixels: pixels,
                     odometry: odo, video: video, into: &voxels)
                fusedFrames += 1
                progress(min(0.9, Double(processedRows) / Double(odometry.count) * 0.9))
            }
            if frame == nil { break }
        }

        let minObservations = fusedFrames >= 20 ? options.minObservations : 1
        var points: [(SIMD3<Float>, SIMD3<UInt8>)] = []
        points.reserveCapacity(voxels.count)
        for accumulator in voxels.values where accumulator.count >= minObservations {
            let position = accumulator.posSum / accumulator.weightSum
            let color = accumulator.colSum / accumulator.weightSum
            points.append((position, SIMD3<UInt8>(
                UInt8(min(max(color.x, 0), 255)),
                UInt8(min(max(color.y, 0), 255)),
                UInt8(min(max(color.z, 0), 255)))))
        }
        guard !points.isEmpty else { throw ExportError.emptyCloud }

        progress(0.95)
        let name = datasetDirectory.lastPathComponent
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).ply")
        try writePLY(points: points, to: outputURL)
        progress(1.0)
        return outputURL
    }

    // MARK: - Fusion

    private func fuse(depth: DatasetDepthFrame,
                      confidence: [UInt8]?,
                      pixels: CVPixelBuffer,
                      odometry odo: DatasetOdometryFrame,
                      video: RGBVideoReader,
                      into voxels: inout [Int64: VoxelAccumulator]) {
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixels) else { return }
        let bgra = baseAddress.assumingMemoryBound(to: UInt8.self)
        let rgbBytesPerRow = CVPixelBufferGetBytesPerRow(pixels)

        let width = depth.width
        let height = depth.height
        // Odometry intrinsics are in video-resolution pixels; scale to depth resolution.
        let sx = Float(width) / Float(video.width)
        let sy = Float(height) / Float(video.height)
        let fx = odo.fx * sx
        let fy = odo.fy * sy
        let cx = odo.cx * sx
        let cy = odo.cy * sy

        let invVoxel = 1.0 / options.voxelSize

        for v in 0..<height {
            for u in 0..<width {
                let idx = v * width + u

                var weight: Float = 1.0
                if let conf = confidence {
                    switch conf[idx] {
                    case 0: continue
                    case 1: weight = options.weightConf1
                    default: weight = 1.0
                    }
                }

                let z = depth.depthMeters[idx]
                guard z > options.minDepth && z < options.maxDepth else { continue }

                let pointCam = SIMD3<Float>(
                    (Float(u) - cx) * z / fx,
                    (Float(v) - cy) * z / fy,
                    z)
                let pointWorld = odo.rotation.act(pointCam) + odo.position

                // Nearest-neighbor color sample in the full-resolution video frame.
                let ru = min(max(Int((Float(u) + 0.5) / sx), 0), video.width - 1)
                let rv = min(max(Int((Float(v) + 0.5) / sy), 0), video.height - 1)
                let pixel = rv * rgbBytesPerRow + ru * 4
                let color = SIMD3<Float>(
                    Float(bgra[pixel + 2]),  // R
                    Float(bgra[pixel + 1]),  // G
                    Float(bgra[pixel]))      // B

                let key = voxelKey(pointWorld * invVoxel)
                var accumulator = voxels[key] ?? VoxelAccumulator()
                accumulator.posSum += pointWorld * weight
                accumulator.colSum += color * weight
                accumulator.weightSum += weight
                accumulator.count += 1
                voxels[key] = accumulator
            }
        }
    }

    /// Packs quantized voxel coordinates into a single Int64 key (21 bits per
    /// axis, offset to keep them positive). Covers ±2 km at 2 mm voxels.
    private func voxelKey(_ scaled: SIMD3<Float>) -> Int64 {
        let offset: Int64 = 1 << 20
        let i = Int64(scaled.x.rounded(.down)) + offset
        let j = Int64(scaled.y.rounded(.down)) + offset
        let k = Int64(scaled.z.rounded(.down)) + offset
        return (i << 42) | (j << 21) | k
    }

    // MARK: - PLY writing

    private func writePLY(points: [(SIMD3<Float>, SIMD3<UInt8>)], to url: URL) throws {
        let header = """
        ply
        format binary_little_endian 1.0
        comment Created by Stray Scanner (fused voxel point cloud)
        element vertex \(points.count)
        property float x
        property float y
        property float z
        property uchar red
        property uchar green
        property uchar blue
        end_header

        """

        try? FileManager.default.removeItem(at: url)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        try handle.write(contentsOf: header.data(using: .ascii)!)

        var buffer = Data(capacity: 1 << 20)
        for (position, color) in points {
            withUnsafeBytes(of: position.x.bitPattern.littleEndian) { buffer.append(contentsOf: $0) }
            withUnsafeBytes(of: position.y.bitPattern.littleEndian) { buffer.append(contentsOf: $0) }
            withUnsafeBytes(of: position.z.bitPattern.littleEndian) { buffer.append(contentsOf: $0) }
            buffer.append(color.x)
            buffer.append(color.y)
            buffer.append(color.z)
            if buffer.count >= (1 << 20) - 16 {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }
    }
}
