/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Simple wrapper for UI audio effects.
用于UI音频效果的简单包装器。
*/

import AVFoundation

class ButtonBeep {
    private let player: AVAudioPlayer
    static var players = [String: AVAudioPlayer]()
    var volume: Float

    init?(name: String, volume: Float) {
        self.volume = volume
        if let player = ButtonBeep.players[name] {
            self.player = player
        } else {
            do {
                guard let url = Bundle.main.url(forResource: "Sounds/\(name)", withExtension: nil) else {
                    return nil
                }
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                self.player = player
                ButtonBeep.players[name] = player
            } catch {
                return nil
            }
        }
    }

    func play() {
        player.volume = volume * SFXCoordinator.effectsGain()
        player.play()
    }
}
