import Testing
import UIKit
@testable import HealthyEating

/// Checks the generated color sets: every token resolves in both appearances, and the text pairs
/// the design system names hold WCAG AA (4.5:1 for text, 3:1 for marks and boundaries).
struct DesignTokenTests {
    static let tokenNames = [
        "bg", "surface", "surface-sunken", "line", "line-strong", "ink", "ink-muted", "accent", "on-accent",
        "accent-soft", "band", "protein", "fat", "carbs", "destructive", "chart-faded", "link",
    ]

    private static func color(_ name: String, _ style: UIUserInterfaceStyle) throws -> UIColor {
        let color = try #require(UIColor(named: name, in: .main, compatibleWith: nil), "missing color set \(name)")
        return color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    private static func luminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private static func contrast(_ a: String, on b: String, _ style: UIUserInterfaceStyle) throws -> Double {
        let la = luminance(try color(a, style)), lb = luminance(try color(b, style))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test(arguments: tokenNames)
    func tokenResolvesInBothAppearances(_ name: String) throws {
        let light = try Self.color(name, .light)
        let dark = try Self.color(name, .dark)
        #expect(light != dark, "\(name) has distinct light and dark values")
    }

    @Test func linkIsAnAliasOfAccent() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            #expect(try Self.color("link", style) == Self.color("accent", style))
        }
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func textPairsMeetAA(_ style: UIUserInterfaceStyle) throws {
        for text in ["ink", "ink-muted"] {
            for background in ["bg", "surface", "surface-sunken"] {
                let ratio = try Self.contrast(text, on: background, style)
                #expect(ratio >= 4.5, "\(text) on \(background): \(ratio)")
            }
        }
        for background in ["bg", "surface", "accent-soft"] {
            #expect(try Self.contrast("accent", on: background, style) >= 4.5)
        }
        #expect(try Self.contrast("on-accent", on: "accent", style) >= 4.5)
        #expect(try Self.contrast("destructive", on: "surface", style) >= 4.5)
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func boundariesAndMarksMeetThreeToOne(_ style: UIUserInterfaceStyle) throws {
        for background in ["bg", "surface"] {
            #expect(try Self.contrast("line-strong", on: background, style) >= 3)
            for mark in ["accent", "protein", "fat", "carbs"] {
                #expect(try Self.contrast(mark, on: background, style) >= 3, "\(mark) on \(background)")
            }
        }
    }
}
