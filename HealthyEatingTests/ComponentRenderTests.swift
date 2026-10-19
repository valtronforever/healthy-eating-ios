import SwiftUI
import Testing
@testable import HealthyEating

/// Renders every design system component in light, dark and AX5, the same variants as the
/// #Preview blocks, and checks that each produces an image. PNGs are written to
/// `<tmp>/HealthyEatingRenders` for visual review (the path is printed).
@MainActor
struct ComponentRenderTests {
    enum Variant: String, CaseIterable {
        case light, dark, ax5
    }

    static let components: [(String, AnyView)] = [
        ("ProvenanceBadge", AnyView(ProvenanceBadgeGallery())),
        ("ConfidenceIndicator", AnyView(ConfidenceIndicatorGallery())),
        ("RangeBand", AnyView(RangeBandGallery())),
        ("SummaryCard", AnyView(SummaryCardGallery())),
        ("MealRow", AnyView(VStack(spacing: Spacing.s3) {
            ForEach(SampleData.meals) { MealRow(meal: $0) }
        }.cardStyle())),
        ("IntegrationStatus", AnyView(IntegrationStatusGallery())),
        ("CalendarDay", AnyView(CalendarDayGallery())),
        ("KcalBarChart", AnyView(KcalBarChartGallery())),
        ("WeightTrendChart", AnyView(WeightTrendChartGallery())),
        ("CopyField", AnyView(CopyFieldGallery())),
        ("Banner", AnyView(BannerGallery())),
        ("Skeleton", AnyView(SkeletonGallery())),
        ("StateMessage", AnyView(StateMessageGallery())),
    ]

    static var outputDirectory: URL {
        FileManager.default.temporaryDirectory.appending(path: "HealthyEatingRenders", directoryHint: .isDirectory)
    }

    @Test(arguments: Variant.allCases)
    func componentsRender(_ variant: Variant) throws {
        try FileManager.default.createDirectory(at: Self.outputDirectory, withIntermediateDirectories: true)
        for (name, view) in Self.components {
            let content = view
                .previewCard()
                .frame(width: 393)
                .environment(\.colorScheme, variant == .dark ? .dark : .light)
                .environment(\.dynamicTypeSize, variant == .ax5 ? .accessibility5 : .large)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try #require(renderer.uiImage, "\(name) did not render in \(variant)")
            #expect(image.size.width >= 393 && image.size.height > 40, "\(name) \(variant) rendered at \(image.size)")
            let data = try #require(image.pngData())
            try data.write(to: Self.outputDirectory.appending(path: "\(name)-\(variant.rawValue).png"))
        }
        print("Component renders: \(Self.outputDirectory.path())")
    }
}

@MainActor
struct CopyFieldTests {
    @Test func breakableOnlyAddsZeroWidthSpaces() {
        let url = "https://food.example.com/mcp"
        let display = CopyField.breakable(url)
        #expect(display != url)
        #expect(display.replacingOccurrences(of: "\u{200B}", with: "") == url)
        #expect(!display.contains("-"))
    }
}
