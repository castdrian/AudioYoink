import Awesome
import SafariUI
import SwiftUI

struct ToolbarButtonsModifier: ViewModifier {
    @State private var showGitHub = false
    @State private var showDonate = false
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showGitHub = true }) {
                            Awesome.Brand.github.image
                                .size(24)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.regularMaterial)
                        )
                        .clipShape(Circle())
                        
                        Button(action: { showDonate = true }) {
                            Image(systemName: "heart.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
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
            }
            .sheet(isPresented: $showGitHub) {
                SafariView(url: URL(string: "https://github.com/castdrian/AudioYoink")!)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showDonate) {
                SafariView(url: URL(string: "https://ko-fi.com/castdrian")!)
                    .ignoresSafeArea()
            }
    }
}

extension View {
    func withToolbarButtons() -> some View {
        modifier(ToolbarButtonsModifier())
    }
}
