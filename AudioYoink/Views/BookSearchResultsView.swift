import Kingfisher
import Awesome
import SwiftSoup
import SwiftUI
import SafariUI

struct BookSearchResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    let searchQuery: String
    @State private var searchResults: [(title: String, url: String, imageUrl: String)] = []
    @State private var isSearching = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedSource: BookSource = .tokybook
    let isSearchFieldFocused: Bool
    @State private var showGitHub = false

    var body: some View {
        VStack {
            Picker("Source", selection: $selectedSource) {
                ForEach(BookSource.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            ScrollView {
                if isSearching {
                    ProgressView()
                        .padding()
                } else if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No results found")
                            .font(.headline)
                        Text("Try adjusting your search or switching sources")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
        .allowsHitTesting(!isSearchFieldFocused)
        .task {
            await performSearch()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: selectedSource) { _, _ in
            Task {
                await performSearch()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showGitHub = true }) {
                    Awesome.Brand.github.image
                        .size(40)
                        .foregroundColor(.label)
                }
                .offset(x: 8)
            }
        }
        .sheet(isPresented: $showGitHub) {
            SafariView(url: URL(string: "https://github.com/castdrian/AudioYoink")!)
                .ignoresSafeArea()
        }
        .onDisappear {
            NotificationCenter.default.post(name: NSNotification.Name("ClearSearchState"), object: nil)
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
        let baseUrl = selectedSource == .tokybook
            ? "https://tokybook.com/?s="
            : "https://freeaudiobooks.top/?s="
        let searchUrl = baseUrl + (query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")

        guard let url = URL(string: searchUrl) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let doc = try SwiftSoup.parse(String(data: data, encoding: .utf8) ?? "")

        switch selectedSource {
        case .tokybook:
            let results = try doc.select("article")
            return try results.array().map { element in
                let title = try element.select("h2.entry-title a").text()
                let url = try element.select("h2.entry-title a").attr("href")
                let imageUrl = try element.select("img.wp-post-image").attr("src")
                return (title: title, url: url, imageUrl: imageUrl)
            }

        case .freeaudiobooks:
            let articles = try doc.select("article")

            return try articles.array().map { element in
                let title = try element.select("h1.main-title.title a").text()

                let url = try element.select("h1.main-title.title a").attr("href")

                let imageStyle = try element.select(".featured-image .thumb span.fullimage").first()?.attr("style") ?? ""
                let imageUrl = imageStyle.replacingOccurrences(of: "background-image: url(", with: "")
                    .replacingOccurrences(of: ");", with: "")
                return (title: title, url: url, imageUrl: imageUrl)
            }
        }
    }
}

#Preview {
    NavigationView {
        BookSearchResultsView(
            searchQuery: "percy jackson",
            isSearchFieldFocused: false
        )
    }
}
