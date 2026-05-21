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

class WoundMeasurementViewController: UIViewController {
    
    private let datasetDirectory: URL
    
    // UI Elements
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let measurementsView = UIView()
    private let lengthLabel = UILabel()
    private let widthLabel = UILabel()
    private let depthLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    
    init(datasetDirectory: URL) {
        self.datasetDirectory = datasetDirectory
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
        titleLabel.text = "Wound Measurement"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Status
        statusLabel.text = "Processing scan..."
        statusLabel.textColor = .lightGray
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Measurements container
        measurementsView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        measurementsView.layer.cornerRadius = 12
        measurementsView.translatesAutoresizingMaskIntoConstraints = false
        measurementsView.isHidden = true
        view.addSubview(measurementsView)
        
        // Measurement labels
        for label in [lengthLabel, widthLabel, depthLabel] {
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 18)
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            measurementsView.addSubview(label)
        }
        
        // Close button
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.systemPink
        closeButton.layer.cornerRadius = 12
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            measurementsView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 32),
            measurementsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            measurementsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            measurementsView.heightAnchor.constraint(equalToConstant: 160),
            
            lengthLabel.topAnchor.constraint(equalTo: measurementsView.topAnchor, constant: 20),
            lengthLabel.centerXAnchor.constraint(equalTo: measurementsView.centerXAnchor),
            
            widthLabel.topAnchor.constraint(equalTo: lengthLabel.bottomAnchor, constant: 16),
            widthLabel.centerXAnchor.constraint(equalTo: measurementsView.centerXAnchor),
            
            depthLabel.topAnchor.constraint(equalTo: widthLabel.bottomAnchor, constant: 16),
            depthLabel.centerXAnchor.constraint(equalTo: measurementsView.centerXAnchor),
            
            closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 200),
            closeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
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
        // Placeholder — real implementation will unproject depth frames
        // and compute wound measurements
        return MeasurementResult(length: 0, width: 0, depth: 0, frameCount: 0)
    }
    
    private func showResults(_ result: MeasurementResult) {
        statusLabel.text = "Scan processed successfully."
        lengthLabel.text = String(format: "Length: %.1f mm", result.length)
        widthLabel.text = String(format: "Width:  %.1f mm", result.width)
        depthLabel.text = String(format: "Depth:  %.1f mm", result.depth)
        measurementsView.isHidden = false
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
