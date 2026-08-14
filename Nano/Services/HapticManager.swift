import Foundation
import UIKit
import CoreHaptics
import AudioToolbox

class HapticManager {
    static let shared = HapticManager()

    private var hapticEngine: CHHapticEngine?
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)

    init() {
        prepareEngine()
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
    }

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            hapticEngine?.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }
        } catch {
            print("HapticManager: CoreHaptics engine init error: \(error)")
        }
    }

    func playTap() {
        // Prepare generators
        impactMedium.prepare()
        impactMedium.impactOccurred()

        // CoreHaptics transient event
        if let engine = hapticEngine {
            do {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                print("HapticManager: CoreHaptics play error: \(error)")
            }
        }

        // Fallback AudioServices system vibration
        AudioServicesPlaySystemSound(1520)
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    func playHeavy() {
        impactHeavy.prepare()
        impactHeavy.impactOccurred()

        if let engine = hapticEngine {
            do {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                print("HapticManager: CoreHaptics play error: \(error)")
            }
        }

        AudioServicesPlaySystemSound(1521)
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    func playBurstStop() {
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) { [weak self] in
                self?.playHeavy()
            }
        }
    }
}
