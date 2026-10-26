import XCTest

extension XCUIApplication {
    /// Scrolls until `element` is on screen between the navigation bar and the floating tab bar,
    /// which covers the bottom rows. Each check is one snapshot: on CI runners every element
    /// query takes seconds, so checking `exists`, `isHittable` and `frame` separately on each pass
    /// adds up to minutes.
    ///
    /// Far away, it swipes up. Once the element is on screen but under the tab bar (or above,
    /// under the navigation bar), it drags slowly by about a third of the screen: a full swipe
    /// could carry a row from under the tab bar to under the navigation bar, where a tap misses
    /// (CI run 40316570722). After moving it waits until the element stops: a tap while the list
    /// still glides only stops it (CI run 40192761719).
    @discardableResult
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        let window = (try? windows.firstMatch.snapshot().frame) ?? .zero
        let bottom = (try? tabBars.firstMatch.snapshot().frame.minY) ?? window.maxY
        var swipes = 0
        var nudges = 0
        var settleChecks = 0
        var moved = false
        var previous: CGRect?
        while true {
            // The navigation bar shrinks while scrolling, so it is read on every pass.
            let top = (try? navigationBars.firstMatch.snapshot().frame.maxY) ?? window.minY
            let frame = (try? element.snapshot().frame).flatMap { $0.isEmpty ? nil : $0 }
            if let frame, frame.minY > top + 8, frame.maxY < bottom - 20 {
                if !moved || frame == previous || settleChecks >= 10 { return true }
                previous = frame
                settleChecks += 1
                Thread.sleep(forTimeInterval: 0.3)
                continue
            }
            previous = nil
            settleChecks = 0
            moved = true
            if let frame, frame.minY < window.maxY, nudges < 6 {
                // On screen but covered: a slow drag, up or down.
                nudge(up: frame.minY > top + 8)
                nudges += 1
            } else {
                guard swipes < maxSwipes else { break }
                swipeUp()
                swipes += 1
            }
        }
        // The last rows of a list may never clear the tab bar; tapping them can still work.
        return element.isHittable
    }

    /// Drags the content by about a third of the screen, slowly, so it does not glide on.
    private func nudge(up: Bool) {
        let window = windows.firstMatch
        let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.65 : 0.35))
        let to = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.35 : 0.65))
        from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
    }
}
