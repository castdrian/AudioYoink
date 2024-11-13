import UIKit

enum KeyboardPreloader {
    static func preloadKeyboard(onNextRunloop: Bool = false) {
        UIResponder.cacheKeyboard(onNextRunloop)
    }
}
