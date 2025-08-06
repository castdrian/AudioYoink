import SwiftUI

struct AutocompleteView: View {
    let books: [OpenLibraryBook]
    let onSelect: (OpenLibraryBook) -> Void
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                            OpenLibraryBookRow(
                                book: book, 
                                isAutocomplete: true,
                                action: { onSelect(book) },
                                onLongPress: nil
                            )
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                            .glassEffectID("autocomplete_\(index)", in: glassNamespace)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 300)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .shadow(color: .primary.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 80)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: books)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }
}
