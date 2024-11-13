import SwiftUI

struct AutocompleteView: View {
    let books: [OpenLibraryBook]
    let onSelect: (OpenLibraryBook) -> Void

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(books) { book in
                        OpenLibraryBookRow(book: book, isAutocomplete: true) {
                            onSelect(book)
                        }
                    }
                }
                .padding()
            }
            .background(.background)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.1), value: books)
        .transition(.opacity)
    }
}
