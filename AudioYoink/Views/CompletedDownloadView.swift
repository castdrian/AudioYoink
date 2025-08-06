import SwiftUI
import Kingfisher

struct CompletedDownloadView: View {
    let download: DownloadItem
    
    var body: some View {
        Button(action: openDocuments) {
            HStack(spacing: 16) {
                // Enhanced cover image
                Group {
                    if let coverUrl = download.coverUrl {
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
                    Text(download.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Label("\(download.totalChapters) chapters • \(formatDuration(download.duration))", 
                          systemImage: "waveform")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: download.id)
                    
                    Text("Tap to Open")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
