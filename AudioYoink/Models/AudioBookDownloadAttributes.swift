import ActivityKit
import Foundation

public struct AudioBookDownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var currentChapter: Int
        public var totalChapters: Int
        public var downloadSpeed: String
        
        public init(
            progress: Double,
            currentChapter: Int,
            totalChapters: Int,
            downloadSpeed: String
        ) {
            self.progress = progress
            self.currentChapter = currentChapter
            self.totalChapters = totalChapters
            self.downloadSpeed = downloadSpeed
        }
    }
    
    public let bookTitle: String
    public let author: String
    
    public init(bookTitle: String, author: String) {
        self.bookTitle = bookTitle
        self.author = author
    }
}
