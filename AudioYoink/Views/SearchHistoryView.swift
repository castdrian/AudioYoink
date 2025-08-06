import SwiftUI

struct SearchHistoryView: View {
    let searchHistory: [OpenLibraryBook]
    let onTap: (OpenLibraryBook) -> Void
    let onClear: () -> Void
    let onDelete: (OpenLibraryBook) -> Void
    @State private var showingConfirmation = false
    @State private var bookToDelete: OpenLibraryBook?
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with glass effect
                HStack {
                    Text("Recent Searches")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button {
                        showingConfirmation = true
                    } label: {
                        Text("Clear")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    .glassEffectID("clearButton", in: glassNamespace)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .glassEffectID("historyHeader", in: glassNamespace)

                // Search history items
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(searchHistory.enumerated()), id: \.element.id) { index, book in
                            OpenLibraryBookRow(
                                book: book, 
                                isAutocomplete: false,
                                action: { onTap(book) },
                                onLongPress: { bookToDelete = book }
                            )
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                            .glassEffectID("history_\(index)", in: glassNamespace)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .leading)),
                                removal: .scale(scale: 0.95).combined(with: .opacity).combined(with: .move(edge: .trailing))
                            ))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 280)
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 20)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .move(edge: .top)),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: searchHistory)
        .confirmationDialog("Clear Search History",
                            isPresented: $showingConfirmation,
                            titleVisibility: .visible)
        {
            Button("Clear", role: .destructive) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
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
