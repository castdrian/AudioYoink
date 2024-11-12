//
//  AudioYoinkApp.swift
//  AudioYoink
//
//  Created by Adrian Castro on 12/11/24.
//

import SwiftUI
import Kingfisher

@main
struct AudioYoinkApp: App {
    init() {
        KeyboardPreloader.preloadKeyboard(onNextRunloop: true)
        
        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 300 * 1024 * 1024
        cache.diskStorage.config.sizeLimit = 1000 * 1024 * 1024
        
        KingfisherManager.shared.defaultOptions = [
            .cacheOriginalImage,
            .backgroundDecode,
            .scaleFactor(UIScreen.main.scale),
            .keepCurrentImageWhileLoading
        ]
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
