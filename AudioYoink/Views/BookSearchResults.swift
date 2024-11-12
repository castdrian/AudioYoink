import SwiftUI
import SwiftSoup
import Kingfisher

struct BookSearchResults: View {
    let searchQuery: String
    @State private var searchResults: [(title: String, url: String, imageUrl: String)] = []
    @State private var isSearching = false
    @State private var showError = false
    @State private var errorMessage = ""
    let isSearchFieldFocused: Bool
    
    var body: some View {
        ScrollView {
            if isSearching {
                ProgressView()
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(searchResults, id: \.url) { result in
                        NavigationLink(destination: BookDetailView(url: result.url)) {
                            HStack(spacing: 12) {
                                KFImage(URL(string: result.imageUrl))
                                    .placeholder {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .lineLimit(2)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
        }
        .allowsHitTesting(!isSearchFieldFocused)
        .task {
            await performSearch()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func performSearch() async {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        do {
            searchResults = try await searchBook(query: searchQuery)
            isSearching = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isSearching = false
        }
    }
    
    private func searchBook(query: String) async throws -> [(title: String, url: String, imageUrl: String)] {
        let searchUrl = "https://tokybook.com/?s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: searchUrl) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        let doc = try SwiftSoup.parse(html)
        let results = try doc.select("article")
        
        return try results.array().map { element in
            let title = try element.select("h2.entry-title a").text()
            let url = try element.select("h2.entry-title a").attr("href")
            let imageUrl = try element.select("img.wp-post-image").attr("src")
            return (title: title, url: url, imageUrl: imageUrl)
        }
    }
}

#Preview {
    NavigationView {
        BookSearchResults(
            searchQuery: "he who fights with monsters",
            isSearchFieldFocused: false
        )
    }
}