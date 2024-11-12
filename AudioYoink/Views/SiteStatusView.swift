import SwiftUI

struct SiteStatusView: View {
    let siteStatus: SiteStatus
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("tokybook.com")
                    .font(.system(.body, design: .monospaced))
                
                if siteStatus.isChecking {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: siteStatus.isReachable ? 
                        "checkmark.circle.fill" : "x.circle.fill")
                    .foregroundColor(siteStatus.isReachable ? 
                        .green : .red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
            
            if !siteStatus.isChecking {
                VStack(alignment: .leading, spacing: 8) {
                    ConnectionDetailRow(label: "Latency", 
                        value: "\(Int(siteStatus.latency * 1000))ms")
                    ConnectionDetailRow(label: "Speed", 
                        value: "\(String(format: "%.1f", siteStatus.speed)) Mbps")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
} 
