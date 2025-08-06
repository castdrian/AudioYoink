import Foundation

struct SiteStatus {
    var isChecking = true
    var isReachable = false
    var latency: TimeInterval = 0
    var speed: Double = 0
    var mirrorIsChecking = true
    var mirrorIsReachable = false
    var mirrorLatency: TimeInterval = 0
    var mirrorSpeed: Double = 0
    var goldenIsChecking = true
    var goldenIsReachable = false
    var goldenLatency: TimeInterval = 0
    var goldenSpeed: Double = 0

    mutating func update(isReachable: Bool, latency: TimeInterval, speed: Double) {
        isChecking = false
        self.isReachable = isReachable
        self.latency = latency
        self.speed = speed
    }

    mutating func updateMirror(isReachable: Bool, latency: TimeInterval, speed: Double) {
        mirrorIsChecking = false
        mirrorIsReachable = isReachable
        mirrorLatency = latency
        mirrorSpeed = speed
    }
    
    mutating func updateGolden(isReachable: Bool, latency: TimeInterval, speed: Double) {
        goldenIsChecking = false
        goldenIsReachable = isReachable
        goldenLatency = latency
        goldenSpeed = speed
    }
}
