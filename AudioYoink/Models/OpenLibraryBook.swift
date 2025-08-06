import Defaults
import Foundation

struct OpenLibraryBook: Identifiable, Equatable, Codable, Defaults.Serializable {
    let id: String
    let title: String
    let author: String
    let year: Int
    let coverUrl: URL?
    let publisher: String
    let genres: [String]

    init(from doc: [String: Any]) {
        id = (doc["key"] as? String) ?? UUID().uuidString
        title = (doc["title"] as? String)?.trimmingCharacters(in: .whitespaces) ?? "Unknown Title"
        author = (doc["author_name"] as? [String])?.first ?? "Unknown Author"
        year = (doc["first_publish_year"] as? Int) ?? 0

        if let coverId = doc["cover_i"] as? Int {
            coverUrl = URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-S.jpg")
        } else {
            coverUrl = nil
        }

        publisher = (doc["publisher"] as? [String])?.first ?? ""

        if let subjects = doc["subject"] as? [String] {
            genres = subjects
                .filter { 
                    let lowercased = $0.lowercased()
                    return !lowercased.contains("series:") && 
                           !lowercased.contains("serie:") &&
                           !lowercased.hasPrefix("series") &&
                           !lowercased.hasPrefix("serie") &&
                           !lowercased.contains("saga:") &&
                           !lowercased.hasPrefix("saga")
                }
                .map { 
                    var cleaned = $0.replacingOccurrences(of: "_", with: " ")
                    
                    // Remove common prefixes
                    let prefixes = ["Serie:", "Series:", "Saga:", "Collection:", "Série:"]
                    for prefix in prefixes {
                        if cleaned.hasPrefix(prefix) {
                            cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                            break
                        }
                    }
                    
                    return cleaned.capitalized
                }
                .filter { !$0.isEmpty }
        } else {
            genres = []
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, author, year, coverUrl, publisher, genres
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        year = try container.decode(Int.self, forKey: .year)
        coverUrl = try container.decodeIfPresent(URL.self, forKey: .coverUrl)
        publisher = try container.decode(String.self, forKey: .publisher)
        genres = try container.decode([String].self, forKey: .genres)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(year, forKey: .year)
        try container.encode(coverUrl, forKey: .coverUrl)
        try container.encode(publisher, forKey: .publisher)
        try container.encode(genres, forKey: .genres)
    }

    static func == (lhs: OpenLibraryBook, rhs: OpenLibraryBook) -> Bool {
        lhs.id == rhs.id
    }
}

extension Defaults.Keys {
    static let searchHistory = Key<[OpenLibraryBook]>("searchHistory", default: [])
}
