import SwiftUI

struct DownloadManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var downloadManager: DownloadManager
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Download Status", selection: $selectedTab) {
                    Text("Active").tag(0)
                    Text("Completed").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                TabView(selection: $selectedTab) {
                    ActiveDownloadsView(downloads: downloadManager.activeDownloads)
                        .tag(0)

                    CompletedDownloadsView(
                        downloads: downloadManager.completedDownloads,
                        onDelete: { download in
                            downloadManager.removeCompletedDownload(download)
                        }
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DummyDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var downloadManager: DownloadManager
    @State private var title = ""
    @State private var author = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Book Title", text: $title)
                
                Button("Start Download") {
                    downloadManager.startDummyDownload(title: title)
                    dismiss()
                }
                .disabled(title.isEmpty || author.isEmpty)
            }
            .navigationTitle("New Download")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ActiveDownloadsView: View {
    let downloads: [DownloadManager.DownloadItem]

    var body: some View {
        List {
            ForEach(downloads) { download in
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
            }
        }
        .listStyle(.plain)
    }
}

struct CompletedDownloadsView: View {
    let downloads: [DownloadManager.DownloadItem]
    let onDelete: (DownloadManager.DownloadItem) -> Void

    var body: some View {
        List {
            ForEach(downloads) { download in
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
                .buttonStyle(LongPressButtonStyle(onLongPress: {
                    onDelete(download)
                }))
                .swipeActions {
                    Button(role: .destructive) {
                        onDelete(download)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
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
                        Text("Chapter \(currentChapter + 1) of \(totalChapters)")
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
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Overall Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))% • \(downloadSpeed)")
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

enum DownloadStatus {
    case downloading
    case completed
}

#Preview {
    DownloadManagerView(downloadManager: DownloadManager())
}
