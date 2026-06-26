//
//  SessionDetailView.swift
//  RHLab
//
//  Created by Gene Jiang on 5/30/2026.
//  Copyright © 2026 RHLab. All rights reserved.
//

import SwiftUI
import AVKit
import CoreData

class SessionDetailViewModel: ObservableObject {
    private var dataContext: NSManagedObjectContext?

    init() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        self.dataContext = appDelegate?.persistentContainer.viewContext
    }
    
    func title(recording: Recording) -> String {
        if let name = recording.name, !name.isEmpty, !name.hasPrefix("Recording ") {
            return name
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        if let created = recording.createdAt {
            return dateFormatter.string(from: created)
        }
        return "Recording"
    }
    
    func date(recording: Recording) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        if let created = recording.createdAt {
            return dateFormatter.string(from: created)
        }
        return ""
    }

    func delete(recording: Recording) {
        recording.deleteFiles()
        self.dataContext?.delete(recording)
        do {
            try self.dataContext?.save()
        } catch let error as NSError {
            print("Could not save recording. \(error), \(error.userInfo)")
        }
    }
}

struct SessionDetailView: View {
    @ObservedObject var viewModel = SessionDetailViewModel()
    var recording: Recording
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @State private var showingShareSheet = false
    @State private var tempPackageURL: URL?
    @State private var isCreatingPackage = false
    @State private var player: AVPlayer?
    @State private var shareError: String?
    @State private var editingField: String? = nil
    @State private var editValue: String = ""

    let defaultUrl = URL(fileURLWithPath: "")

    var body: some View {
        let width = UIScreen.main.bounds.size.width
        let height = width * 0.75
        ScrollView {
            VStack(spacing: 0) {
                VideoPlayer(player: player ?? AVPlayer(url: defaultUrl))
                    .frame(width: width, height: height)
                    .onAppear {
                        if player == nil {
                            player = AVPlayer(url: recording.absoluteRgbPath() ?? defaultUrl)
                        }
                    }

                if let photoURL = recording.absolutePhoto2DPath(),
                   let uiImage = UIImage(contentsOfFile: photoURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width)
                        .padding(.top, 8)
                }

                HStack(spacing: 20) {
                    Button(action: shareItem) {
                        HStack {
                            if isCreatingPackage {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text(isCreatingPackage ? "Preparing..." : "Share")
                                .fixedSize()
                        }
                        .foregroundColor(isCreatingPackage ? .gray : .blue)
                        .frame(minWidth: 100)
                    }
                    .disabled(isCreatingPackage)

                    Button(action: deleteItem) {
                        Text("Delete").foregroundColor(Color("DangerColor"))
                    }
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Wound Measurements")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 16)

                    EditableWoundRow(label: "Diameter", value: recording.woundDiameter > 0 ? String(format: "%.1f", recording.woundDiameter) : "--", unit: "mm") {
                        editingField = "Diameter"
                        editValue = recording.woundDiameter > 0 ? String(format: "%.1f", recording.woundDiameter) : ""
                    }
                    Divider()
                    EditableWoundRow(label: "Depth", value: recording.woundDepth > 0 ? String(format: "%.1f", recording.woundDepth) : "--", unit: "mm") {
                        editingField = "Depth"
                        editValue = recording.woundDepth > 0 ? String(format: "%.1f", recording.woundDepth) : ""
                    }
                    Divider()
                    EditableWoundRow(label: "Max Diameter", value: recording.woundMaxDiameter > 0 ? String(format: "%.1f", recording.woundMaxDiameter) : "--", unit: "mm") {
                        editingField = "Max Diameter"
                        editValue = recording.woundMaxDiameter > 0 ? String(format: "%.1f", recording.woundMaxDiameter) : ""
                    }
                    Divider()
                    EditableWoundRow(label: "Surface Area", value: recording.woundSurfaceArea > 0 ? String(format: "%.1f", recording.woundSurfaceArea) : "--", unit: "mm\u{00B2}") {
                        editingField = "Surface Area"
                        editValue = recording.woundSurfaceArea > 0 ? String(format: "%.1f", recording.woundSurfaceArea) : ""
                    }
                    Divider()
                    EditableWoundRow(label: "Perimeter", value: recording.woundPerimeter > 0 ? String(format: "%.1f", recording.woundPerimeter) : "--", unit: "mm") {
                        editingField = "Perimeter"
                        editValue = recording.woundPerimeter > 0 ? String(format: "%.1f", recording.woundPerimeter) : ""
                    }
                }
                .padding(20)
                .padding(.top, 8)
                .alert("Edit \(editingField ?? "")", isPresented: Binding(
                    get: { editingField != nil },
                    set: { if !$0 { editingField = nil } }
                )) {
                    TextField("Enter value", text: $editValue)
                        .keyboardType(.decimalPad)
                    Button("Save") {
                        saveEditedValue()
                    }
                    Button("Cancel", role: .cancel) {
                        editingField = nil
                    }
                } message: {
                    Text("Enter the corrected measurement in mm")
                }
            }
        }
        .background(Color("BackgroundColor").ignoresSafeArea())
        .navigationBarTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(viewModel.title(recording: recording))
                        .font(.headline)
                    Text(viewModel.date(recording: recording))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let packageURL = tempPackageURL {
                ShareSheet(activityItems: [packageURL]) { activityType, completed, returnedItems, activityError in
                    DispatchQueue.main.async {
                        try? FileManager.default.removeItem(at: packageURL)
                        tempPackageURL = nil
                        showingShareSheet = false
                    }
                }
            }
        }
        .alert("Export Failed", isPresented: Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )) {
            Button("OK", role: .cancel) { shareError = nil }
        } message: {
            Text(shareError ?? "")
        }
    }

    func deleteItem() {
        viewModel.delete(recording: recording)
        self.presentationMode.wrappedValue.dismiss()
    }

    func saveEditedValue() {
        guard let field = editingField, let value = Double(editValue) else {
            editingField = nil
            return
        }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let viewContext = appDelegate.persistentContainer.viewContext
        viewContext.perform {
            let request = NSFetchRequest<Recording>(entityName: "Recording")
            request.predicate = NSPredicate(format: "id == %@", self.recording.id! as CVarArg)
            if let rec = try? viewContext.fetch(request).first {
                switch field {
                case "Diameter":     rec.woundDiameter = value
                case "Depth":        rec.woundDepth = value
                case "Max Diameter": rec.woundMaxDiameter = value
                case "Surface Area": rec.woundSurfaceArea = value
                case "Perimeter":    rec.woundPerimeter = value
                default: break
                }
                try? viewContext.save()
            }
        }
        editingField = nil
    }

    func shareItem() {
        isCreatingPackage = true
        Task {
            do {
                let packageURL = try await ShareUtility.createShareableArchive(for: recording)
                await MainActor.run {
                    tempPackageURL = packageURL
                    isCreatingPackage = false
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isCreatingPackage = false
                    shareError = error.localizedDescription
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let completionWithItemsHandler: UIActivityViewController.CompletionWithItemsHandler?

    init(activityItems: [Any], completionHandler: UIActivityViewController.CompletionWithItemsHandler? = nil) {
        self.activityItems = activityItems
        self.completionWithItemsHandler = completionHandler
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.completionWithItemsHandler = completionWithItemsHandler
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {}
}

struct EditableWoundRow: View {
    let label: String
    let value: String
    let unit: String
    let onTap: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(value) \(unit)")
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.medium)
            Image(systemName: "pencil")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct SessionDetailView_Previews: PreviewProvider {
    static var recording: Recording = { () -> Recording in
        let rec = Recording()
        rec.id = UUID()
        rec.name = "Placeholder name"
        rec.createdAt = Date()
        rec.duration = 30.0
        return rec
    }()

    static var previews: some View {
        SessionDetailView(recording: recording)
    }
}
