//
//  AudioBookDownloadLiveActivity.swift
//  AudioBookDownloadLiveActivity
//
//  Created by Adrian Castro on 16/11/24.
//

import SwiftUI
import WidgetKit
import ActivityKit

struct AudioBookDownloadLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AudioBookDownloadAttributes.self) { context in
            LiveActivityView(
                title: context.attributes.bookTitle,
                author: context.attributes.author,
                progress: context.state.progress,
                currentChapter: context.state.currentChapter,
                totalChapters: context.state.totalChapters,
                downloadSpeed: context.state.downloadSpeed
            )
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(.blue)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.attributes.bookTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.attributes.author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ProgressView(value: context.state.progress)
                            .tint(.blue)
                        HStack {
                            Text("Chapter \(context.state.currentChapter)/\(context.state.totalChapters)")
                            Spacer()
                            Text(context.state.downloadSpeed)
                        }
                        .font(.caption2)
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
            } minimal: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

struct LiveActivityView: View {
    let title: String
    let author: String
    let progress: Double
    let currentChapter: Int
    let totalChapters: Int
    let downloadSpeed: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            ProgressView(value: progress)
                .tint(.blue)
            
            HStack {
                Text("Chapter \(currentChapter) of \(totalChapters)")
                Spacer()
                Text(downloadSpeed)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    LiveActivityView(
        title: "Sample Book",
        author: "Sample Author",
        progress: 0.45,
        currentChapter: 5,
        totalChapters: 10,
        downloadSpeed: "2.1 MB/s"
    )
}
