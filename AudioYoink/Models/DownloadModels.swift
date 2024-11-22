enum DownloadStatus {
    case downloading
    case completed
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
    
    var downloadedSize: Double {
        var size = chapterSizes[..<(currentChapter - 1)].reduce(0, +)
        size += chapterSizes[currentChapter - 1] * chapterProgress
        return size
    }
    
    var totalSize: Double {
        chapterSizes.reduce(0, +)
    }
} 