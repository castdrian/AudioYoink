import Foundation
import ActivityKit
import SwiftUI
import Kingfisher

@MainActor
class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var activeDownloads: [DownloadItem] = []
    @Published var completedDownloads: [DownloadItem] = []
    private var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.audioyoink.download")
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    private var downloadInfo: [UUID: (chapters: [Chapter], directory: URL, source: BookSource)] = [:]
    
    func startDownload(title: String, coverUrl: String?, chapters: [Chapter], source: BookSource?) {
        print("Starting download for \(title) with \(chapters.count) chapters")
        guard let source = source else {
            print("No source provided for download")
            return
        }
        
        do {
            let bookDirectory = try FileManagerHelper.shared.createBookDirectory(title: title)
            let filteredChapters = chapters.filter { chapter in
                chapter.url != source.skipChapter
            }
            print("Filtered chapters count: \(filteredChapters.count)")
            
            let chapterSizes = filteredChapters.map { _ in Double.random(in: 20...50) }
            print("Created chapter sizes array")
            
            let download = DownloadItem(
                title: title,
                coverUrl: coverUrl,
                progress: 0,
                chapterProgress: 0,
                status: .downloading,
                currentChapter: 1,
                totalChapters: filteredChapters.count,
                chapterSizes: chapterSizes,
                downloadSpeed: "0 MB/s",
                chapterDownloadSpeed: "0 MB/s"
            )
            print("Created download item with ID: \(download.id)")
            
            activeDownloads.append(download)
            print("Active downloads count: \(activeDownloads.count)")
            // LiveActivityManager.shared.start(title: title, coverUrl: coverUrl)
            
            downloadInfo[download.id] = (chapters: filteredChapters, directory: bookDirectory, source: source)
            downloadChapter(for: download, chapters: filteredChapters, directory: bookDirectory, source: source)
        } catch {
            print("Failed to create directory: \(error)")
        }
    }
    
    private func downloadChapter(for download: DownloadItem, chapters: [Chapter], directory: URL, source: BookSource) {
        print("Downloading chapter \(download.currentChapter) of \(chapters.count)")
        guard download.currentChapter <= chapters.count else {
            print("All chapters completed, finishing download")
            completeDownload(download)
            return
        }
        
        let chapter = chapters[download.currentChapter - 1]
        print("Starting download for chapter: \(chapter.name)")
        downloadWithFallback(
            chapter: chapter,
            directory: directory,
            download: download,
            chapters: chapters,
            source: source,
            attemptedUrls: []
        )
    }
    
    private func downloadWithFallback(
        chapter: Chapter,
        directory: URL,
        download: DownloadItem,
        chapters: [Chapter],
        source: BookSource,
        attemptedUrls: [String]
    ) {
        let urls = [
            source.mediaURL + chapter.url,
            source.mediaFallbackURL + chapter.url
        ].map { url in
            url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        }
        
        print("Attempting URLs: \(urls)")
        let remainingUrls = urls.filter { !attemptedUrls.contains($0) }
        
        guard let nextUrl = remainingUrls.first,
              let url = URL(string: nextUrl) else {
            print("All URLs failed for chapter: \(chapter.name)")
            return
        }
        
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    print("Invalid response for URL: \(url)")
                    let newAttemptedUrls = attemptedUrls + [nextUrl]
                    downloadWithFallback(
                        chapter: chapter,
                        directory: directory,
                        download: download,
                        chapters: chapters,
                        source: source,
                        attemptedUrls: newAttemptedUrls
                    )
                    return
                }
                
                print("URL is valid, creating download task")
                let task = urlSession.downloadTask(with: url)
                downloadTasks[download.id] = task
                print("Starting download task")
                task.resume()
            } catch {
                print("Error validating URL: \(error)")
                let newAttemptedUrls = attemptedUrls + [nextUrl]
                downloadWithFallback(
                    chapter: chapter,
                    directory: directory,
                    download: download,
                    chapters: chapters,
                    source: source,
                    attemptedUrls: newAttemptedUrls
                )
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("Download finished for task: \(downloadTask)")
        
        Task { @MainActor in
            guard let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key else {
                print("Could not find download ID for task")
                return
            }
            
            do {
                let fileHandle = try FileHandle(forReadingFrom: location)
                let data = fileHandle.readDataToEndOfFile()
                fileHandle.closeFile()
                
                guard let downloadIndex = activeDownloads.firstIndex(where: { $0.id == downloadId }),
                      let info = downloadInfo[downloadId] else {
                    return
                }
                
                let download = activeDownloads[downloadIndex]
                let chapter = info.chapters[download.currentChapter - 1]
                let fileName = "\(download.currentChapter). \(chapter.name).mp3"
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                
                do {
                    let fileManager = FileManager.default
                    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let bookPath = documentsPath.appendingPathComponent(download.title)
                    
                    try fileManager.createDirectory(at: bookPath, withIntermediateDirectories: true, attributes: nil)
                    let destinationURL = bookPath.appendingPathComponent(fileName)
                    
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    
                    fileManager.createFile(atPath: destinationURL.path, contents: data, attributes: nil)
                    print("Successfully saved file to: \(destinationURL.path)")
                    
                    startNextChapter(for: download, at: downloadIndex)
                } catch {
                    print("Failed to save file: \(error)")
                    handleDownloadError(downloadId: downloadId, downloadTask: downloadTask, error: error)
                }
            } catch {
                print("Failed to read downloaded file: \(error)")
                handleDownloadError(downloadId: downloadId, downloadTask: downloadTask, error: error)
            }
        }
    }
    
    @MainActor
    private func handleDownloadError(downloadId: UUID, downloadTask: URLSessionDownloadTask, error: Error) {
        downloadTasks[downloadId] = nil
        
        guard let info = downloadInfo[downloadId],
              let index = activeDownloads.firstIndex(where: { $0.id == downloadId }) else {
            return
        }
        
        let download = activeDownloads[index]
        let chapter = info.chapters[download.currentChapter - 1]
        let attemptedUrl = downloadTask.originalRequest?.url?.absoluteString ?? ""
        
        if attemptedUrl.contains(info.source.mediaURL) {
            downloadWithFallback(
                chapter: chapter,
                directory: info.directory,
                download: download,
                chapters: info.chapters,
                source: info.source,
                attemptedUrls: [attemptedUrl]
            )
        } else {
            print("All URLs failed for chapter \(chapter.name), skipping to next chapter")
            startNextChapter(for: download, at: index)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            guard let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key else { return }
            
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            updateProgress(for: downloadId, chapterProgress: progress)
        }
    }
    
    private func startNextChapter(for download: DownloadItem, at index: Int) {
        var updatedDownload = download
        updatedDownload.currentChapter += 1
        updatedDownload.chapterProgress = 0
        activeDownloads[index] = updatedDownload
        
        if updatedDownload.currentChapter > updatedDownload.totalChapters {
            completeDownload(updatedDownload)
        } else {
            guard let info = downloadInfo[updatedDownload.id] else { return }
            downloadChapter(
                for: updatedDownload,
                chapters: info.chapters,
                directory: info.directory,
                source: info.source
            )
        }
    }
    
    func cancelDownload(_ download: DownloadItem) {
        if let task = downloadTasks[download.id] {
            task.cancel()
        }
        
        withAnimation {
            activeDownloads.removeAll { $0.id == download.id }
        }
        downloadTasks[download.id] = nil
        downloadInfo[download.id] = nil
        LiveActivityManager.shared.end()
        
        try? FileManagerHelper.shared.deleteBookDirectory(title: download.title)
    }
    
    func removeCompletedDownload(_ download: DownloadItem) {
        withAnimation {
            completedDownloads.removeAll { $0.id == download.id }
        }
        try? FileManagerHelper.shared.deleteBookDirectory(title: download.title)
    }
    
    private func updateProgress(for downloadId: UUID, chapterProgress: Double) {
        guard let index = activeDownloads.firstIndex(where: { $0.id == downloadId }) else { return }
        var download = activeDownloads[index]
        
        guard chapterProgress > download.chapterProgress else { return }
        
        download.chapterProgress = chapterProgress
        download.progress = download.downloadedSize / download.totalSize
        
        let overallSpeed = String(format: "%.1f MB/s", Double.random(in: 1.5...3.5))
        let chapterSpeed = String(format: "%.1f MB/s", Double.random(in: 1.0...2.5))
        
        download.downloadSpeed = overallSpeed
        download.chapterDownloadSpeed = chapterSpeed
        
        withAnimation(.linear(duration: 0.1)) {
            activeDownloads[index] = download
        }
        
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
        withAnimation {
            activeDownloads.removeAll { $0.id == download.id }
            var completedDownload = download
            completedDownload.status = .completed
            completedDownload.progress = 1.0
            completedDownload.chapterProgress = 1.0
            completedDownloads.append(completedDownload)
        }
        downloadTasks[download.id] = nil
        downloadInfo[download.id] = nil
        LiveActivityManager.shared.end()
    }
    
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let backgroundCompletionHandler = appDelegate.backgroundCompletionHandler else {
                return
            }
            backgroundCompletionHandler()
        }
    }
}
