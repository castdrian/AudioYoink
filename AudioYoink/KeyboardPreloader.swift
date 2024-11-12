import UIKit

final class KeyboardPreloader {
    static func preloadKeyboard() {
        let dummyTextField = UITextField()
        UIApplication.shared.windows.first?.addSubview(dummyTextField)
        dummyTextField.becomeFirstResponder()
        dummyTextField.resignFirstResponder()
        dummyTextField.removeFromSuperview()
    }
} 