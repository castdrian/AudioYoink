import SwiftUI
import Kingfisher

struct CompletedDownloadView: View {
    let download: DownloadItem
    
    var body: some View {
        Button {
            UIApplication.shared.open(download.directory)
        } label: {
            HStack(spacing: 12) {
                if let coverUrl = download.coverUrl {
                    KFImage(URL(string: coverUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("\(download.totalChapters) chapters • \(formatDuration(download.duration))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "folder")
                    .foregroundColor(.accentColor)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
} 