//
//  ContentView.swift
//  AudioYoink
//
//  Created by Adrian Castro on 12/11/24.
//

import SwiftUI
import SwiftSoup

struct SiteStatus {
    var isChecking = true
    var isReachable = false
    var latency: TimeInterval = 0
    var speed: Double = 0
    
    mutating func update(isReachable: Bool, latency: TimeInterval, speed: Double) {
        self.isChecking = false
        self.isReachable = isReachable
        self.latency = latency
        self.speed = speed
    }
}

struct ContentView: View {
    @State private var searchText = ""
    @State private var searchResults: [(title: String, url: String)] = []
    @State private var isSearching = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var siteStatus = SiteStatus()
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchFieldFocused = false
                    }
                
                VStack(spacing: 0) {
                    if searchResults.isEmpty && !isSearching {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "headphones.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.tint)
                            
                            HStack {
                                Text("tokybook.com")
                                    .font(.system(.body, design: .monospaced))
                                
                                if siteStatus.isChecking {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: siteStatus.isReachable ? 
                                        "checkmark.circle.fill" : "x.circle.fill")
                                        .foregroundColor(siteStatus.isReachable ? 
                                            .green : .red)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                            
                            if !siteStatus.isChecking {
                                VStack(alignment: .leading, spacing: 8) {
                                    ConnectionDetailRow(label: "Latency", 
                                        value: "\(Int(siteStatus.latency * 1000))ms")
                                    ConnectionDetailRow(label: "Speed", 
                                        value: "\(String(format: "%.1f", siteStatus.speed)) Mbps")
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        Spacer()
                    } else {
                        BookSearchResults(
                            searchQuery: searchText,
                            isSearchFieldFocused: isSearchFieldFocused
                        )
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Divider()
                        SearchBar(text: $searchText, onClear: {
                            withAnimation {
                                searchText = ""
                                searchResults = []
                                isSearching = false
                                isSearchFieldFocused = false
                            }
                        }) {
                            isSearchFieldFocused = false
                            performSearch()
                        }
                        .focused($isSearchFieldFocused)
                        .padding(.vertical, 8)
                        .background(.background)
                    }
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
        
        isSearching = true
        searchResults = []
        
        Task {
            do {
                let results = try await searchBook(query: searchText)
                DispatchQueue.main.async {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSearching = false
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
