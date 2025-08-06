import SwiftUI

struct SiteStatusView: View {
    let siteStatus: SiteStatus
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            VStack(spacing: 20) {
                // Main site status
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text("tokybook.com")
                            .font(.system(.body, design: .monospaced, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if siteStatus.isChecking {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.primary)
                        } else {
                            Image(systemName: siteStatus.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(siteStatus.isReachable ? .green : .red)
                                .font(.system(size: 20, weight: .medium))
                                .symbolEffect(.bounce, value: siteStatus.isReachable)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                    .glassEffectID("mainSite", in: glassNamespace)

                    if !siteStatus.isChecking {
                        VStack(spacing: 8) {
                            ConnectionDetailRow(
                                label: "Latency", 
                                value: String(format: "%.2fs", siteStatus.latency)
                            )
                            ConnectionDetailRow(
                                label: "Speed", 
                                value: "\(siteStatus.speed) Mb/s"
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        .glassEffectID("mainSiteDetails", in: glassNamespace)
                    }
                }

                // Mirror site status
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text("freeaudiobooks.top")
                            .font(.system(.body, design: .monospaced, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if siteStatus.mirrorIsChecking {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.primary)
                        } else {
                            Image(systemName: siteStatus.mirrorIsReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(siteStatus.mirrorIsReachable ? .green : .red)
                                .font(.system(size: 20, weight: .medium))
                                .symbolEffect(.bounce, value: siteStatus.mirrorIsReachable)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                    .glassEffectID("mirrorSite", in: glassNamespace)

                    if !siteStatus.mirrorIsChecking {
                        VStack(spacing: 8) {
                            ConnectionDetailRow(
                                label: "Latency", 
                                value: String(format: "%.2fs", siteStatus.mirrorLatency)
                            )
                            ConnectionDetailRow(
                                label: "Speed", 
                                value: "\(siteStatus.mirrorSpeed) Mb/s"
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        .glassEffectID("mirrorSiteDetails", in: glassNamespace)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
