//
//  ContentView.swift
//  AudioYoink
//
//  Created by Adrian Castro on 12/11/24.
//

import SwiftUI
import SwiftSoup
import Defaults

struct ContentView: View {
    @State private var searchText = ""
    @State private var searchResults: [(title: String, url: String)] = []
    @State private var autoCompleteResults: [OpenLibraryBook] = []
    @State private var selectedBook: OpenLibraryBook?
    @State private var isSearching = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var siteStatus = SiteStatus()
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isAutocompleting = false
    @State private var autocompleteTask: Task<Void, Never>?
    @State private var shouldPerformSearch = false
    @Default(.searchHistory) private var searchHistory
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchFieldFocused = false
                    }
                
                VStack(spacing: 0) {
                    if shouldPerformSearch || isSearching || !searchResults.isEmpty {
                        BookSearchResults(
                            searchQuery: searchText,
                            isSearchFieldFocused: isSearchFieldFocused
                        )
                    } else if isSearchFieldFocused && !autoCompleteResults.isEmpty {
                        AutocompleteView(books: autoCompleteResults) { book in
                            handleAutocompleteTap(book)
                        }
                    } else {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "headphones.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.tint)
                            
                            SiteStatusView(siteStatus: siteStatus)
                            
                            if !searchHistory.isEmpty {
                                SearchHistoryView(
                                    searchHistory: searchHistory,
                                    onTap: handleAutocompleteTap,
                                    onClear: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            searchHistory = []
                                        }
                                    }
                                )
                            }
                        }
                        Spacer()
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    SearchBar(text: $searchText, onClear: {
                        withAnimation {
                            searchText = ""
                            searchResults = []
                            autoCompleteResults = []
                            isSearching = false
                            isSearchFieldFocused = false
                            shouldPerformSearch = false
                        }
                    }) {
                        isSearchFieldFocused = false
                        autoCompleteResults = []
                        performSearch()
                    }
                    .focused($isSearchFieldFocused)
                    .padding(.vertical, 8)
                    .background(.background)
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                autocompleteTask?.cancel()
                
                if isSearching || shouldPerformSearch {
                    return
                }
                
                if searchText.count < 2 {
                    withAnimation {
                        autoCompleteResults = []
                        isAutocompleting = false
                    }
                    return
                }
                
                if isSearchFieldFocused {
                    isAutocompleting = true
                    
                    autocompleteTask = Task {
                        if !Task.isCancelled {
                            await performAutocomplete()
                        }
                    }
                }
            }
            .onChange(of: isSearchFieldFocused) { oldValue, newValue in
                if !newValue {
                    autoCompleteResults = []
                }
            }
            .task {
                await checkSiteStatus()
            }
        }
    }
    
    func checkSiteStatus() async {
        do {
            let startTime = Date()
            let (_, response) = try await URLSession.shared.data(from: URL(string: "https://tokybook.com")!)
            let endTime = Date()
            
            let latency = endTime.timeIntervalSince(startTime)
            let httpResponse = response as? HTTPURLResponse
            let bytes = Double(httpResponse?.expectedContentLength ?? 0)
            let megabits = max((bytes * 8) / 1_000_000, 0.1)
            let speed = round((megabits / latency) * 10) / 10
            
            await MainActor.run {
                siteStatus.update(isReachable: httpResponse?.statusCode == 200,
                                latency: latency,
                                speed: speed)
            }
        } catch {
            await MainActor.run {
                siteStatus.update(isReachable: false,
                                latency: 0,
                                speed: 0)
            }
        }
    }
    
    func performSearch() {
        guard !searchText.isEmpty else { return }
        
        shouldPerformSearch = true
        isSearching = true
        
        Task {
            do {
                let results = try await searchBook(query: searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                    shouldPerformSearch = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSearching = false
                    shouldPerformSearch = false
                }
            }
        }
    }
    
    func searchBook(query: String) async throws -> [(title: String, url: String)] {
        let searchUrl = "https://tokybook.com/?s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: searchUrl) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        let doc = try SwiftSoup.parse(html)
        let results = try doc.select("h2.entry-title")
        
        return try results.array().map { element in
            let link = try element.select("a").first()
            let title = try link?.text() ?? ""
            let url = try link?.attr("href") ?? ""
            return (title: title, url: url)
        }
    }
    
    func performAutocomplete() async {
        isAutocompleting = true
        defer {
            isAutocompleting = false
        }
        
        let query = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://openlibrary.org/search.json?q=\(query)&fields=key,title,author_name,first_publish_year,cover_i,publisher,subject&limit=10") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let docs = json?["docs"] as? [[String: Any]] ?? []
            
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.spring()) {
                        autoCompleteResults = docs.map { OpenLibraryBook(from: $0) }
                    }
                }
            }
        } catch {
            await MainActor.run {
                autoCompleteResults = []
            }
        }
    }
    
    private func handleAutocompleteTap(_ book: OpenLibraryBook) {
        selectedBook = book
        searchText = book.title
        isSearchFieldFocused = false
        autoCompleteResults = []
        
        if !searchHistory.contains(where: { $0.id == book.id }) {
            searchHistory.insert(book, at: 0)
            if searchHistory.count > 10 {
                searchHistory.removeLast()
            }
        }
        
        performSearch()
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onClear: () -> Void
    let onSubmit: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search audiobooks...", text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit(onSubmit)
            
            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct SearchResultRow: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ConnectionDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

#Preview {
    ContentView()
}
