//
//  Recording+CoreDataClass.swift
//  RHLab
//
//  Created by Gene Jiang on 5/30/2026.
//  Copyright © 2026 RHLab. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Recording)
public class Recording: NSManagedObject {

    func deleteFiles() {
        deleteFile(directoryPath())
    }

    private func deleteFile(_ path: URL?) {
        if let filePath = path {
            if FileManager.default.fileExists(atPath: filePath.path) {
                do {
                    try FileManager.default.removeItem(atPath: filePath.path)
                    print("Deleted file \(filePath.absoluteString)")
                } catch let error as NSError {
                    print("Could not delete file \(filePath.absoluteString). \(error), \(error.userInfo)")
                }
            }
        }
    }
    
    func absolutePhoto2DPath() -> URL? {
        if let path = self.photo2DPath {
            return URL(fileURLWithPath: path, relativeTo: pathsRelativeTo())
        }
        return nil
    }
}
