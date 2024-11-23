import Defaults

enum DownloadStatus: Codable, Equatable {
    case downloading
    case completed
    case failed(String)
    
    private enum CodingKeys: String, CodingKey {
        case type, message
    }
    
    private enum StatusType: String, Codable {
        case downloading, completed, failed
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .downloading:
            try container.encode(StatusType.downloading, forKey: .type)
        case .completed:
            try container.encode(StatusType.completed, forKey: .type)
        case .failed(let message):
            try container.encode(StatusType.failed, forKey: .type)
            try container.encode(message, forKey: .message)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StatusType.self, forKey: .type)
        switch type {
        case .downloading:
            self = .downloading
        case .completed:
            self = .completed
        case .failed:
            let message = try container.decode(String.self, forKey: .message)
            self = .failed(message)
        }
    }
}

struct DownloadItem: Identifiable, Codable, Defaults.Serializable {
    let id: UUID
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
    let directoryPath: String
    let duration: TimeInterval
    var completedDate: Date?
    
    var directory: URL {
        URL(fileURLWithPath: directoryPath)
    }
    
    var downloadedSize: Double {
        var size = chapterSizes[..<(currentChapter - 1)].reduce(0, +)
        size += chapterSizes[currentChapter - 1] * chapterProgress
        return size
    }
    
    var totalSize: Double {
        chapterSizes.reduce(0, +)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, coverUrl, progress, chapterProgress, status, currentChapter
        case totalChapters, chapterSizes, downloadSpeed, chapterDownloadSpeed
        case directoryPath, duration, completedDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        progress = try container.decode(Double.self, forKey: .progress)
        chapterProgress = try container.decode(Double.self, forKey: .chapterProgress)
        status = try container.decode(DownloadStatus.self, forKey: .status)
        currentChapter = try container.decode(Int.self, forKey: .currentChapter)
        totalChapters = try container.decode(Int.self, forKey: .totalChapters)
        chapterSizes = try container.decode([Double].self, forKey: .chapterSizes)
        downloadSpeed = try container.decode(String.self, forKey: .downloadSpeed)
        chapterDownloadSpeed = try container.decode(String.self, forKey: .chapterDownloadSpeed)
        directoryPath = try container.decode(String.self, forKey: .directoryPath)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        completedDate = try container.decodeIfPresent(Date.self, forKey: .completedDate)
    }
    
    init(title: String, coverUrl: String?, progress: Double, chapterProgress: Double, status: DownloadStatus, currentChapter: Int, totalChapters: Int, chapterSizes: [Double], downloadSpeed: String, chapterDownloadSpeed: String, directory: URL, duration: TimeInterval, completedDate: Date?) {
        self.id = UUID()
        self.title = title
        self.coverUrl = coverUrl
        self.progress = progress
        self.chapterProgress = chapterProgress
        self.status = status
        self.currentChapter = currentChapter
        self.totalChapters = totalChapters
        self.chapterSizes = chapterSizes
        self.downloadSpeed = downloadSpeed
        self.chapterDownloadSpeed = chapterDownloadSpeed
        self.directoryPath = directory.path
        self.duration = duration
        self.completedDate = completedDate
    }
} 
