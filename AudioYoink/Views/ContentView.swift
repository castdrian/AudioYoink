//
//  ContentView.swift
//  AudioYoink
//
//  Created by Adrian Castro on 12/11/24.
//

import Awesome
import Defaults
import SwiftSoup
import SwiftUI
import SafariUI

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
    @State private var showDownloadManager = false
    @State private var showGitHub = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchFieldFocused = false
                        hideKeyboard()
                    }

                VStack(spacing: 0) {
                    if shouldPerformSearch || isSearching || !searchResults.isEmpty {
                        BookSearchResultsView(
                            searchQuery: searchText,
                            isSearchFieldFocused: isSearchFieldFocused
                        )
                    } else if isSearchFieldFocused, !autoCompleteResults.isEmpty {
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

                VStack {
                    if !isSearchFieldFocused {
                        Spacer()
                    }

                    SearchBar(
                        text: $searchText,
                        onClear: {
                            withAnimation {
                                searchText = ""
                                searchResults = []
                                autoCompleteResults = []
                                isSearching = false
                                isSearchFieldFocused = false
                                shouldPerformSearch = false
                            }
                        },
                        onSubmit: {
                            isSearchFieldFocused = false
                            autoCompleteResults = []
                            performSearch()
                        },
                        showDownloadManager: {
                            showDownloadManager = true
                        },
                        isLoading: isAutocompleting
                    )
                    .focused($isSearchFieldFocused)
                    .padding(.bottom, 8)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.1), value: isSearchFieldFocused)
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
            .onChange(of: searchText) { _, _ in
                autocompleteTask?.cancel()

                if !isSearchFieldFocused {
                    return
                }

                if searchText.count < 2 {
                    withAnimation {
                        autoCompleteResults = []
                        isAutocompleting = false
                    }
                    return
                }

                isAutocompleting = true
                autocompleteTask = Task(priority: .userInitiated) {
                    await performAutocomplete()
                }
            }
            .onChange(of: isSearchFieldFocused) { _, newValue in
                if !newValue {
                    autoCompleteResults = []
                }
            }
            .task {
                await checkSiteStatus()
            }
        }
        .sheet(isPresented: $showDownloadManager) {
            DownloadManagerView()
        }
    }

    func checkSiteStatus() async {
        async let mainSite = checkSite(url: "https://tokybook.com")
        async let mirrorSite = checkSite(url: "https://freeaudiobooks.top")

        let (main, mirror) = await (mainSite, mirrorSite)

        await MainActor.run {
            siteStatus.update(isReachable: main.isReachable,
                              latency: main.latency,
                              speed: main.speed)
            siteStatus.updateMirror(isReachable: mirror.isReachable,
                                    latency: mirror.latency,
                                    speed: mirror.speed)
        }
    }

    private func checkSite(url: String) async -> (isReachable: Bool, latency: TimeInterval, speed: Double) {
        do {
            let startTime = Date()
            let (_, response) = try await URLSession.shared.data(from: URL(string: url)!)
            let endTime = Date()

            let latency = endTime.timeIntervalSince(startTime)
            let httpResponse = response as? HTTPURLResponse
            let bytes = Double(httpResponse?.expectedContentLength ?? 0)
            let megabits = max((bytes * 8) / 1_000_000, 0.1)
            let speed = round((megabits / latency) * 10) / 10

            return (isReachable: httpResponse?.statusCode == 200,
                    latency: latency,
                    speed: speed)
        } catch {
            return (isReachable: false, latency: 0, speed: 0)
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
        let query = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://openlibrary.org/search.json?q=\(query)&fields=key,title,author_name,first_publish_year,cover_i,publisher,subject&limit=10") else {
            await MainActor.run { isAutocompleting = false }
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
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.1)) {
                        autoCompleteResults = docs.map { OpenLibraryBook(from: $0) }
                    }
                    isAutocompleting = false
                }
            }
        } catch {
            await MainActor.run {
                autoCompleteResults = []
                isAutocompleting = false
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
    let showDownloadManager: () -> Void
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search audiobooks...", text: $text)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit(onSubmit)

                if !text.isEmpty {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    } else {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray3), lineWidth: 1)
            )
            .cornerRadius(10)

            Button(action: showDownloadManager) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
            }
        }
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

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil,
                                        from: nil,
                                        for: nil)
    }
}

#Preview {
    ContentView()
}
