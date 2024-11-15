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
    @State private var chapters: [Chapter] = []
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showToast = false
    @State private var toastMessage = ""

    init(url: String) {
        self.url = url
        self.source = BookSource.fromURL(url)
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
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(chapters) { chapter in
                            ChapterRow(chapter: chapter)
                                .onTapGesture {
                                    if let duration = Double(chapter.duration) {
                                        toastMessage = "Duration: \(formatDuration(duration))"
                                        showToast = true

                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            showToast = false
                                        }
                                    }
                                }
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }

            if showToast {
                Text(toastMessage)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.bottom, 100)
                    .transition(.opacity)
                    .animation(.easeInOut, value: showToast)
            }

            if !isLoading, !chapters.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(chapters.count) Chapters")
                                .font(.headline)
                            Text("Total Duration: \(calculateTotalDuration(chapters))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            // Download functionality will go here
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                    }
                    .padding()
                    .background(.background)
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
    }
}

struct ChapterRow: View {
    let chapter: Chapter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chapter.name)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        BookDetailView(url: "https://tokybook.com/he-who-fights-with-monsters-11-a-litrpg-adventure")
    }
}
