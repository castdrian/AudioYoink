import SwiftUI

struct SiteStatusView: View {
    let siteStatus: SiteStatus
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 24) {
            VStack(spacing: 24) {
                // Header with better spacing
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source Status")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        Text("Audiobook sources connectivity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Overall health indicator with better design
                    let healthyCount = [siteStatus.isReachable, siteStatus.mirrorIsReachable, siteStatus.goldenIsReachable].filter { $0 }.count
                    let healthColor: Color = healthyCount == 3 ? .green : healthyCount >= 1 ? .orange : .red
                    
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(healthColor.opacity(0.2))
                                .frame(width: 24, height: 24)
                            Circle()
                                .fill(healthColor)
                                .frame(width: 8, height: 8)
                        }
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(healthyCount)/3")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Online")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .glassEffectID("statusHeader", in: glassNamespace)
                
                // Source cards with better layout
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    SourceStatusCard(
                        name: "TokyBook",
                        isChecking: siteStatus.isChecking,
                        isReachable: siteStatus.isReachable,
                        latency: siteStatus.latency,
                        speed: siteStatus.speed,
                        glassNamespace: glassNamespace,
                        id: "tokybook"
                    )
                    
                    SourceStatusCard(
                        name: "GoldenAudio",
                        isChecking: siteStatus.goldenIsChecking,
                        isReachable: siteStatus.goldenIsReachable,
                        latency: siteStatus.goldenLatency,
                        speed: siteStatus.goldenSpeed,
                        glassNamespace: glassNamespace,
                        id: "goldenaudiobook"
                    )
                    
                    SourceStatusCard(
                        name: "FreeAudio",
                        isChecking: siteStatus.mirrorIsChecking,
                        isReachable: siteStatus.mirrorIsReachable,
                        latency: siteStatus.mirrorLatency,
                        speed: siteStatus.mirrorSpeed,
                        glassNamespace: glassNamespace,
                        id: "freeaudiobooks"
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 20)
    }
}

struct SourceStatusCard: View {
    let name: String
    let isChecking: Bool
    let isReachable: Bool
    let latency: TimeInterval
    let speed: Double
    let glassNamespace: Namespace.ID
    let id: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Status indicator with better design
            ZStack {
                Circle()
                    .fill(.quaternary.opacity(0.3))
                    .frame(width: 44, height: 44)
                
                if isChecking {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(.primary)
                } else {
                    Image(systemName: isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isReachable ? .green : .red)
                        .font(.system(size: 24, weight: .semibold))
                        .symbolEffect(.bounce, value: isReachable)
                }
            }
            
            VStack(spacing: 8) {
                // Source name with better typography
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Stats with improved layout
                if !isChecking && isReachable {
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text("\(String(format: "%.0f", latency * 1000))ms")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text("\(Int(speed))Mb/s")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if !isChecking && !isReachable {
                    VStack(spacing: 4) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                        Text("Offline")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                    }
                } else if isChecking {
                    Text("Checking...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minHeight: 120)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .glassEffectID(id, in: glassNamespace)
    }
}
