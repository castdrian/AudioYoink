import SwiftUI
import Kingfisher

struct CompletedDownloadView: View {
    let download: DownloadItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let coverUrl = download.coverUrl {
                    KFImage(URL(string: coverUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.title)
                        .font(.system(size: 16, weight: .medium))
                    Text("\(download.totalChapters) chapters • \(formatDuration(download.duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
        .onTapGesture {
            openDocuments()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    private func openDocuments() {
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let sharedUrl = URL(string: "shareddocuments://\(documentsUrl.path)") {
            if UIApplication.shared.canOpenURL(sharedUrl) {
                UIApplication.shared.open(sharedUrl, options: [:], completionHandler: nil)
            }
        }
    }
} 
