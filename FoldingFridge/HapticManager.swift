import AudioToolbox
import UIKit

enum HapticManager {
    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.82)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func sheet() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.95)
    }

    static func onboardingCommit() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }

    static func captureSound() {
        AudioServicesPlaySystemSound(1108)
    }
}
