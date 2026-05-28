//
//  Untitled.swift
//  StrayScanner
//
//  Created by Marianny De Leon on 5/14/26.
//  Copyright © 2026 Stray Robots. All rights reserved.
//

//
//  WoundMeasurementViewController.swift
//  StrayScanner
//
//
//import UIKit
//
//class WoundMeasurementViewController: UIViewController {
//    
//    private let datasetDirectory: URL
//    
//    init(datasetDirectory: URL) {
//        self.datasetDirectory = datasetDirectory
//        super.init(nibName: nil, bundle: nil)
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = UIColor(named: "BackgroundColor")
//        loadDataset()
//    }
//    
//    private func loadDataset() {
//        let depthDirectory = datasetDirectory.appendingPathComponent("depth")
//        let odometryPath = datasetDirectory.appendingPathComponent("odometry.csv")
//        print("Dataset directory: \(datasetDirectory)")
//        print("Depth directory: \(depthDirectory)")
//        print("Odometry path: \(odometryPath)")
//    }
//}

import UIKit
import simd
import CoreData


class WoundMeasurementViewController: UIViewController {
    
    private let datasetDirectory: URL
    private var recording: Recording
    
    
    // UI Elements
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let measurementsView = UIView()
    private let lengthLabel = UILabel()
    private let widthLabel = UILabel()
    private let depthLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    
    init(datasetDirectory: URL, recordingEntry: Recording) {
        self.datasetDirectory = datasetDirectory
        self.recording = recordingEntry
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .black
        setupUI()
        processDataset()
    }
    
    private func setupUI() {
        // Title
        titleLabel.text = "Wound Measurements"
        titleLabel.textColor = UIColor.label
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Status
        statusLabel.text = "Processing scan..."
        statusLabel.textColor = UIColor.secondaryLabel
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Measurements container
        measurementsView.backgroundColor = .clear
        measurementsView.translatesAutoresizingMaskIntoConstraints = false
        measurementsView.isHidden = true
        view.addSubview(measurementsView)
        
        // Measurement labels
        for label in [lengthLabel, widthLabel, depthLabel] {
            label.textColor = UIColor.label
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)
            label.textAlignment = .right
            label.translatesAutoresizingMaskIntoConstraints = false
            measurementsView.addSubview(label)
        }
        
        // Add dividers
        let divider1 = makeDivider()
        let divider2 = makeDivider()
        measurementsView.addSubview(divider1)
        measurementsView.addSubview(divider2)
        
        // Length row label
        let lengthTitle = makeRowLabel("Length")
        let widthTitle = makeRowLabel("Width")
        let depthTitle = makeRowLabel("Depth")
        measurementsView.addSubview(lengthTitle)
        measurementsView.addSubview(widthTitle)
        measurementsView.addSubview(depthTitle)
        
        // Close button
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(UIColor.systemBlue, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        closeButton.backgroundColor = .clear
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            measurementsView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 32),
            measurementsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            measurementsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            measurementsView.heightAnchor.constraint(equalToConstant: 180),
            
            lengthTitle.topAnchor.constraint(equalTo: measurementsView.topAnchor, constant: 12),
            lengthTitle.leadingAnchor.constraint(equalTo: measurementsView.leadingAnchor),
            lengthLabel.centerYAnchor.constraint(equalTo: lengthTitle.centerYAnchor),
            lengthLabel.trailingAnchor.constraint(equalTo: measurementsView.trailingAnchor),
            
            divider1.topAnchor.constraint(equalTo: lengthTitle.bottomAnchor, constant: 12),
            divider1.leadingAnchor.constraint(equalTo: measurementsView.leadingAnchor),
            divider1.trailingAnchor.constraint(equalTo: measurementsView.trailingAnchor),
            divider1.heightAnchor.constraint(equalToConstant: 0.5),
            
            widthTitle.topAnchor.constraint(equalTo: divider1.bottomAnchor, constant: 12),
            widthTitle.leadingAnchor.constraint(equalTo: measurementsView.leadingAnchor),
            widthLabel.centerYAnchor.constraint(equalTo: widthTitle.centerYAnchor),
            widthLabel.trailingAnchor.constraint(equalTo: measurementsView.trailingAnchor),
            
            divider2.topAnchor.constraint(equalTo: widthTitle.bottomAnchor, constant: 12),
            divider2.leadingAnchor.constraint(equalTo: measurementsView.leadingAnchor),
            divider2.trailingAnchor.constraint(equalTo: measurementsView.trailingAnchor),
            divider2.heightAnchor.constraint(equalToConstant: 0.5),
            
            depthTitle.topAnchor.constraint(equalTo: divider2.bottomAnchor, constant: 12),
            depthTitle.leadingAnchor.constraint(equalTo: measurementsView.leadingAnchor),
            depthLabel.centerYAnchor.constraint(equalTo: depthTitle.centerYAnchor),
            depthLabel.trailingAnchor.constraint(equalTo: measurementsView.trailingAnchor),
            
            closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 200),
            closeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func makeRowLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = UIColor.secondaryLabel
        label.font = UIFont.systemFont(ofSize: 17)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func processDataset() {
        let depthDir = datasetDirectory.appendingPathComponent("depth")
        let odometryFile = datasetDirectory.appendingPathComponent("odometry.csv")
        
        // Check files exist
        guard FileManager.default.fileExists(atPath: depthDir.path),
              FileManager.default.fileExists(atPath: odometryFile.path) else {
            statusLabel.text = "Could not find dataset files.\nPath: \(datasetDirectory.lastPathComponent)"
            return
        }
        
        // Count depth frames
        let frames = (try? FileManager.default.contentsOfDirectory(atPath: depthDir.path))?.count ?? 0
        statusLabel.text = "Found \(frames) depth frames.\nProcessing point cloud..."
        
        // Process on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.buildPointCloudAndMeasure(depthDir: depthDir, odometryFile: odometryFile)
            DispatchQueue.main.async {
                self.showResults(result)
            }
        }
    }
    
    private struct MeasurementResult {
        let length: Float
        let width: Float
        let depth: Float
        let frameCount: Int
    }
    
    private func buildPointCloudAndMeasure(depthDir: URL, odometryFile: URL) -> MeasurementResult {
        // Step 1: Parse odometry.csv
        guard let odometryFrames = parseOdometry(url: odometryFile) else {
            print("Failed to parse odometry")
            return MeasurementResult(length: 0, width: 0, depth: 0, frameCount: 0)
        }
        
        var allPoints: [SIMD3<Float>] = []
        
        // Step 2: Process each frame
        for odometry in odometryFrames {
            let frameStr = String(format: "%06d", odometry.frame)
            let depthPath = depthDir.appendingPathComponent("\(frameStr).png")
            let confidencePath = depthDir
                .deletingLastPathComponent()
                .appendingPathComponent("confidence/\(frameStr).png")
            
            // Step 3: Load depth and confidence maps
            guard let depthMap = load16BitPNG(url: depthPath) else { continue }
            let confidenceMap = loadConfidencePNG(url: confidencePath)
            
            // Step 4: Unproject pixels to 3D and transform to world space
            let points = unprojectFrame(
                depthMap: depthMap,
                confidenceMap: confidenceMap,
                odometry: odometry
            )
            allPoints.append(contentsOf: points)
        }
        
        guard !allPoints.isEmpty else {
            print("No points generated")
            return MeasurementResult(length: 0, width: 0, depth: 0, frameCount: 0)
        }
        
        // Step 5: Segment wound vs healthy tissue using depth threshold
        let measurements = measureWound(points: allPoints)
        return MeasurementResult(
            length: measurements.length,
            width: measurements.width,
            depth: measurements.depth,
            frameCount: odometryFrames.count
        )
    }
    
    // MARK: - Odometry Parsing
    
    private struct OdometryFrame {
        let frame: Int
        let position: SIMD3<Float>
        let rotation: simd_quatf
        let fx: Float
        let fy: Float
        let cx: Float
        let cy: Float
    }
    
    private func parseOdometry(url: URL) -> [OdometryFrame]? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        var frames: [OdometryFrame] = []
        let lines = contents.components(separatedBy: "\n").dropFirst() // skip header
        
        for line in lines {
            let cols = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count >= 13,
                  let frame = Int(cols[1]),
                  let x = Float(cols[2]), let y = Float(cols[3]), let z = Float(cols[4]),
                  let qx = Float(cols[5]), let qy = Float(cols[6]),
                  let qz = Float(cols[7]), let qw = Float(cols[8]),
                  let fx = Float(cols[9]), let fy = Float(cols[10]),
                  let cx = Float(cols[11]), let cy = Float(cols[12])
            else { continue }
            
            let position = SIMD3<Float>(x, y, z)
            let rotation = simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
            frames.append(OdometryFrame(frame: frame, position: position,
                                        rotation: rotation, fx: fx, fy: fy, cx: cx, cy: cy))
        }
        return frames.isEmpty ? nil : frames
    }
    
    // MARK: - Depth Map Loading
    
    private struct DepthMap {
        let width: Int
        let height: Int
        let data: [Float] // depth in meters
    }
    
    private func load16BitPNG(url: URL) -> DepthMap? {
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgImage = CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        
        var depthValues: [Float] = []
        depthValues.reserveCapacity(width * height)
        
        // 16-bit PNG: 2 bytes per pixel, big-endian
        for i in 0..<(width * height) {
            let high = UInt16(bytes[i * 2])
            let low = UInt16(bytes[i * 2 + 1])
            let rawValue = (high << 8) | low
            // Convert mm to meters
            depthValues.append(Float(rawValue) / 1000.0)
        }
        
        return DepthMap(width: width, height: height, data: depthValues)
    }
    
    private func loadConfidencePNG(url: URL) -> [UInt8]? {
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgImage = CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ),
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        
        let count = cgImage.width * cgImage.height
        return Array(UnsafeBufferPointer(start: bytes, count: count))
    }
    
    // MARK: - Unprojection
    
    private func unprojectFrame(depthMap: DepthMap,
                                confidenceMap: [UInt8]?,
                                odometry: OdometryFrame) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        let width = depthMap.width
        let height = depthMap.height
        
        // Sample every 2nd pixel for performance
        let step = 2
        
        for v in stride(from: 0, to: height, by: step) {
            for u in stride(from: 0, to: width, by: step) {
                let idx = v * width + u
                
                // Skip low confidence pixels
                if let conf = confidenceMap, conf[idx] == 0 { continue }
                
                let depth = depthMap.data[idx]
                // Skip invalid depth
                guard depth > 0.05 && depth < 1.5 else { continue }
                
                // Unproject to camera space
                let xCam = (Float(u) - odometry.cx) * depth / odometry.fx
                let yCam = (Float(v) - odometry.cy) * depth / odometry.fy
                let zCam = depth
                let pointCam = SIMD3<Float>(xCam, yCam, zCam)
                
                // Transform to world space using pose
                let pointWorld = odometry.rotation.act(pointCam) + odometry.position
                points.append(pointWorld)
            }
        }
        return points
    }
    
    // MARK: - Measurement
    
    private struct WoundMeasurements {
        let length: Float // mm
        let width: Float  // mm
        let depth: Float  // mm
    }
    
    private func measureWound(points: [SIMD3<Float>]) -> WoundMeasurements {
        // Step 1: Find ground plane using median Z of all points
        let zValues = points.map { $0.z }.sorted()
        let groundZ = zValues[zValues.count / 2]
        
        // Step 2: Separate wound points (deeper than ground by threshold)
        // Wound points are further from camera (larger Z in camera space)
        let threshold: Float = 0.003 // 3mm below ground plane
        let woundPoints = points.filter { $0.z > groundZ + threshold }
        let healthyPoints = points.filter { $0.z <= groundZ + threshold }
        
        guard !woundPoints.isEmpty else {
            print("No wound points found")
            return WoundMeasurements(length: 0, width: 0, depth: 0)
        }
        
        // Step 3: Fit plane to healthy tissue using mean
        let healthyZ = healthyPoints.isEmpty ? groundZ :
        healthyPoints.map { $0.z }.reduce(0, +) / Float(healthyPoints.count)
        
        // Step 4: Get wound extents in X and Y
        let woundX = woundPoints.map { $0.x }
        let woundY = woundPoints.map { $0.y }
        let woundZ = woundPoints.map { $0.z }
        
        let lengthM = (woundX.max() ?? 0) - (woundX.min() ?? 0)
        let widthM = (woundY.max() ?? 0) - (woundY.min() ?? 0)
        let depthM = (woundZ.max() ?? 0) - healthyZ
        
        return WoundMeasurements(
            length: lengthM * 1000,
            width: widthM * 1000,
            depth: depthM * 1000
        )
        
        
    }
    private func showResults(_ result: MeasurementResult) {
        statusLabel.text = "Scan processed successfully."
        lengthLabel.text = String(format: "%.1f mm", result.length)
        widthLabel.text = String(format: "%.1f mm", result.width)
        depthLabel.text = String(format: "%.1f mm", result.depth)
        measurementsView.isHidden = false
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let viewContext = appDelegate.persistentContainer.viewContext
        viewContext.perform {
            let request = NSFetchRequest<Recording>(entityName: "Recording")
            request.predicate = NSPredicate(format: "id == %@", self.recording.id! as CVarArg)
            if let rec = try? viewContext.fetch(request).first {
                rec.woundDiameter = Double(result.length)
                rec.woundMaxDiameter = Double(result.width)
                rec.woundDepth = Double(result.depth)
                try? viewContext.save()
            }
        }
    }
    
    @objc private func closeTapped() {
        let alert = UIAlertController(title: "Name this recording", message: "Give this recording a name so you can identify it later.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "e.g. Patient A - left leg"
            textField.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let name = alert.textFields?.first?.text, !name.isEmpty {
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                let viewContext = appDelegate.persistentContainer.viewContext
                viewContext.perform {
                    let request = NSFetchRequest<Recording>(entityName: "Recording")
                    request.predicate = NSPredicate(format: "id == %@", self.recording.id! as CVarArg)
                    if let rec = try? viewContext.fetch(request).first {
                        rec.name = name
                        try? viewContext.save()
                    }
                }
            }
            self.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Skip", style: .cancel) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}
