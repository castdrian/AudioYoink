import ActivityKit
import Foundation

public struct AudioBookDownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var chapterProgress: Double
        public var currentChapter: Int
        public var totalChapters: Int
        public var downloadSpeed: String
        public var chapterDownloadSpeed: String
        
        public init(
            progress: Double,
            chapterProgress: Double,
            currentChapter: Int,
            totalChapters: Int,
            downloadSpeed: String,
            chapterDownloadSpeed: String
        ) {
            self.progress = progress
            self.chapterProgress = chapterProgress
            self.currentChapter = currentChapter
            self.totalChapters = totalChapters
            self.downloadSpeed = downloadSpeed
            self.chapterDownloadSpeed = chapterDownloadSpeed
        }
    }
    
    public let bookTitle: String
    public let coverUrl: String?
    
    public init(bookTitle: String, coverUrl: String?) {
        self.bookTitle = bookTitle
        self.coverUrl = coverUrl
    }
}
