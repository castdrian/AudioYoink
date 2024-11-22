//
//  AudioBookDownloadLiveActivity.swift
//  AudioBookDownloadLiveActivity
//
//  Created by Adrian Castro on 16/11/24.
//

import SwiftUI
import WidgetKit
import ActivityKit
import Kingfisher

struct AudioBookDownloadLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AudioBookDownloadAttributes.self) { context in
            LiveActivityView(
                title: context.attributes.bookTitle,
                coverUrl: context.attributes.coverUrl,
                progress: context.state.progress,
                chapterProgress: context.state.chapterProgress,
                currentChapter: context.state.currentChapter,
                totalChapters: context.state.totalChapters,
                downloadSpeed: context.state.downloadSpeed,
                chapterDownloadSpeed: context.state.chapterDownloadSpeed
            )
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(.blue)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let coverUrl = context.attributes.coverUrl,
                       let url = URL(string: coverUrl) {
                        KFImage(url)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 75)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.attributes.bookTitle)
                            .font(.headline)
                            .lineLimit(1)

                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Chapter \(context.state.currentChapter) of \(context.state.totalChapters)")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(context.state.chapterProgress * 100))% • \(context.state.chapterDownloadSpeed)")
                                    .font(.caption)
                            }
                            ProgressView(value: context.state.chapterProgress)
                                .tint(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Overall Progress")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(context.state.progress * 100))%")
                                    .font(.caption)
                            }
                            ProgressView(value: context.state.progress)
                                .tint(.green)
                        }
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .trim(from: 0, to: context.state.chapterProgress)
                        .stroke(.blue, lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .stroke(.blue.opacity(0.2), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    Text("\(Int(context.state.chapterProgress * 100))%")
                        .font(.system(size: 8, weight: .medium))
                }
                .frame(width: 32, height: 32)
            } compactTrailing: {
                ZStack {
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(.green, lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .stroke(.green.opacity(0.2), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 8, weight: .medium))
                }
                .frame(width: 32, height: 32)
            } minimal: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

struct LiveActivityView: View {
    let title: String
    let coverUrl: String?
    let progress: Double
    let chapterProgress: Double
    let currentChapter: Int
    let totalChapters: Int
    let downloadSpeed: String
    let chapterDownloadSpeed: String
    
    var body: some View {
        HStack(spacing: 12) {
            if let coverUrl = coverUrl,
               let url = URL(string: coverUrl) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Chapter \(currentChapter) of \(totalChapters)")
                            .font(.caption)
                        Spacer()
                        Text("\(Int(chapterProgress * 100))% • \(chapterDownloadSpeed)")
                            .font(.caption)
                    }
                    ProgressView(value: chapterProgress)
                        .tint(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Overall Progress")
                            .font(.caption)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                    }
                    ProgressView(value: progress)
                        .tint(.green)
                }
            }
        }
        .padding()
    }
}
