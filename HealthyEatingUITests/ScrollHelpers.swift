import XCTest

extension XCUIApplication {
    /// Swipes up until `element` is on screen and clear of the floating tab bar, which covers the
    /// bottom rows. Each check is one snapshot: on CI runners every element query takes seconds,
    /// so checking `exists`, `isHittable` and `frame` separately on each pass adds up to minutes.
    /// After a swipe it also waits until the element stops moving: a tap while the list still
    /// glides only stops it (CI run 40192761719).
    @discardableResult
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        let bar = tabBars.firstMatch
        let bottom = (try? bar.snapshot().frame.minY) ?? (try? windows.firstMatch.snapshot().frame.maxY) ?? .greatestFiniteMagnitude
        var swipes = 0
        var settleChecks = 0
        var previous: CGRect?
        while true {
            if let frame = try? element.snapshot().frame, !frame.isEmpty, frame.minY > 0, frame.maxY < bottom - 20 {
                if swipes == 0 || frame == previous || settleChecks >= 10 { return true }
                previous = frame
                settleChecks += 1
                Thread.sleep(forTimeInterval: 0.3)
                continue
            }
            previous = nil
            guard swipes < maxSwipes else { break }
            swipeUp()
            swipes += 1
        }
        // The last rows of a list may never clear the tab bar; tapping them can still work.
        return element.isHittable
    }
}
