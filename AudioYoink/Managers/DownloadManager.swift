import Foundation
import ActivityKit
import SwiftUI
import Kingfisher

@MainActor
class DownloadManager: ObservableObject {
    @Published var activeDownloads: [DownloadItem] = []
    @Published var completedDownloads: [DownloadItem] = []
    private var downloadTimers: [UUID: Timer] = [:]
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIScene.didEnterBackgroundNotification, object: nil)
    }
    
    @objc private func didEnterBackground() {
        Task {
            for download in activeDownloads {
                LiveActivityManager.shared.start(
                    title: download.title,
                    coverUrl: download.coverUrl
                )
            }
        }
    }
    
    struct DownloadItem: Identifiable {
        let id = UUID()
        let title: String
        let coverUrl: String?
        var progress: Double
        var chapterProgress: Double
        var status: DownloadStatus
        var currentChapter: Int
        let totalChapters: Int
        let chapterSizes: [Double]
        var downloadSpeed: String
        var chapterDownloadSpeed: String
        var totalSize: Double {
            chapterSizes.reduce(0, +)
        }
        var downloadedSize: Double {
            var size = chapterSizes[..<(currentChapter - 1)].reduce(0, +)
            size += chapterSizes[currentChapter - 1] * chapterProgress
            return size
        }
    }
    
    func startDummyDownload(title: String, coverUrl: String? = nil) {
        if let coverUrl = coverUrl, let url = URL(string: coverUrl) {
            KingfisherManager.shared.retrieveImage(with: url) { _ in }
        }
        
        print("Starting dummy download for: \(title)")
        let chapterSizes = (0..<10).map { _ in Double.random(in: 20...50) }
        let download = DownloadItem(
            title: title,
            coverUrl: coverUrl,
            progress: 0,
            chapterProgress: 0,
            status: .downloading,
            currentChapter: 1,
            totalChapters: 10,
            chapterSizes: chapterSizes,
            downloadSpeed: "0 MB/s",
            chapterDownloadSpeed: "0 MB/s"
        )
        
        activeDownloads.append(download)
        print("Starting Live Activity...")
        LiveActivityManager.shared.start(title: title, coverUrl: coverUrl)
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
                download.chapterProgress += 1.0 / 20
                
                download.progress = download.downloadedSize / download.totalSize
                
                if download.chapterProgress >= 1.0 {
                    download.chapterProgress = 0
                    download.currentChapter += 1
                    
                    if download.currentChapter > download.totalChapters {
                        download.progress = 1.0
                        download.chapterProgress = 1.0
                        timer.invalidate()
                        self.completeDownload(download)
                        return
                    }
                }
                
                withAnimation {
                    self.activeDownloads[index] = download
                }
                
                self.updateDownloadProgress(download)
            }
        }
        
        downloadTimers[initialDownload.id] = timer
    }
    
    private func updateDownloadProgress(_ download: DownloadItem) {
        let overallSpeed = String(format: "%.1f MB/s", Double.random(in: 1.5...3.5))
        let chapterSpeed = String(format: "%.1f MB/s", Double.random(in: 1.0...2.5))
        
        LiveActivityManager.shared.update(
            progress: download.progress,
            chapterProgress: download.chapterProgress,
            currentChapter: download.currentChapter,
            totalChapters: download.totalChapters,
            downloadSpeed: overallSpeed,
            chapterDownloadSpeed: chapterSpeed
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
