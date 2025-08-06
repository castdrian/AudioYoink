enum BookSource: String, CaseIterable {
    case tokybook = "tokybook.com"
    case goldenaudiobook = "goldenaudiobook.net"
    case freeaudiobooks = "freeaudiobooks.top"
    
    var skipChapter: String {
        switch self {
        case .tokybook:
            return "https://file.tokybook.com/upload/welcome-you-to-tokybook.mp3"
        case .freeaudiobooks:
            return "https://freeaudiobooks.top/wp-content/uploads/welcome-to-freeaudiobook-top.mp3"
        case .goldenaudiobook:
            return "" // No known skip chapter for Golden Audiobook
        }
    }
    
    var mediaURL: String {
        switch self {
        case .tokybook:
            return "https://files01.tokybook.com/audio/"
        case .freeaudiobooks:
            return "https://files01.freeaudiobooks.top/audio/"
        case .goldenaudiobook:
            return "https://ipaudio.club/wp-content/uploads/GOLN/"
        }
    }
    
    var mediaFallbackURL: String {
        switch self {
        case .tokybook:
            return "https://files02.tokybook.com/audio/"
        case .freeaudiobooks:
            return "https://files02.freeaudiobooks.top/audio/"
        case .goldenaudiobook:
            return "https://ipaudio.club/wp-content/uploads/GOLN/"
        }
    }
    
    static func fromURL(_ url: String) -> BookSource? {
        return Self.allCases.first { source in
            url.contains(source.rawValue)
        }
    }
}
