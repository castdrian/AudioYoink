import SwiftUI
import Defaults

struct SearchToolbar: ViewModifier {
    @Binding var searchText: String
    @Binding var externalFocus: Bool
    @FocusState private var internalFocus: Bool
    @StateObject private var autocompleteManager = AutocompleteManager()
    @Default(.searchHistory) private var searchHistory
    let onClear: () -> Void
    let onSubmit: () -> Void
    let showDownloadManager: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            if internalFocus && !searchText.isEmpty && !autocompleteManager.results.isEmpty {
                AutocompleteView(books: autocompleteManager.results) { book in
                    searchText = book.title
                    internalFocus = false
                    externalFocus = false
                    autocompleteManager.clearResults()
                    
                    if !searchHistory.contains(where: { $0.id == book.id }) {
                        searchHistory.insert(book, at: 0)
                        if searchHistory.count > 10 {
                            searchHistory.removeLast()
                        }
                    }
                    
                    onSubmit()
                }
                .zIndex(1)
            }
            
            VStack(spacing: 0) {
                content
                    .padding(.bottom, 8)
                
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("Search audiobooks...", text: $searchText)
                            .textFieldStyle(.plain)
                            .submitLabel(.search)
                            .onSubmit {
                                autocompleteManager.clearResults()
                                onSubmit()
                            }
                            .focused($internalFocus)

                        if !searchText.isEmpty {
                            if autocompleteManager.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            } else {
                                Button(action: {
                                    withAnimation {
                                        searchText = ""
                                        autocompleteManager.clearResults()
                                        onClear()
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray3), lineWidth: 1)
                    )
                    .cornerRadius(10)

                    Button(action: showDownloadManager) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .onChange(of: searchText) { _, newValue in
            if !internalFocus {
                autocompleteManager.clearResults()
                return
            }

            if newValue.isEmpty {
                autocompleteManager.clearResults()
                return
            }

            if newValue.count < 2 {
                autocompleteManager.clearResults()
                return
            }

            autocompleteManager.search(query: newValue)
        }
        .onChange(of: internalFocus) { _, newValue in
            externalFocus = newValue
            if !newValue {
                autocompleteManager.clearResults()
            }
        }
        .onChange(of: externalFocus) { _, newValue in
            internalFocus = newValue
        }
        .onAppear {
            if searchText.isEmpty {
                autocompleteManager.clearResults()
            }
        }
    }
}

extension View {
    func withSearchToolbar(
        searchText: Binding<String>,
        externalFocus: Binding<Bool>,
        onClear: @escaping () -> Void,
        onSubmit: @escaping () -> Void,
        showDownloadManager: @escaping () -> Void
    ) -> some View {
        modifier(SearchToolbar(
            searchText: searchText,
            externalFocus: externalFocus,
            onClear: onClear,
            onSubmit: onSubmit,
            showDownloadManager: showDownloadManager
        ))
    }
} 
