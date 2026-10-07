import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @State private var viewModel: BackupViewModel
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isConfirming = false

    init(viewModel: BackupViewModel) { self.viewModel = viewModel }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.xl) {
                Text("Keep a copy of your collection, progress and review dates. Choose where to save the file using Files.")
                    .foregroundStyle(Forest.inkMuted)
                Button("Export backup") {
                    Task {
                        await viewModel.send(.export)
                        isExporting = viewModel.state.exportData != nil
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Choose backup to restore") { isImporting = true }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                if viewModel.state.isBusy {
                    ProgressView("Preparing your backup")
                }
                if let error = viewModel.state.errorMessage {
                    StateMessage(title: "Backup couldn't be completed", message: error)
                    if let recovery = viewModel.state.recoveryURL {
                        ShareLink("Share recovery backup", item: recovery)
                            .frame(minHeight: 44)
                    }
                }
                if let backup = viewModel.state.preview {
                    VStack(alignment: .leading, spacing: Forest.Space.m) {
                        Text("Backup from \(backup.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.headline)
                        Text("\(backup.words.count) \(backup.words.count == 1 ? "word" : "words") · \(backup.kanjis.count) kanji")
                        Text("Restoring replaces your current collection, progress and review dates. A recovery backup of your current collection will be kept on this iPhone.")
                            .foregroundStyle(Forest.inkMuted)
                        Button("Replace current collection", role: .destructive) { isConfirming = true }
                            .buttonStyle(.bordered)
                            .tint(Forest.danger)
                            .frame(minHeight: 44)
                        Button("Cancel restore") { Task { await viewModel.send(.cancelPreview) } }
                            .frame(minHeight: 44)
                    }
                    .padding(Forest.Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
                }
                Text("Backups are files you manage. This app has no account or automatic sync.")
                    .font(.footnote)
                    .foregroundStyle(Forest.inkMuted)
            }
            .padding(Forest.Space.l)
            .foregroundStyle(Forest.ink)
            .disabled(viewModel.state.isBusy)
        }
        .background(Forest.canvas)
        .navigationTitle("Backup and restore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .fileExporter(isPresented: $isExporting, document: viewModel.state.exportData.map(BackupDocument.init(data:)), contentType: .json, defaultFilename: filename) { result in
            Task { await viewModel.send(.exportFinished(result)) }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            Task { await viewModel.send(.importFile(result)) }
        }
        .confirmationDialog("Replace current collection?", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Replace current collection", role: .destructive) { Task { await viewModel.send(.confirmRestore) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The selected backup will replace your current words, kanji, progress and review dates. A recovery backup will be saved first.")
        }
    }

    private var filename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "kotoba-backup-\(formatter.string(from: Date())).json"
    }
}
