import UIKit

final class KeyboardPreloader {
    static func preloadKeyboard(onNextRunloop: Bool = false) {
        UIResponder.cacheKeyboard(onNextRunloop)
    }
} 