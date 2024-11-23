import ActivityKit
import Foundation

@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()
    @Published var activityId: String?
    @Published var activityToken: String?
    private var lastUpdateTime: TimeInterval = 0
    
    func start(title: String, coverUrl: String?) {
        Task {
            await cancelAllRunningActivities()
            await startNewLiveActivity(title: title, coverUrl: coverUrl)
        }
    }
    
    func update(progress: Double, chapterProgress: Double, currentChapter: Int, totalChapters: Int, downloadSpeed: String, chapterDownloadSpeed: String) {
        guard let activityId = activityId else { return }
        
        let currentTime = Date().timeIntervalSince1970
        guard currentTime - lastUpdateTime >= 0.5 else { return }
        lastUpdateTime = currentTime
        
        Task {
            let contentState = AudioBookDownloadAttributes.ContentState(
                progress: progress,
                chapterProgress: chapterProgress,
                currentChapter: currentChapter,
                totalChapters: totalChapters,
                downloadSpeed: downloadSpeed,
                chapterDownloadSpeed: chapterDownloadSpeed
            )
            
            let content = ActivityContent(state: contentState, staleDate: nil)
            
            for activity in Activity<AudioBookDownloadAttributes>.activities {
                if activity.id == activityId {
                    await activity.update(content)
                    break
                }
            }
        }
    }
    
    func end() {
        Task {
            let finalState = AudioBookDownloadAttributes.ContentState(
                progress: 1.0,
                chapterProgress: 1.0,
                currentChapter: 0,
                totalChapters: 0,
                downloadSpeed: "Completed",
                chapterDownloadSpeed: "Completed"
            )
            
            let finalContent = ActivityContent(state: finalState, staleDate: nil)
            
            for activity in Activity<AudioBookDownloadAttributes>.activities {
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
            activityId = nil
            activityToken = nil
        }
    }
    
    private func startNewLiveActivity(title: String, coverUrl: String?) async {
        let attributes = AudioBookDownloadAttributes(
            bookTitle: title,
            coverUrl: coverUrl
        )
        
        let contentState = AudioBookDownloadAttributes.ContentState(
            progress: 0,
            chapterProgress: 0,
            currentChapter: 0,
            totalChapters: 10,
            downloadSpeed: "0 MB/s",
            chapterDownloadSpeed: "0 MB/s"
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            
            activityId = activity.id
            print("Live Activity started with ID: \(activity.id)")
        } catch {
            print("Error starting live activity: \(error.localizedDescription)")
        }
    }
    
    private func cancelAllRunningActivities() async {
        let finalState = AudioBookDownloadAttributes.ContentState(
            progress: 1.0,
            chapterProgress: 1.0,
            currentChapter: 0,
            totalChapters: 0,
            downloadSpeed: "Cancelled",
            chapterDownloadSpeed: "Cancelled"
        )
        
        let finalContent = ActivityContent(state: finalState, staleDate: nil)
        
        for activity in Activity<AudioBookDownloadAttributes>.activities {
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }
    }
} 
