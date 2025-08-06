import SwiftUI
import Kingfisher

struct DownloadManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var downloadManager: DownloadManager
    @Namespace private var glassNamespace
    
    var body: some View {
        NavigationView {
            GlassEffectContainer(spacing: 20) {
                List {
                    if !downloadManager.activeDownloads.isEmpty {
                        Section {
                            ForEach(Array(downloadManager.activeDownloads.enumerated()), id: \.element.id) { index, download in
                                DownloadItemRow(
                                    title: download.title,
                                    coverUrl: download.coverUrl,
                                    progress: download.progress,
                                    chapterProgress: download.chapterProgress,
                                    currentChapter: download.currentChapter,
                                    totalChapters: download.totalChapters,
                                    status: download.status,
                                    downloadSpeed: download.downloadSpeed,
                                    chapterDownloadSpeed: download.chapterDownloadSpeed
                                )
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                                .glassEffectID("active_\(index)", in: glassNamespace)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            downloadManager.cancelDownload(download)
                                        }
                                    } label: {
                                        Label("Cancel", systemImage: "xmark")
                                    }
                                    .tint(.red)
                                }
                            }
                        } header: {
                            Text("Active Downloads")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(.bottom, 8)
                        }
                        .listSectionSeparator(.hidden)
                    }
                    
                    if !downloadManager.completedDownloads.isEmpty {
                        Section {
                            ForEach(Array(downloadManager.completedDownloads.enumerated()), id: \.element.id) { index, download in
                                CompletedDownloadView(download: download)
                                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                                    .glassEffectID("completed_\(index)", in: glassNamespace)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                downloadManager.removeCompletedDownload(download)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                            }
                        } header: {
                            Text("Completed")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(.bottom, 8)
                        }
                        .listSectionSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background {
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemBackground).opacity(0.95),
                            Color(.systemGray6).opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
                .navigationTitle("Downloads")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.regularMaterial)
                        )
                        .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.regularMaterial)
    }
}

struct DownloadItemRow: View {
    let title: String
    let coverUrl: String?
    let progress: Double
    let chapterProgress: Double
    let currentChapter: Int
    let totalChapters: Int
    let status: DownloadStatus
    let downloadSpeed: String
    let chapterDownloadSpeed: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Enhanced cover image
                Group {
                    if let coverUrl = coverUrl {
                        KFImage(URL(string: coverUrl))
                            .placeholder {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.tertiary)
                                    .overlay {
                                        Image(systemName: "book.closed")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.secondary)
                                    }
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .primary.opacity(0.1), radius: 6, y: 3)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.tertiary)
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.secondary)
                            }
                            .shadow(color: .primary.opacity(0.1), radius: 6, y: 3)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    
                    if case .failed(let message) = status {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red)
                    } else if status == .downloading {
                        Text("Chapter \(currentChapter) of \(totalChapters)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                statusIcon
            }
            
            if status == .downloading {
                VStack(alignment: .leading, spacing: 12) {
                    // Chapter progress
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Current Chapter")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(chapterProgress * 100))%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        
                        ProgressView(value: chapterProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(y: 1.5)
                    }
                    
                    // Overall progress
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Overall Progress")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .scaleEffect(y: 1.5)
                    }
                    
                    // Download speeds
                    if !downloadSpeed.isEmpty || !chapterDownloadSpeed.isEmpty {
                        HStack {
                            if !chapterDownloadSpeed.isEmpty {
                                Label(chapterDownloadSpeed, systemImage: "speedometer")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if !downloadSpeed.isEmpty {
                                Label(downloadSpeed, systemImage: "arrow.down.circle")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    var statusIcon: some View {
        switch status {
        case .downloading:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, options: .repeating)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: status)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.red)
                .symbolEffect(.bounce, value: status)
        }
    }
}

#Preview {
    DownloadManagerView()
}
