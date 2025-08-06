import Kingfisher
import SwiftUI

struct LongPressButtonStyle: ButtonStyle {
    let onLongPress: (() -> Void)?
    @State private var longPressTask: Task<Void, Never>?
    @State private var didLongPress = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    didLongPress = false
                    longPressTask = Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        if !Task.isCancelled {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            didLongPress = true
                            onLongPress?()
                        }
                    }
                } else {
                    longPressTask?.cancel()
                    longPressTask = nil
                }
            }
            .disabled(didLongPress)
            .onChange(of: didLongPress) { _, _ in
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    didLongPress = false
                }
            }
    }
}

struct OpenLibraryBookRow: View {
    let book: OpenLibraryBook
    let isAutocomplete: Bool
    let action: () -> Void
    let onLongPress: (() -> Void)?
    
    let genreColors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .mint, .indigo]

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Enhanced book cover with shadow
                Group {
                    if let coverUrl = book.coverUrl {
                        KFImage(coverUrl)
                            .placeholder {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.tertiary)
                                    .overlay {
                                        Image(systemName: "book.closed")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.secondary)
                                    }
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .primary.opacity(0.1), radius: 4, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.tertiary)
                            .frame(width: 48, height: 72)
                            .overlay {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)
                            }
                            .shadow(color: .primary.opacity(0.1), radius: 4, y: 2)
                    }
                }

                // Enhanced content layout
                VStack(alignment: .leading, spacing: 8) {
                    Text(book.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Text(book.author)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)

                        if book.year > 0 {
                            Text("(\(String(book.year)))")
                                .font(.system(size: 15))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if !book.publisher.isEmpty {
                        Text(book.publisher)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    // Enhanced genre tags with glass effect
                    if !book.genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(book.genres.prefix(3)), id: \.self) { genre in
                                    Text(genre)
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background {
                                            Capsule()
                                                .fill(genreColors[abs(genre.hashValue) % genreColors.count].opacity(0.15))
                                                .overlay {
                                                    Capsule()
                                                        .stroke(genreColors[abs(genre.hashValue) % genreColors.count].opacity(0.3), lineWidth: 1)
                                                }
                                        }
                                        .foregroundStyle(genreColors[abs(genre.hashValue) % genreColors.count])
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 12)
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(LongPressButtonStyle(onLongPress: onLongPress))
    }
}
