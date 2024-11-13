import SwiftUI

struct SiteStatusView: View {
    let siteStatus: SiteStatus

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack {
                    Text("tokybook.com")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 4)
                    if siteStatus.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: siteStatus.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(siteStatus.isReachable ? .green : .red)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

                if !siteStatus.isChecking {
                    VStack(spacing: 4) {
                        ConnectionDetailRow(label: "Latency", value: String(format: "%.2fs", siteStatus.latency))
                        ConnectionDetailRow(label: "Speed", value: "\(siteStatus.speed) Mb/s")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text("freeaudiobooks.top")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 4)
                    if siteStatus.mirrorIsChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: siteStatus.mirrorIsReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(siteStatus.mirrorIsReachable ? .green : .red)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

                if !siteStatus.mirrorIsChecking {
                    VStack(spacing: 4) {
                        ConnectionDetailRow(label: "Latency", value: String(format: "%.2fs", siteStatus.mirrorLatency))
                        ConnectionDetailRow(label: "Speed", value: "\(siteStatus.mirrorSpeed) Mb/s")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
}
