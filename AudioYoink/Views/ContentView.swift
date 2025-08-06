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
    @State private var selectedBook: OpenLibraryBook?
    @State private var isSearching = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var siteStatus = SiteStatus()
    @FocusState private var isSearchFieldFocused: Bool
    @State private var shouldPerformSearch = false
    @Default(.searchHistory) private var searchHistory
    @State private var showDownloadManager = false
    @StateObject private var autocompleteManager = AutocompleteManager()
	@EnvironmentObject private var downloadManager: DownloadManager
    @Namespace private var glassNamespace

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background with subtle gradient
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95),
                        Color(.systemGray6).opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isSearchFieldFocused = false
                        hideKeyboard()
                    }
                }

                GeometryReader { geometry in
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: geometry.size.height * 0.05)
                        
                        VStack(spacing: 28) {
                            // App Icon with Liquid Glass
                            if let appIcon = AppIconProvider.appIcon() {
                                Image(uiImage: appIcon)
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                                    .shadow(color: .primary.opacity(0.1), radius: 8, y: 4)
                                    .scaleEffect(1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: false)
                            }

                            SiteStatusView(siteStatus: siteStatus)

                            if !searchHistory.isEmpty {
                                SearchHistoryView(
                                    searchHistory: searchHistory,
                                    onTap: handleAutocompleteTap,
                                    onClear: {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            searchHistory = []
                                        }
                                    },
                                    onDelete: { book in
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                            searchHistory.removeAll { $0.id == book.id }
                                        }
                                    }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                    }
                }
                .zIndex(0)
                .ignoresSafeArea(.keyboard)

                if isSearchFieldFocused, !searchText.isEmpty, !autocompleteManager.results.isEmpty {
                    AutocompleteView(books: autocompleteManager.results) { book in
                        handleAutocompleteTap(book)
                    }
                    .zIndex(1)
                }

                VStack {
                    if !isSearchFieldFocused {
                        Spacer()
                    }

                    SearchBar(
                        text: $searchText,
                        onClear: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                searchText = ""
                                NotificationCenter.default.post(name: NSNotification.Name("ClearSearchState"), object: nil)
                            }
                        },
                        onSubmit: submitSearch,
                        showDownloadManager: {
                            showDownloadManager = true
                        },
                        isLoading: autocompleteManager.isLoading,
                        autocompleteManager: autocompleteManager,
                        glassNamespace: glassNamespace
                    )
                    .focused($isSearchFieldFocused)
                    .padding(.bottom, isSearchFieldFocused ? 16 : 8)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isSearchFieldFocused)
                .zIndex(2)
            }
            .navigationDestination(isPresented: $shouldPerformSearch) {
                BookSearchResultsView(
                    searchQuery: searchText,
                    isSearchFieldFocused: false,
                    shouldPerformSearch: $shouldPerformSearch
                )
                .onDisappear {
                    if !shouldPerformSearch {
                        clearSearch()
                    }
                }
            }
            .withGitHubButton()
            .sheet(isPresented: $showDownloadManager) {
                DownloadManagerView()
            }
            .task {
                await checkSiteStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearSearchState"))) { _ in
                withAnimation {
                    searchText = ""
                    searchResults = []
                    isSearching = false
                    isSearchFieldFocused = false
                    shouldPerformSearch = false
                }
            }
        }
    }

    func checkSiteStatus() async {
        async let mainSite = checkSite(url: "https://tokybook.com")
        async let mirrorSite = checkSite(url: "https://freeaudiobooks.top")
        async let goldenSite = checkSite(url: "https://goldenaudiobook.net")

        let (main, mirror, golden) = await (mainSite, mirrorSite, goldenSite)

        await MainActor.run {
            siteStatus.update(isReachable: main.isReachable,
                              latency: main.latency,
                              speed: main.speed)
            siteStatus.updateMirror(isReachable: mirror.isReachable,
                                    latency: mirror.latency,
                                    speed: mirror.speed)
            siteStatus.updateGolden(isReachable: golden.isReachable,
                                    latency: golden.latency,
                                    speed: golden.speed)
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
        isSearching = true

        Task {
            do {
                let results = try await searchBook(query: searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
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

    private func handleAutocompleteTap(_ book: OpenLibraryBook) {
        selectedBook = book
        searchText = book.title
        isSearchFieldFocused = false
        autocompleteManager.clearResults()

        if !searchHistory.contains(where: { $0.id == book.id }) {
            searchHistory.insert(book, at: 0)
            if searchHistory.count > 10 {
                searchHistory.removeLast()
            }
        }

        shouldPerformSearch = true
        Task {
            await MainActor.run {
                performSearch()
            }
        }
    }

    private func clearSearch() {
        withAnimation {
            searchText = ""
            searchResults = []
            isSearching = false
            isSearchFieldFocused = false
            shouldPerformSearch = false
        }
    }

    private func submitSearch() {
        isSearchFieldFocused = false
        shouldPerformSearch = true
        performSearch()
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onClear: () -> Void
    let onSubmit: () -> Void
    let showDownloadManager: () -> Void
    let isLoading: Bool
    @ObservedObject var autocompleteManager: AutocompleteManager
    let glassNamespace: Namespace.ID
    
    var body: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                // Search field with liquid glass
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 18, weight: .medium))
                    
                    TextField("Search audiobooks...", text: $text)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .font(.system(size: 16, weight: .medium))
                        .onSubmit(onSubmit)
                        .onChange(of: text) { _, newValue in
                            autocompleteManager.search(query: newValue)
                        }
                    
                    if !text.isEmpty {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 18, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.secondary)
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(height: 52)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
                .glassEffectID("searchField", in: glassNamespace)
                
                // Download manager button
                Button(action: showDownloadManager) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 52, height: 52)
                .glassEffect(.regular.interactive(), in: .circle)
            }
            .padding(.horizontal, 20)
        }
    }
}

struct SearchResultRow: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    }
}

struct ConnectionDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .foregroundStyle(.primary)
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
