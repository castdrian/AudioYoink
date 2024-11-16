import Foundation
import ActivityKit
import SwiftUI

@MainActor
class DownloadManager: ObservableObject {
    @Published var activeDownloads: [DownloadItem] = []
    @Published var completedDownloads: [DownloadItem] = []
    private var downloadTimers: [UUID: Timer] = [:]
    
    struct DownloadItem: Identifiable {
        let id = UUID()
        let title: String
        let author: String
        var progress: Double
        var status: DownloadStatus
        var currentChapter: Int
        let totalChapters: Int
    }
    
    func startDummyDownload(title: String, author: String) {
        let download = DownloadItem(
            title: title,
            author: author,
            progress: 0,
            status: .downloading,
            currentChapter: 0,
            totalChapters: 10
        )
        
        activeDownloads.append(download)
        LiveActivityManager.shared.start(title: title, author: author)
        simulateDownloadProgress(for: download)
    }
    
    private func simulateDownloadProgress(for initialDownload: DownloadItem) {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                guard let index = self.activeDownloads.firstIndex(where: { $0.id == initialDownload.id }) else {
                    timer.invalidate()
                    return
                }
                
                var download = self.activeDownloads[index]
                download.progress += Double.random(in: 0.02...0.08)
                
                if download.progress >= 1.0 {
                    download.progress = 1.0
                    timer.invalidate()
                    self.completeDownload(download)
                    return
                }
                
                download.currentChapter = Int(download.progress * 10)
                
                withAnimation {
                    self.activeDownloads[index] = download
                }
                
                self.updateDownloadProgress(download)
            }
        }
        
        downloadTimers[initialDownload.id] = timer
    }
    
    private func updateDownloadProgress(_ download: DownloadItem) {
        LiveActivityManager.shared.update(
            progress: download.progress,
            currentChapter: download.currentChapter,
            totalChapters: download.totalChapters,
            downloadSpeed: "\(Int(download.progress * 100))%"
        )
    }
    
    private func completeDownload(_ download: DownloadItem) {
        var completedDownload = download
        completedDownload.status = .completed
        completedDownload.progress = 1.0
        
        withAnimation {
            activeDownloads.removeAll { $0.id == download.id }
            completedDownloads.append(completedDownload)
        }
        
        downloadTimers[download.id]?.invalidate()
        downloadTimers[download.id] = nil
        
        LiveActivityManager.shared.end()
    }
    
    func removeCompletedDownload(_ download: DownloadItem) {
        withAnimation {
            completedDownloads.removeAll { $0.id == download.id }
        }
    }
}
