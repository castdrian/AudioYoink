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
    @State private var isRefreshing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedSource: BookSource = .tokybook
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showDownloadManager = false
    @State private var searchText: String = ""
    @StateObject private var autocompleteManager = AutocompleteManager()
    @State private var shouldDismiss = false
    @EnvironmentObject private var downloadManager: DownloadManager
    @Namespace private var glassNamespace
    
    // Cache for search results per source
    @State private var searchCache: [BookSource: (query: String, results: [(title: String, url: String, imageUrl: String)])] = [:]

    init(searchQuery: String, isSearchFieldFocused: Bool, shouldPerformSearch: Binding<Bool>) {
        self.searchQuery = searchQuery
        self._searchText = State(initialValue: searchQuery)
        self._shouldPerformSearch = shouldPerformSearch
    }

    var body: some View {
        ZStack {
            // Background with gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.95),
                    Color(.systemGray6).opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Fixed source picker at top
                GlassEffectContainer(spacing: 0) {
                    HStack {
                        Picker("Source", selection: $selectedSource) {
                            ForEach(BookSource.allCases, id: \.self) { source in
                                Text(source.rawValue.replacingOccurrences(of: ".com", with: "").replacingOccurrences(of: ".net", with: "").replacingOccurrences(of: ".top", with: "")).tag(source)
                            }
                        }
                        .pickerStyle(.segmented)
                        .animation(.easeInOut, value: selectedSource)
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    .glassEffectID("sourcePicker", in: glassNamespace)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                if value.translation.width > threshold {
                                    // Swipe right - previous source
                                    withAnimation {
                                        if let currentIndex = BookSource.allCases.firstIndex(of: selectedSource),
                                           currentIndex > 0 {
                                            selectedSource = BookSource.allCases[currentIndex - 1]
                                        }
                                    }
                                } else if value.translation.width < -threshold {
                                    // Swipe left - next source
                                    withAnimation {
                                        if let currentIndex = BookSource.allCases.firstIndex(of: selectedSource),
                                           currentIndex < BookSource.allCases.count - 1 {
                                            selectedSource = BookSource.allCases[currentIndex + 1]
                                        }
                                    }
                                }
                            }
                    )
                }
                .background(.regularMaterial)
                .zIndex(1)
                
                // Scrollable content
                ScrollView {
                    if isSearching {
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.primary)
                            Text("Searching audiobooks...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(40)
                    } else if searchResults.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                            
                            VStack(spacing: 8) {
                                Text("No results found")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                Text("Try adjusting your search or switching sources")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(40)
                    } else {
                        // Grid layout for search results
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 20) {
                            ForEach(Array(searchResults.enumerated()), id: \.element.url) { index, result in
                                SearchResultCard(
                                    result: result,
                                    index: index,
                                    glassNamespace: glassNamespace
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
                .refreshable {
                    guard !isRefreshing else { return } // Prevent multiple concurrent refreshes
                    // Clear cache for current source and refresh
                    searchCache[selectedSource] = nil
                    // Add a small delay to ensure any pending requests are properly cancelled
                    try? await Task.sleep(for: .milliseconds(100))
                    // Use a separate function for refresh to handle errors properly
                    await refreshSearch()
                }
            }
            
            // Autocomplete overlay
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

    private func refreshSearch() async {
        guard !searchText.isEmpty else { return }
        guard !isRefreshing else { return } // Prevent concurrent refreshes
        
        isRefreshing = true
        isSearching = true
        // Don't clear searchResults here - preserve current results until we get new ones

        do {
            let results = try await searchBook(query: searchText)
            searchResults = results
            
            // Cache the results
            searchCache[selectedSource] = (query: searchText, results: results)
            
        } catch {
            // Only silence cancellation errors during refresh
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                // This is a cancellation error - handle silently, keep current results
            } else {
                // For other errors, try to use cached results if available
                if let cached = searchCache[selectedSource], 
                   cached.query.lowercased() == searchText.lowercased() {
                    searchResults = cached.results
                }
                // If no cached results, keep the current results (don't clear them)
            }
        }
        
        isSearching = false
        isRefreshing = false
    }

    private func performSearch() async {
        guard !searchText.isEmpty else { return }

        // Check if we have cached results for this source and query
        if let cached = searchCache[selectedSource], 
           cached.query.lowercased() == searchText.lowercased() {
            searchResults = cached.results
            return
        }

        isSearching = true
        searchResults = []

        do {
            let results = try await searchBook(query: searchText)
            searchResults = results
            
            // Cache the results
            searchCache[selectedSource] = (query: searchText, results: results)
            
            isSearching = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isSearching = false
        }
    }

    private func searchBook(query: String) async throws -> [(title: String, url: String, imageUrl: String)] {
        let baseUrl: String
        switch selectedSource {
        case .tokybook:
            baseUrl = "https://tokybook.com/?s="
        case .freeaudiobooks:
            baseUrl = "https://freeaudiobooks.top/?s="
        case .goldenaudiobook:
            baseUrl = "https://goldenaudiobook.net/?s="
        }
        
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
            
        case .goldenaudiobook:
            let articles = try doc.select("article")
            return try articles.array().map { element in
                let title = try element.select("h2.title-post a").text()
                let url = try element.select("h2.title-post a").attr("href")
                let imageUrl = try element.select("img.wp-post-image").attr("data-src").isEmpty 
                    ? try element.select("img.wp-post-image").attr("src")
                    : try element.select("img.wp-post-image").attr("data-src")
                return (title: title, url: url, imageUrl: imageUrl)
            }
        }
    }
}

struct SearchResultCard: View {
    let result: (title: String, url: String, imageUrl: String)
    let index: Int
    let glassNamespace: Namespace.ID
    @State private var showingDetails = false
    
    var body: some View {
        NavigationLink(destination: BookDetailView(
            url: result.url,
            bookTitle: result.title,
            coverUrl: result.imageUrl
        )) {
            VStack(spacing: 12) {
                // Book cover image
                KFImage(URL(string: result.imageUrl))
                    .placeholder {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.tertiary)
                            .overlay {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 140)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .primary.opacity(0.1), radius: 6, y: 3)
                
                // Book title
                Text(result.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .glassEffectID("card_\(index)", in: glassNamespace)
        .onLongPressGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            BookDetailView(
                url: result.url,
                bookTitle: result.title,
                coverUrl: result.imageUrl
            )
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
