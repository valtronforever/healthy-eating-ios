import SwiftUI

/// Loads one week's review and the settings it is shown with (energy unit).
@MainActor
@Observable
final class WeeklyReviewModel {
    struct Snapshot {
        var review: WeeklyReview
        var settings: UserSettings
    }

    private(set) var state: Loadable<Snapshot> = .loading

    func load(week: Date, _ data: any NutritionDataSource) async -> APIError? {
        do {
            async let review = data.weeklyReview(week: week)
            async let settings = data.settings()
            state = .loaded(Snapshot(review: try await review, settings: try await settings))
            return nil
        } catch {
            let apiError = error as? APIError ?? .unexpectedResponse(String(describing: error))
            state = .failed(apiError)
            return apiError
        }
    }
}

/// D2 Weekly review: one local week, Monday to Sunday, as facts from the backend. Averages name
/// the days they use; patterns and data quality never judge. Calm mode hides calories.
struct WeeklyReviewView: View {
    @Environment(AppModel.self) private var app
    @State private var model = WeeklyReviewModel()
    @State private var week = Calendar.current.startOfDay(for: .now)

    var body: some View {
        List {
            weekHeader.plainListRow()
            switch model.state {
            case .loading:
                LoadingCards().plainListRow()
            case .failed(let error):
                ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                    .padding(.top, Spacing.s6)
                    .plainListRow()
            case .loaded(let snapshot):
                if snapshot.review.mealCount == 0 {
                    emptyCard.plainListRow()
                } else {
                    averagesSection(snapshot)
                    if !snapshot.review.micronutrientAverages.isEmpty {
                        Section {
                            MicronutrientsLink(
                                subtitle: Self.weekTitle(first: snapshot.review.firstDay, last: snapshot.review.lastDay),
                                values: MicronutrientsView.averageValues(
                                    snapshot.review.micronutrientAverages, countedDays: snapshot.review.countedDays,
                                    ranges: snapshot.settings.micronutrientRanges),
                                footer: MicronutrientsView.periodFooter(snapshot.settings))
                        }
                        .listRowBackground(Color.surface)
                    }
                    patternsSection(snapshot)
                    dataQualitySection(snapshot.review)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Weekly review")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task(id: week) { await reload() }
    }

    private func reload() async {
        guard let data = app.data else { return }
        if let error = await model.load(week: week, data) { app.handle(error) }
    }

    // MARK: Sections

    private var weekHeader: some View {
        let review = model.state.value?.review
        let isThisWeek = review.map { $0.lastDay >= Calendar.current.startOfDay(for: .now) } ?? true
        return HStack(spacing: Spacing.s4) {
            Text(verbatim: review.map { Self.weekTitle(first: $0.firstDay, last: $0.lastDay) } ?? " ")
                .font(.title2.bold())
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.s2)
            Button { moveWeek(by: -7) } label: {
                Image(systemName: "chevron.left").frame(minWidth: Spacing.tapTarget, minHeight: Spacing.tapTarget)
            }
            .accessibilityLabel("Previous week")
            .accessibilityIdentifier("previousWeek")
            Button { moveWeek(by: 7) } label: {
                Image(systemName: "chevron.right").frame(minWidth: Spacing.tapTarget, minHeight: Spacing.tapTarget)
            }
            .disabled(isThisWeek)
            .accessibilityLabel("Next week")
            .accessibilityIdentifier("nextWeek")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.accent)
    }

    private func moveWeek(by days: Int) {
        week = Calendar.current.date(byAdding: .day, value: days, to: week) ?? week
    }

    private var emptyCard: some View {
        VStack(spacing: Spacing.s1) {
            Text("No meals this week")
                .font(.headline)
                .foregroundStyle(.ink)
            Text("The review fills in as meals arrive from your assistant.")
                .foregroundStyle(.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: Spacing.s5)
    }

    private func averagesSection(_ snapshot: WeeklyReviewModel.Snapshot) -> some View {
        let review = snapshot.review
        let averages = review.averages
        return Section {
            row("Days logged", Self.daysLine(review))
            if !app.calmMode {
                row("Calories", averages.map { NutritionFormat.energy($0.caloriesKcal, in: snapshot.settings.energyUnit) } ?? "–")
            }
            row(Macro.protein.name, grams(averages?.proteinG))
            row(Macro.fat.name, grams(averages?.fatG))
            row(Macro.carbs.name, grams(averages?.carbohydratesG))
        } header: {
            Text("Averages").sectionTextStyle()
        } footer: {
            Text(verbatim: Self.averagesFootnote(review)).sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }

    private func patternsSection(_ snapshot: WeeklyReviewModel.Snapshot) -> some View {
        let review = snapshot.review
        return Section {
            fact("Protein per meal", Self.proteinLine(review))
            fact("Weekdays and weekend", Self.weekdaysLine(review, unit: snapshot.settings.energyUnit, calm: app.calmMode))
            fact("Late meals", Self.lateLine(review))
        } header: {
            Text("Patterns").sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }

    private func dataQualitySection(_ review: WeeklyReview) -> some View {
        Section {
            if let share = review.estimatedValuesShare {
                ProvenanceShareBar(estimatedShare: share)
                    .padding(.vertical, Spacing.s2)
            }
            row("Low-confidence estimates", Self.mealsCount(review.lowConfidenceMeals))
        } header: {
            Text("Data quality").sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent {
            Text(verbatim: value).foregroundStyle(.inkMuted)
        } label: {
            Text(label).foregroundStyle(.ink)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent {
            Text(verbatim: value).foregroundStyle(.inkMuted)
        } label: {
            Text(verbatim: label).foregroundStyle(.ink)
        }
    }

    private func fact(_ title: LocalizedStringKey, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(.ink)
            Text(verbatim: line).font(.subheadline).foregroundStyle(.inkMuted)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func grams(_ value: Double?) -> String {
        value.map { NutritionFormat.value($0, .grams) } ?? "–"
    }

    // MARK: Wording (facts with their days; never good, bad, over or under)

    /// "Oct 12–18" ("12–18 Oct" where the day comes first), "Sep 28–Oct 4" across months: the
    /// locale's order, with an en dash and no spaces (design/system/content.md).
    nonisolated static func weekTitle(first: Date, last: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateTemplate = "MMMd"
        let text = formatter.string(from: first, to: last)
        return text.replacingOccurrences(of: "\\s*[–-]\\s*", with: "–", options: .regularExpression)
    }

    nonisolated static func daysLine(_ review: WeeklyReview) -> String {
        switch review.countingRule {
        case .completeDays: String(localized: "\(review.loggedDays) of 7 · \(review.completeDays) complete")
        case .loggedDays: String(localized: "\(review.loggedDays) of 7")
        }
    }

    /// Names the days the averages use and why the others are left out.
    nonisolated static func averagesFootnote(_ review: WeeklyReview, calendar: Calendar = .current, locale: Locale = .current) -> String {
        var sentences: [String] = []
        let counted = review.countedDays
        if counted == 0 {
            sentences.append(String(localized: "No day counts for the averages yet."))
        } else {
            switch review.countingRule {
            case .completeDays:
                sentences.append(counted == 1
                    ? String(localized: "Averages use the 1 complete day.")
                    : String(localized: "Averages use the \(counted) complete days."))
            case .loggedDays: sentences.append(String(localized: "Averages use \(counted) of 7 days."))
            }
        }
        let reasons = Dictionary(grouping: review.leftOut, by: \.reason)
        func names(_ reason: WeeklyReview.LeftOutReason) -> (text: String, count: Int)? {
            guard let days = reasons[reason], !days.isEmpty else { return nil }
            let weekday = DateFormatter()
            weekday.locale = locale
            weekday.calendar = calendar
            weekday.timeZone = calendar.timeZone
            weekday.setLocalizedDateFormatFromTemplate("EEEE")
            let list = ListFormatter.localizedString(byJoining: days.map { weekday.string(from: $0.date) })
            return (list, days.count)
        }
        if reasons[.inProgress] != nil {
            sentences.append(String(localized: "Today is still in progress."))
        }
        if let (list, count) = names(.notLogged) {
            sentences.append(count == 1 ? String(localized: "\(list) was not logged.") : String(localized: "\(list) were not logged."))
        }
        if let (list, count) = names(.partial) {
            sentences.append(count == 1 ? String(localized: "\(list) was marked partial.") : String(localized: "\(list) were marked partial."))
        }
        if let (list, count) = names(.notMarkedComplete) {
            sentences.append(count == 1
                ? String(localized: "\(list) was not marked complete.")
                : String(localized: "\(list) were not marked complete."))
        }
        if reasons[.future] != nil {
            sentences.append(String(localized: "The rest of the week is still ahead."))
        }
        return sentences.joined(separator: " ")
    }

    nonisolated static func proteinLine(_ review: WeeklyReview, locale: Locale = .current) -> String {
        guard let protein = review.proteinPerMealG else { return String(localized: "No meals this week") }
        return String(localized: "\(NutritionFormat.value(protein, .grams, locale: locale)) on average across \(review.mealCount) meals")
    }

    nonisolated static func weekdaysLine(_ review: WeeklyReview, unit: EnergyUnit, calm: Bool, locale: Locale = .current) -> String {
        guard let weekdays = review.weekdays.averages, let weekend = review.weekend.averages else {
            return String(localized: "Shown once both weekdays and the weekend have counted days")
        }
        if calm {
            let onWeekdays = NutritionFormat.value(weekdays.proteinG, .grams, locale: locale)
            let onWeekend = NutritionFormat.value(weekend.proteinG, .grams, locale: locale)
            return String(localized: "\(onWeekdays) protein on weekdays, \(onWeekend) on the weekend")
        }
        let onWeekdays = NutritionFormat.energy(weekdays.caloriesKcal, in: unit, locale: locale)
        let onWeekend = NutritionFormat.number(unit.amount(fromKcal: weekend.caloriesKcal), locale: locale)
        return String(localized: "\(onWeekdays) on weekdays, \(onWeekend) on the weekend")
    }

    nonisolated static func lateLine(_ review: WeeklyReview, calendar: Calendar = .current) -> String {
        let nine = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: .now) ?? .now
        let time = nine.formatted(date: .omitted, time: .shortened)
        return String(localized: "\(review.lateMeals) of \(review.mealCount) meals after \(time)")
    }

    nonisolated static func mealsCount(_ count: Int) -> String {
        count == 1 ? String(localized: "1 meal") : String(localized: "\(count) meals")
    }
}

/// "Where values came from": the share of the week's values that were the person's own numbers
/// and the share the assistant estimated, with the fixed provenance words.
struct ProvenanceShareBar: View {
    let estimatedShare: Double
    @ScaledMetric(relativeTo: .body) private var barHeight: CGFloat = 10
    @ScaledMetric(relativeTo: .footnote) private var swatch: CGFloat = 10

    private var estimatedPercent: Int { Int((min(max(estimatedShare, 0), 1) * 100).rounded()) }
    private var ownPercent: Int { 100 - estimatedPercent }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Where values came from").foregroundStyle(.ink)
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Rectangle().fill(Color.accent).frame(width: proxy.size.width * Double(ownPercent) / 100)
                    Rectangle().fill(Color.chartFaded)
                }
            }
            .frame(height: barHeight)
            .clipShape(RoundedRectangle(cornerRadius: Radius.full, style: .continuous))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s4) { legend }
                VStack(alignment: .leading, spacing: Spacing.s1) { legend }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Where values came from")
        .accessibilityValue("Your numbers \(ownPercent) percent, estimated \(estimatedPercent) percent")
    }

    @ViewBuilder
    private var legend: some View {
        legendItem(Color.accent, "Your numbers \(ownPercent)%")
        legendItem(Color.chartFaded, "Estimated \(estimatedPercent)%")
    }

    private func legendItem(_ color: Color, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.s2) {
            RoundedRectangle(cornerRadius: Radius.xs, style: .continuous).fill(color).frame(width: swatch, height: swatch)
            Text(text).font(.footnote).foregroundStyle(.inkMuted)
        }
    }
}

#Preview("Light") {
    NavigationStack { WeeklyReviewView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { WeeklyReviewView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { WeeklyReviewView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
