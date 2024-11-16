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
                TextField("Author", text: $author)
                
                Button("Start Download") {
                    downloadManager.startDummyDownload(title: title, author: author)
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
                    author: download.author,
                    progress: download.progress,
                    status: download.status
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
                    author: download.author,
                    progress: download.progress,
                    status: download.status
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
    let author: String
    let progress: Double
    let status: DownloadStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                    Text(author)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                statusIcon
            }

            if status == .downloading {
                ProgressView(value: progress)
                    .tint(.accentColor)
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
