import Foundation
import ActivityKit
import SwiftUI
import Kingfisher
import Defaults

extension Defaults.Keys {
    static let completedDownloads = Key<[DownloadItem]>("completedDownloads", default: [])
}

@MainActor
class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var activeDownloads: [DownloadItem] = []
    @Published var completedDownloads: [DownloadItem] = Defaults[.completedDownloads] {
        didSet {
            Defaults[.completedDownloads] = completedDownloads
        }
    }
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
            
            let totalDuration = filteredChapters.reduce(0) { total, chapter in 
                let components = chapter.duration.split(separator: ":")
                if components.count == 3 {
                    let hours = Int(components[0]) ?? 0
                    let minutes = Int(components[1]) ?? 0
                    let seconds = Int(components[2]) ?? 0
                    return total + (hours * 3600 + minutes * 60 + seconds)
                } else if components.count == 2 {
                    let minutes = Int(components[0]) ?? 0
                    let seconds = Int(components[1]) ?? 0
                    return total + (minutes * 60 + seconds)
                }
                return total
            }
            
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
                chapterDownloadSpeed: "0 MB/s",
                directory: bookDirectory,
                duration: TimeInterval(totalDuration),
                completedDate: nil
            )
            print("Created download item with ID: \(download.id)")
            
            activeDownloads.append(download)
            print("Active downloads count: \(activeDownloads.count)")
            LiveActivityManager.shared.start(title: title, coverUrl: coverUrl)
            
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
        // Handle both absolute and relative URLs
        let urls: [String]
        if chapter.url.hasPrefix("http") {
            // Chapter URL is already absolute, use as-is
            urls = [chapter.url]
            print("Using absolute URL for \(chapter.name): \(chapter.url)")
        } else {
            // Chapter URL is relative, construct full URLs with base and fallback
            urls = [
                source.mediaURL + chapter.url,
                source.mediaFallbackURL + chapter.url
            ]
            print("Constructed URLs for \(chapter.name): \(urls)")
        }
        
        // Only encode URLs if they are relative (constructed by us)
        // Absolute URLs from Golden Audiobook are already properly encoded
        let encodedUrls: [String]
        if chapter.url.hasPrefix("http") {
            // Don't re-encode absolute URLs
            encodedUrls = urls
            print("Using URLs without re-encoding: \(encodedUrls)")
        } else {
            // Encode relative URLs
            encodedUrls = urls.map { url in
                url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
            }
            print("Encoded relative URLs: \(encodedUrls)")
        }
        
        let remainingUrls = encodedUrls.filter { !attemptedUrls.contains($0) }
        print("Remaining URLs to try: \(remainingUrls)")
        
        guard let nextUrl = remainingUrls.first,
              let url = URL(string: nextUrl) else {
            print("All URLs failed for chapter: \(chapter.name)")
            return
        }
        
        print("Starting download task for URL: \(url)")
        let task = urlSession.downloadTask(with: url)
        downloadTasks[download.id] = task
        task.resume()
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("Download finished for task: \(downloadTask)")
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: location)
            let fileData = fileHandle.readDataToEndOfFile()
            fileHandle.closeFile()
            
            // Check if the downloaded file is too small (likely an error response)
            let fileSize = fileData.count
            print("Downloaded file size: \(fileSize) bytes")
            
            if fileSize < 1000 { // Less than 1KB suggests an error response
                print("File too small (\(fileSize) bytes), likely an error response")
                
                // Try to parse as text to see what the error is
                if let errorText = String(data: fileData, encoding: .utf8) {
                    print("Error response content: \(errorText)")
                }
                
                Task { @MainActor in
                    guard let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key else { return }
                    handleDownloadError(downloadId: downloadId, downloadTask: downloadTask, error: NSError(domain: "AudioYoink", code: -1, userInfo: [NSLocalizedDescriptionKey: "File too small (\(fileSize) bytes)"]))
                }
                return
            }
            
            Task { @MainActor in
                guard let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
                      let downloadIndex = activeDownloads.firstIndex(where: { $0.id == downloadId }),
                      let info = downloadInfo[downloadId] else {
                    print("Could not find download info")
                    return
                }
                
                let download = activeDownloads[downloadIndex]
                let chapter = info.chapters[download.currentChapter - 1]
                let fileName = "\(download.currentChapter). \(chapter.name).mp3"
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let bookPath = documentsPath.appendingPathComponent(download.title)
                let destinationURL = bookPath.appendingPathComponent(fileName)
                
                startNextChapter(for: download, at: downloadIndex)
                
                Task.detached {
                    do {
                        let fileManager = FileManager.default
                        try fileManager.createDirectory(at: bookPath, withIntermediateDirectories: true, attributes: nil)
                        
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.removeItem(at: destinationURL)
                        }
                        
                        fileManager.createFile(atPath: destinationURL.path, contents: fileData, attributes: nil)
                        print("Successfully saved file to: \(destinationURL.path)")
                    } catch {
                        print("Failed to save file: \(error)")
                        Task { @MainActor in
                            self.handleFailedSave(downloadId: downloadId, downloadIndex: downloadIndex, download: download, chapter: chapter)
                        }
                    }
                }
            }
        } catch {
            print("Failed to read temporary file: \(error)")
        }
    }
    
    @MainActor
    private func handleFailedSave(downloadId: UUID, downloadIndex: Int, download: DownloadItem, chapter: Chapter) {
        print("Failed to save file")
        var failedDownload = download
        failedDownload.status = .failed("Failed to save chapter \(chapter.name)")
        activeDownloads[downloadIndex] = failedDownload
        downloadTasks[downloadId] = nil
        downloadInfo[downloadId] = nil
        LiveActivityManager.shared.end()
    }
    
    @MainActor
    private func handleDownloadError(downloadId: UUID, downloadTask: URLSessionDownloadTask, error: Error) {
        print("Download error: \(error)")
        downloadTasks[downloadId] = nil
        
        guard let info = downloadInfo[downloadId],
              let index = activeDownloads.firstIndex(where: { $0.id == downloadId }) else {
            print("Could not find download info for failed download")
            return
        }
        
        var download = activeDownloads[index]
        let chapter = info.chapters[download.currentChapter - 1]
        let attemptedUrl = downloadTask.originalRequest?.url?.absoluteString ?? ""
        print("Failed URL: \(attemptedUrl)")
        
        // For relative URLs, try fallback if we haven't tried it yet
        // For absolute URLs, there's no fallback, so fail immediately
        let shouldRetry = !chapter.url.hasPrefix("http") && !attemptedUrl.contains(info.source.mediaFallbackURL)
        
        if shouldRetry {
            print("Attempting fallback URL for chapter: \(chapter.name)")
            downloadWithFallback(
                chapter: chapter,
                directory: info.directory,
                download: download,
                chapters: info.chapters,
                source: info.source,
                attemptedUrls: [attemptedUrl]
            )
        } else {
            print("No fallback available, failing download for chapter: \(chapter.name)")
            download.status = .failed("Failed to download chapter \(chapter.name): \(error.localizedDescription)")
            activeDownloads[index] = download
            downloadTasks[download.id] = nil
            downloadInfo[download.id] = nil
            LiveActivityManager.shared.end()
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
            completedDownload.completedDate = Date()
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
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error,
           let downloadTask = task as? URLSessionDownloadTask {
            Task { @MainActor in
                guard let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key else { return }
                handleDownloadError(downloadId: downloadId, downloadTask: downloadTask, error: error)
            }
        }
    }
}
