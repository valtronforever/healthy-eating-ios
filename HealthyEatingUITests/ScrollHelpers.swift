import XCTest

extension XCUIApplication {
    /// Swipes up until `element` is on screen and clear of the floating tab bar, which covers the
    /// bottom rows. Each check is one snapshot: on CI runners every element query takes seconds,
    /// so checking `exists`, `isHittable` and `frame` separately on each pass adds up to minutes.
    @discardableResult
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        let bar = tabBars.firstMatch
        let bottom = (try? bar.snapshot().frame.minY) ?? (try? windows.firstMatch.snapshot().frame.maxY) ?? .greatestFiniteMagnitude
        for attempt in 0...maxSwipes {
            if let frame = try? element.snapshot().frame, !frame.isEmpty, frame.minY > 0, frame.maxY < bottom - 20 {
                return true
            }
            if attempt < maxSwipes { swipeUp() }
        }
        // The last rows of a list may never clear the tab bar; tapping them can still work.
        return element.isHittable
    }
}
