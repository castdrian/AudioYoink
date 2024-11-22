import SwiftUI

struct DownloadManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var downloadManager: DownloadManager
    
    var body: some View {
        NavigationView {
            List {
                if !downloadManager.activeDownloads.isEmpty {
                    Section("Active Downloads") {
                        ForEach(downloadManager.activeDownloads) { download in
                            DownloadItemRow(
                                title: download.title,
                                progress: download.progress,
                                chapterProgress: download.chapterProgress,
                                currentChapter: download.currentChapter,
                                totalChapters: download.totalChapters,
                                status: download.status,
                                downloadSpeed: download.downloadSpeed,
                                chapterDownloadSpeed: download.chapterDownloadSpeed
                            )
                            .swipeActions {
                                Button(role: .destructive) {
                                    downloadManager.cancelDownload(download)
                                } label: {
                                    Label("Cancel", systemImage: "xmark")
                                }
                            }
                        }
                    }
                }
                
                if !downloadManager.completedDownloads.isEmpty {
                    Section("Completed Downloads") {
                        ForEach(downloadManager.completedDownloads) { download in
                            DownloadItemRow(
                                title: download.title,
                                progress: download.progress,
                                chapterProgress: download.chapterProgress,
                                currentChapter: download.currentChapter,
                                totalChapters: download.totalChapters,
                                status: download.status,
                                downloadSpeed: download.downloadSpeed,
                                chapterDownloadSpeed: download.chapterDownloadSpeed
                            )
                            .swipeActions {
                                Button(role: .destructive) {
                                    downloadManager.removeCompletedDownload(download)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct DownloadItemRow: View {
    let title: String
    let progress: Double
    let chapterProgress: Double
    let currentChapter: Int
    let totalChapters: Int
    let status: DownloadStatus
    let downloadSpeed: String
    let chapterDownloadSpeed: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                    if status == .downloading {
                        Text("Chapter \(currentChapter) of \(totalChapters)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                statusIcon
            }
            
            if status == .downloading {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Current Chapter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(chapterProgress * 100))% • \(chapterDownloadSpeed)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: chapterProgress)
                        .tint(.blue)
                    
                    HStack {
                        Text("Overall Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: progress)
                        .tint(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    var statusIcon: some View {
        switch status {
        case .downloading:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.tint)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}

#Preview {
    DownloadManagerView()
}
