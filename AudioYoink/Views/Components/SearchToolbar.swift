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
    @Namespace private var glassNamespace
    
    func body(content: Content) -> some View {
        ZStack {
            if internalFocus && !searchText.isEmpty && !autocompleteManager.results.isEmpty {
                AutocompleteView(books: autocompleteManager.results) { book in
                    searchText = book.title
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        internalFocus = false
                        externalFocus = false
                    }
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
                    .padding(.bottom, 16)
                
                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 16) {
                        HStack(spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 18, weight: .medium))

                                TextField("Search audiobooks...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .submitLabel(.search)
                                    .font(.system(size: 16, weight: .medium))
                                    .onSubmit {
                                        autocompleteManager.clearResults()
                                        onSubmit()
                                    }
                                    .focused($internalFocus)

                                if !searchText.isEmpty {
                                    if autocompleteManager.isLoading {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.secondary)
                                            .scaleEffect(0.8)
                                    } else {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                searchText = ""
                                                autocompleteManager.clearResults()
                                                onClear()
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                                .font(.system(size: 18, weight: .medium))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .frame(height: 52)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
                            .glassEffectID("searchField", in: glassNamespace)

                            // Download manager button
                            Button(action: showDownloadManager) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                            .frame(width: 52, height: 52)
                            .glassEffect(.regular.interactive(), in: .circle)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 16)
                } else {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 18, weight: .medium))

                                TextField("Search audiobooks...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .submitLabel(.search)
                                    .font(.system(size: 16, weight: .medium))
                                    .onSubmit {
                                        autocompleteManager.clearResults()
                                        onSubmit()
                                    }
                                    .focused($internalFocus)

                                if !searchText.isEmpty {
                                    if autocompleteManager.isLoading {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.secondary)
                                            .scaleEffect(0.8)
                                    } else {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                searchText = ""
                                                autocompleteManager.clearResults()
                                                onClear()
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                                .font(.system(size: 18, weight: .medium))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .frame(height: 52)
                            .background(
                                Group {
                                    if #available(iOS 26.0, *) {
                                        Color.clear
                                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
                                            .glassEffectID("searchField", in: glassNamespace)
                                    }
                                }
                            )

                            // Download manager button
                            Button(action: showDownloadManager) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                            .frame(width: 52, height: 52)
                            .background(
                                Group {
                                    if #available(iOS 26.0, *) {
                                        Color.clear.glassEffect(.regular.interactive(), in: .circle)
                                    }
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 16)
                }
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

            autocompleteManager.search(query: newValue)
        }
        .onChange(of: internalFocus) { _, focused in
            externalFocus = focused
        }
        .onChange(of: externalFocus) { _, focused in
            internalFocus = focused
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
