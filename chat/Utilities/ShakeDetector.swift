//
//  ShakeDetector.swift
//  chat
//
//  Detects device shake gestures for triggering debug menu
//

import SwiftUI
import UIKit

#if DEBUG

// Notification posted when device is shaken
extension NSNotification.Name {
    static let deviceDidShake = NSNotification.Name("deviceDidShake")
}

// UIWindow extension to detect shake motion
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

// SwiftUI view modifier to handle shake gesture
struct ShakeGestureModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                action()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeGestureModifier(action: action))
    }
}

#endif
