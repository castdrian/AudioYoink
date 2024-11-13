import Kingfisher
import SwiftUI

struct OpenLibraryBookRow: View {
    let book: OpenLibraryBook
    let isAutocomplete: Bool
    let action: () -> Void

    let genreColors: [Color] = [.blue, .green, .orange, .purple, .pink]

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let coverUrl = book.coverUrl {
                    KFImage(coverUrl)
                        .placeholder {
                            Color.gray.opacity(0.3)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Color.gray.opacity(0.3)
                        .frame(width: 40, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(2)

                    HStack {
                        Text(book.author)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        if book.year > 0 {
                            Text("(\(String(book.year)))")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    if !book.publisher.isEmpty {
                        Text(book.publisher)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if !book.genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(book.genres.prefix(3)), id: \.self) { genre in
                                    Text(genre)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            genreColors[abs(genre.hashValue) % genreColors.count]
                                                .opacity(0.2)
                                        )
                                        .foregroundColor(
                                            genreColors[abs(genre.hashValue) % genreColors.count]
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 16)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isAutocomplete ? Color(.systemGray6) : Color(.systemBackground))
            .cornerRadius(8)
        }
    }
}
