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
                            .size(24)
                            .foregroundStyle(.primary)
                    }
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.regularMaterial)
                    )
                    .clipShape(Circle())
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