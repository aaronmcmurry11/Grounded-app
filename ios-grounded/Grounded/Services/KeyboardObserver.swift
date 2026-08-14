import SwiftUI
import UIKit
import Observation

/// Publishes the real keyboard geometry so views can position pinned content from
/// the measured overlap instead of guessing from focus state (focus flips instantly;
/// the keyboard takes ~250ms to arrive, so the two are not interchangeable).
@Observable
final class KeyboardObserver {
    /// How far the keyboard covers the screen *above* the bottom safe area.
    /// Zero whenever the keyboard is down.
    var overlap: CGFloat = 0

    var isVisible: Bool { overlap > 0 }

    init() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIResponder.keyboardWillShowNotification,
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardWillHideNotification,
        ]

        for name in names {
            // queue: .main guarantees the block runs on the main thread, so reading
            // UIKit geometry inside assumeIsolated is safe.
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let isHiding = name == UIResponder.keyboardWillHideNotification
                MainActor.assumeIsolated {
                    self?.update(from: note, isHiding: isHiding)
                }
            }
        }
    }

    private func update(from note: Notification, isHiding: Bool) {
        let info = note.userInfo
        let duration = (info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25

        var newOverlap: CGFloat = 0
        if !isHiding,
           let endFrame = info?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
           let window = Self.activeWindow {
            let converted = window.convert(endFrame, from: nil)
            let covered = window.bounds.intersection(converted).height
            newOverlap = max(0, covered - window.safeAreaInsets.bottom)
        }

        guard newOverlap != overlap else { return }
        withAnimation(.easeOut(duration: max(duration, 0.15))) {
            overlap = newOverlap
        }
    }

    private static var activeWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
