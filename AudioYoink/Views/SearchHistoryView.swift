import SwiftUI

struct SearchHistoryView: View {
    let searchHistory: [OpenLibraryBook]
    let onTap: (OpenLibraryBook) -> Void
    let onClear: () -> Void
    let onDelete: (OpenLibraryBook) -> Void
    @State private var showingConfirmation = false
    @State private var bookToDelete: OpenLibraryBook?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Searches")
                    .font(.headline)
                Spacer()
                Button {
                    showingConfirmation = true
                } label: {
                    Text("Clear")
                        .foregroundColor(.secondary)
                }
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(searchHistory) { book in
                        OpenLibraryBookRow(
                            book: book, 
                            isAutocomplete: false,
                            action: { onTap(book) },
                            onLongPress: { bookToDelete = book }
                        )
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.3), value: searchHistory)
        .confirmationDialog("Clear Search History",
                            isPresented: $showingConfirmation,
                            titleVisibility: .visible)
        {
            Button("Clear", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onClear()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear your search history?")
        }
        .confirmationDialog("Delete Item",
                          isPresented: .init(
                            get: { bookToDelete != nil },
                            set: { if !$0 { bookToDelete = nil } }
                          ),
                          titleVisibility: .visible)
        {
            Button("Delete", role: .destructive) {
                if let book = bookToDelete {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onDelete(book)
                    }
                }
                bookToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                bookToDelete = nil
            }
        } message: {
            if let book = bookToDelete {
                Text("Delete '\(book.title)' from search history?")
            }
        }
    }
}
