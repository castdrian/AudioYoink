import Foundation
import SwiftUI

class AutocompleteManager: ObservableObject {
    @Published var results: [OpenLibraryBook] = []
    @Published var isLoading = false
    private var task: Task<Void, Never>?
    
    func search(query: String) {
        task?.cancel()
        
        guard query.count >= 2 else {
            clearResults()
            return
        }
        
        isLoading = true
        task = Task(priority: .userInitiated) { @MainActor in
            await performAutocomplete(query: query)
        }
    }
    
    @MainActor
    private func performAutocomplete(query: String) async {
        guard let url = URL(string: "https://openlibrary.org/search.json?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&fields=key,title,author_name,first_publish_year,cover_i,publisher,subject&limit=10") else {
            clearResults()
            return
        }

        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5
            config.timeoutIntervalForResource = 5
            let session = URLSession(configuration: config)

            let (data, _) = try await session.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let docs = json?["docs"] as? [[String: Any]] ?? []

            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.1)) {
                    results = docs.map { OpenLibraryBook(from: $0) }
                }
            }
        } catch {
            clearResults()
        }
        isLoading = false
    }
    
    func clearResults() {
        withAnimation {
            results = []
            isLoading = false
        }
    }
}
