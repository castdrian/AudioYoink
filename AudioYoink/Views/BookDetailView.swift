import SwiftSoup
import SwiftUI

struct Chapter: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let duration: String
    
    init(name: String, url: String, duration: String) {
        self.name = name
        self.url = url
        
        if duration.contains(":") {
            self.duration = duration
        } else if let seconds = Double(duration) {
            let totalSeconds = Int(seconds)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let remainingSeconds = totalSeconds % 60
            
            if hours > 0 {
                self.duration = String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
            } else {
                self.duration = String(format: "%02d:%02d", minutes, remainingSeconds)
            }
        } else {
            self.duration = "00:00"
        }
    }
}

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case parsingError
    case invalidDurationFormat
}

struct TrackResponse: Codable {
    let name: String
    let chapter_link_dropbox: String
    let duration: String

    enum CodingKeys: String, CodingKey {
        case name
        case chapter_link_dropbox
        case duration
    }
}

struct BookDetailView: View {
    let url: String
    let source: BookSource?
    let bookTitle: String
    let coverUrl: String?
    
    @State private var chapters: [Chapter] = []
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @EnvironmentObject private var downloadManager: DownloadManager
    @State private var showDownloadManager = false

    init(url: String, bookTitle: String, coverUrl: String? = nil) {
        self.url = url
        self.source = BookSource.fromURL(url)
        self.bookTitle = bookTitle
        self.coverUrl = coverUrl
    }

    func fetchChapters(from url: String) async throws -> [Chapter] {
        let htmlDocument = try await downloadHTML(from: url)
        let htmlString = try htmlDocument.outerHtml()

        let pattern = #"tracks\s*=\s*(\[[^\]]+\])\s*,[^;]*;"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: htmlString, options: [], range: NSRange(location: 0, length: htmlString.utf16.count)),
           let range = Range(match.range(at: 1), in: htmlString)
        {
            var jsonString = String(htmlString[range])
            jsonString = jsonString.replacingOccurrences(of: "'", with: "\"")
                .replacingOccurrences(of: "\\", with: "")
                .replacingOccurrences(of: ",\n", with: ",")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: ",,", with: ",")

            if let jsonData = jsonString.data(using: .utf8) {
                let decoder = JSONDecoder()
                do {
                    let tracks = try decoder.decode([TrackResponse].self, from: jsonData)
                    return tracks
                        .filter { track in
                            track.chapter_link_dropbox != source?.skipChapter
                        }
                        .map { track in
                            let duration = track.duration.isEmpty ? "00:00" : track.duration
                            return Chapter(
                                name: track.name,
                                url: track.chapter_link_dropbox,
                                duration: duration
                            )
                        }
                } catch {
                    throw NetworkError.parsingError
                }
            }
            throw NetworkError.parsingError
        }
        throw NetworkError.parsingError
    }

    func downloadHTML(from urlString: String) async throws -> Document {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw NetworkError.invalidResponse
        }

        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw NetworkError.parsingError
        }

        return try SwiftSoup.parse(htmlString)
    }

    func calculateTotalDuration(_ chapters: [Chapter]) -> String {
        let totalSeconds = chapters.reduce(0) { total, chapter in
            if chapter.duration.contains(":") {
                let components = chapter.duration.split(separator: ":")
                if components.count == 3 {
                    let hours = Int(components[0]) ?? 0
                    let minutes = Int(components[1]) ?? 0
                    let seconds = Int(components[2]) ?? 0
                    return total + (hours * 3600 + minutes * 60 + seconds)
                } else if components.count == 2 {
                    let minutes = Int(components[0]) ?? 0
                    let seconds = Int(components[1]) ?? 0
                    return total + (minutes * 60 + seconds)
                }
            } else {
                return total + (Int(chapter.duration) ?? 0)
            }
            return total
        }

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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
            
            GlassEffectContainer(spacing: 16) {
                ScrollView {
                    if isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.primary)
                            Text("Loading chapters...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                                ChapterRow(chapter: chapter)
                                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                                    .glassEffectID("chapter_\(index)", in: Namespace().wrappedValue)
                                    .onTapGesture {
                                        if let duration = Double(chapter.duration) {
                                            toastMessage = "Duration: \(formatDuration(duration))"
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                showToast = true
                                            }

                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    showToast = false
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .padding(.bottom, 120)
                    }
                }
            }

            // Toast notification with glass effect
            if showToast {
                Text(toastMessage)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .padding(.bottom, 120)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showToast)
            }

            // Download section with enhanced glass effect
            if !isLoading, !chapters.isEmpty {
                VStack(spacing: 0) {
                    // Subtle divider
                    Rectangle()
                        .fill(.separator.opacity(0.3))
                        .frame(height: 1)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(chapters.count) Chapters")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Total Duration: \(calculateTotalDuration(chapters))")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            print("Starting download from BookDetailView")
                            downloadManager.startDownload(
                                title: bookTitle,
                                coverUrl: coverUrl,
                                chapters: chapters,
                                source: source
                            )
                            print("Download started, showing download manager")
                            showDownloadManager = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Download")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .glassEffect(.regular, in: .rect(cornerRadius: 0))
                    .background(.regularMaterial)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .task {
            do {
                chapters = try await fetchChapters(from: url)
                isLoading = false
            } catch {
                showError = true
                errorMessage = "Failed to fetch chapters: \(error.localizedDescription)"
            }
        }
        .withGitHubButton()
        .sheet(isPresented: $showDownloadManager) {
            DownloadManagerView()
        }
    }
}

struct ChapterRow: View {
    let chapter: Chapter

    var body: some View {
        HStack(spacing: 16) {
            // Chapter indicator
            Circle()
                .fill(.tertiary)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(chapter.name)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                
                if !chapter.duration.isEmpty && chapter.duration != "00:00" {
                    Label(chapter.duration, systemImage: "clock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "play.circle")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationView {
        BookDetailView(
            url: "https://tokybook.com/he-who-fights-with-monsters-11-a-litrpg-adventure",
            bookTitle: "Sample Book",
            coverUrl: nil
        )
    }
}
