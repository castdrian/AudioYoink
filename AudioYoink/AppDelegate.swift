import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    var backgroundCompletionHandler: (() -> Void)?
    
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        backgroundCompletionHandler = completionHandler
    }
} 