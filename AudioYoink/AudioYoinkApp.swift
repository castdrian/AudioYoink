//
//  AudioYoinkApp.swift
//  AudioYoink
//
//  Created by Adrian Castro on 12/11/24.
//

import SwiftUI

@main
struct AudioYoinkApp: App {
    init() {
        KeyboardPreloader.preloadKeyboard()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
