import ActivityKit
import Foundation

@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()
    @Published var activityId: String?
    @Published var activityToken: String?
    
    func start(title: String, author: String) {
        Task {
            await cancelAllRunningActivities()
            await startNewLiveActivity(title: title, author: author)
        }
    }
    
    func update(progress: Double, currentChapter: Int, totalChapters: Int, downloadSpeed: String) {
        guard let activityId else { return }
        
        Task {
            let contentState = AudioBookDownloadAttributes.ContentState(
                progress: progress,
                currentChapter: currentChapter,
                totalChapters: totalChapters,
                downloadSpeed: downloadSpeed
            )
            
            for activity in Activity<AudioBookDownloadAttributes>.activities {
                if activity.id == activityId {
                    await activity.update(ActivityContent(state: contentState, staleDate: nil))
                }
            }
        }
    }
    
    func end() {
        Task {
            let finalState = AudioBookDownloadAttributes.ContentState(
                progress: 1.0,
                currentChapter: 0,
                totalChapters: 0,
                downloadSpeed: "Completed"
            )
            
            let finalContent = ActivityContent(state: finalState, staleDate: nil)
            
            for activity in Activity<AudioBookDownloadAttributes>.activities {
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
            activityId = nil
            activityToken = nil
        }
    }
    
    private func startNewLiveActivity(title: String, author: String) async {
        let attributes = AudioBookDownloadAttributes(
            bookTitle: title,
            author: author
        )
        
        let contentState = AudioBookDownloadAttributes.ContentState(
            progress: 0,
            currentChapter: 0,
            totalChapters: 10,
            downloadSpeed: "0 MB/s"
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
            currentChapter: 0,
            totalChapters: 0,
            downloadSpeed: "Cancelled"
        )
        
        let finalContent = ActivityContent(state: finalState, staleDate: nil)
        
        for activity in Activity<AudioBookDownloadAttributes>.activities {
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }
    }
} 