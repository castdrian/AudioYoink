import Foundation

struct SiteStatus {
    var isChecking = true
    var isReachable = false
    var latency: TimeInterval = 0
    var speed: Double = 0
    
    mutating func update(isReachable: Bool, latency: TimeInterval, speed: Double) {
        self.isChecking = false
        self.isReachable = isReachable
        self.latency = latency
        self.speed = speed
    }
}
