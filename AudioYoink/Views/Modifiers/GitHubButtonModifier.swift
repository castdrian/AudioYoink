import Awesome
import SafariUI
import SwiftUI

struct GitHubButtonModifier: ViewModifier {
    @State private var showGitHub = false
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showGitHub = true }) {
                        Awesome.Brand.github.image
                            .size(40)
                            .foregroundColor(.label)
                    }
                    .offset(x: 8)
                }
            }
            .sheet(isPresented: $showGitHub) {
                SafariView(url: URL(string: "https://github.com/castdrian/AudioYoink")!)
                    .ignoresSafeArea()
            }
    }
}

extension View {
    func withGitHubButton() -> some View {
        modifier(GitHubButtonModifier())
    }
} 