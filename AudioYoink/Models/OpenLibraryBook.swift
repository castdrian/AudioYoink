import Foundation

struct OpenLibraryBook: Identifiable, Equatable {
    let id: String
    let title: String
    let author: String
    let year: Int
    let coverUrl: URL?
    let publisher: String
    let genres: [String]
    
    init(from doc: [String: Any]) {
        self.id = (doc["key"] as? String) ?? UUID().uuidString
        self.title = (doc["title"] as? String)?.trimmingCharacters(in: .whitespaces) ?? "Unknown Title"
        self.author = (doc["author_name"] as? [String])?.first ?? "Unknown Author"
        self.year = (doc["first_publish_year"] as? Int) ?? 0
        
        if let coverId = doc["cover_i"] as? Int {
            self.coverUrl = URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-S.jpg")
        } else {
            self.coverUrl = nil
        }
        
        self.publisher = (doc["publisher"] as? [String])?.first ?? ""
        
        if let subjects = doc["subject"] as? [String] {
            self.genres = subjects
                .filter { !$0.lowercased().contains("series:") }
                .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
        } else {
            self.genres = []
        }
    }
    
    static func == (lhs: OpenLibraryBook, rhs: OpenLibraryBook) -> Bool {
        return lhs.id == rhs.id
    }
} 
