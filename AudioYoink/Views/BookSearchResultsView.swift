import Awesome
import Defaults
import Kingfisher
import SafariUI
import SwiftSoup
import SwiftUI

struct BookSearchResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @Default(.searchHistory) private var searchHistory
    let searchQuery: String
    @Binding var shouldPerformSearch: Bool
    @State private var searchResults: [(title: String, url: String, imageUrl: String)] = []
    @State private var isSearching = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedSource: BookSource = .tokybook
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showDownloadManager = false
    @State private var searchText: String = ""
    @StateObject private var autocompleteManager = AutocompleteManager()
    @State private var shouldDismiss = false
    @EnvironmentObject private var downloadManager: DownloadManager

    init(searchQuery: String, isSearchFieldFocused: Bool, shouldPerformSearch: Binding<Bool>) {
        self.searchQuery = searchQuery
        self._searchText = State(initialValue: searchQuery)
        self._shouldPerformSearch = shouldPerformSearch
    }

    var body: some View {
        ZStack {
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
                                NavigationLink(destination: BookDetailView(
                                    url: result.url,
                                    bookTitle: result.title,
                                    coverUrl: result.imageUrl
                                )) {
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
            if isSearchFieldFocused, !autocompleteManager.results.isEmpty {
                AutocompleteView(books: autocompleteManager.results) { book in
                    withAnimation {
                        searchText = book.title
                        isSearchFieldFocused = false
                        autocompleteManager.clearResults()
                        shouldDismiss = false

                        if !searchHistory.contains(where: { $0.id == book.id }) {
                            searchHistory.insert(book, at: 0)
                            if searchHistory.count > 10 {
                                searchHistory.removeLast()
                            }
                        }

                        Task {
                            await performSearch()
                        }
                    }
                }
                .zIndex(1)
            }
        }
        .withSearchToolbar(
            searchText: $searchText,
            externalFocus: Binding(
                get: { isSearchFieldFocused },
                set: { isSearchFieldFocused = $0 }
            ),
            onClear: {
                withAnimation {
                    searchText = ""
                    searchResults = []
                    shouldDismiss = true
                    shouldPerformSearch = false
                    dismiss()
                }
            },
            onSubmit: {
                Task {
                    await performSearch()
                }
            },
            showDownloadManager: { showDownloadManager = true }
        )
        .padding(.top, 8)
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
        .sheet(isPresented: $showDownloadManager) {
            DownloadManagerView()
        }
        .onDisappear {
            if shouldDismiss {
                NotificationCenter.default.post(name: NSNotification.Name("ClearSearchState"), object: nil)
            }
        }
        .withGitHubButton()
    }

    private func performSearch() async {
        guard !searchText.isEmpty else { return }

        isSearching = true
        searchResults = []

        do {
            searchResults = try await searchBook(query: searchText)
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
            isSearchFieldFocused: false,
            shouldPerformSearch: .constant(true)
        )
    }
}
