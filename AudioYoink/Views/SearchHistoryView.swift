import SwiftUI

struct SearchHistoryView: View {
    let searchHistory: [OpenLibraryBook]
    let onTap: (OpenLibraryBook) -> Void
    let onClear: () -> Void
    @State private var showingConfirmation = false
    
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
                        OpenLibraryBookRow(book: book, isAutocomplete: false) {
                            onTap(book)
                        }
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
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onClear()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to clear your search history?")
        }
    }
} 
