import SwiftUI

struct DownloadManagerView: View {
    @Environment(\.dismiss) private var dismiss
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
                    ActiveDownloadsView()
                        .tag(0)
                    
                    CompletedDownloadsView()
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

struct ActiveDownloadsView: View {
    var body: some View {
        List {
            ForEach(0..<3) { _ in
                DownloadItemRow(
                    title: "Sample Book Title",
                    author: "Author Name",
                    progress: Double.random(in: 0...1),
                    status: .downloading
                )
            }
        }
        .listStyle(.plain)
    }
}

struct CompletedDownloadsView: View {
    var body: some View {
        List {
            ForEach(0..<5) { _ in
                DownloadItemRow(
                    title: "Sample Book Title",
                    author: "Author Name",
                    progress: 1.0,
                    status: .completed
                )
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
    DownloadManagerView()
}
