import Foundation

/// The design boards' sample data behind `NutritionDataSource`, kept in memory so edits,
/// deletes and day marks behave like the real server. Used with `-skipOnboarding` (UI tests,
/// screenshots) and in previews. Contains no logic the backend owns beyond simple sums.
actor SampleDataSource: NutritionDataSource {
    private var todayMeals: [Meal] = SampleData.meals
    private var lastSaved: (at: Date, via: String)? = (SampleData.lastSavedAt, SampleData.lastSavedVia)
    /// A new account: no meals until the first one "arrives" on the third status check: the
    /// sign-in check and A5's first check still see none, so the waiting state shows.
    private var statusChecks = 0
    private let newAccount: Bool

    init(newAccount: Bool = false) {
        self.newAccount = newAccount
        if newAccount {
            todayMeals = []
            lastSaved = nil
        }
    }
    /// Marks the person set; an explicit nil means "not marked" (overrides the board pattern).
    private var marks: [Date: DayMark?] = [:]
    private var userSettings = UserSettings(
        timeZone: TimeZone.current.identifier, energyUnit: .kcal, calmMode: false,
        targets: [
            .calories: TargetRange(min: 1900, max: 2200), .protein: TargetRange(min: 110, max: 140),
            .fat: TargetRange(min: 55, max: 80), .carbohydrates: TargetRange(min: 200, max: 260),
        ],
        weightTracking: true)
    /// D3's sample weigh-ins: the board's 28 days ending today.
    private lazy var weighIns: [WeighIn] = SampleData.weightPoints.compactMap { point in
        guard let raw = point.raw else { return nil }
        let day = calendar.date(byAdding: .day, value: point.index - (SampleData.weightPoints.count - 1), to: calendar.startOfDay(for: .now)) ?? .now
        return WeighIn(id: UUID(), weightKg: raw, measuredAt: day.addingTimeInterval(7 * 3600), source: .appleHealth)
    }
    private var signIns: [Connection] = [
        Connection(id: "claude", name: "Claude", kind: .aiAssistant, signIns: [
            .init(id: UUID(), createdAt: .now.addingTimeInterval(-40 * 86_400), lastUsedAt: SampleData.lastSavedAt, isCurrent: false),
        ]),
        Connection(id: "chatgpt", name: "ChatGPT", kind: .aiAssistant, signIns: [
            .init(id: UUID(), createdAt: .now.addingTimeInterval(-12 * 86_400), lastUsedAt: .now.addingTimeInterval(-26 * 3600), isCurrent: false),
        ]),
        Connection(id: "ios", name: "Healthy Eating for iOS", kind: .iosApp, signIns: [
            .init(id: UUID(), createdAt: .now.addingTimeInterval(-40 * 86_400), lastUsedAt: .now, isCurrent: true),
        ]),
    ]
    private let calendar = Calendar.current

    func meals(on day: Date) -> [Meal] {
        if calendar.isDateInToday(day) { return todayMeals.sorted { $0.eatenAt > $1.eatenAt } }
        guard !newAccount, day < calendar.startOfDay(for: .now), pastState(day) != .none else { return [] }
        return SampleData.meals.map { meal in
            var moved = meal
            let time = calendar.dateComponents([.hour, .minute], from: meal.eatenAt)
            moved.eatenAt = calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: day) ?? day
            return moved
        }.sorted { $0.eatenAt > $1.eatenAt }
    }

    func days(from: Date, to: Date) -> DayRange {
        var days: [DayTotals] = []
        var day = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: to)
        while day <= last {
            days.append(totals(for: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return DayRange(days: days, countingRule: .completeDays)
    }

    func trends(window: Int) -> Trends {
        let sample = SampleData.trend(days: window)
        let averages = NutrientValues(
            caloriesKcal: sample.averageKcal, proteinG: sample.macroAverages[0].value,
            fatG: sample.macroAverages[1].value, carbohydratesG: sample.macroAverages[2].value)
        let change = NutrientValues(caloriesKcal: -70, proteinG: 6, fatG: 0, carbohydratesG: -11)
        let today = calendar.startOfDay(for: .now)
        let first = calendar.date(byAdding: .day, value: -(window - 1), to: today) ?? today
        let previousLast = calendar.date(byAdding: .day, value: -1, to: first) ?? first
        let previousFirst = calendar.date(byAdding: .day, value: -window, to: first) ?? first
        let logged = sample.days.filter { $0.state != .none }.count
        return Trends(
            windowDays: window, countingRule: .completeDays,
            current: TrendPeriod(firstDay: first, lastDay: today, countedDays: sample.completeDays, loggedDays: logged,
                                 averages: averages, estimatedCaloriesShare: 0.6,
                                 optionalAverages: [
                                     .fiber: OptionalAverage(average: 21, days: sample.completeDays),
                                     .sugar: OptionalAverage(average: 38, days: sample.completeDays),
                                     .sodium: OptionalAverage(average: 2100, days: max(1, sample.completeDays / 2)),
                                 ]),
            previous: TrendPeriod(firstDay: previousFirst, lastDay: previousLast, countedDays: sample.completeDays, loggedDays: logged,
                                  averages: NutrientValues(caloriesKcal: averages.caloriesKcal + 70, proteinG: averages.proteinG - 6,
                                                           fatG: averages.fatG, carbohydratesG: averages.carbohydratesG + 11),
                                  estimatedCaloriesShare: 0.55),
            change: change)
    }

    /// D2's sample week: Thursday not logged, today in progress, later days ahead; in past weeks
    /// Sunday is logged but not marked complete.
    func weeklyReview(week: Date) -> WeeklyReview {
        let today = calendar.startOfDay(for: .now)
        let day = calendar.startOfDay(for: week)
        let sinceMonday = (calendar.component(.weekday, from: day) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -sinceMonday, to: day) ?? day
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
        var leftOut: [WeeklyReview.LeftOutDay] = []
        var logged = 0, counted = 0, countedWeekend = 0
        for (index, date) in days.enumerated() {
            let reason: WeeklyReview.LeftOutReason? =
                if date > today { .future }
                else if date == today { .inProgress }
                else if index == 3 { .notLogged }
                else if index == 6 { .notMarkedComplete }
                else { nil }
            if reason != .future, reason != .notLogged { logged += 1 }
            if let reason {
                leftOut.append(.init(date: date, reason: reason))
            } else {
                counted += 1
                if index >= 5 { countedWeekend += 1 }
            }
        }
        let averages = NutrientValues(caloriesKcal: 2060, proteinG: 121, fatG: 70, carbohydratesG: 231)
        return WeeklyReview(
            firstDay: monday, lastDay: days.last ?? monday, countingRule: .completeDays,
            loggedDays: logged, completeDays: counted, countedDays: counted,
            averages: counted > 0 ? averages : nil,
            leftOut: leftOut,
            weekdays: .init(countedDays: counted - countedWeekend,
                            averages: counted > countedWeekend ? NutrientValues(caloriesKcal: 2010, proteinG: 118, fatG: 68, carbohydratesG: 226) : nil),
            weekend: .init(countedDays: countedWeekend,
                           averages: countedWeekend > 0 ? NutrientValues(caloriesKcal: 2190, proteinG: 128, fatG: 75, carbohydratesG: 244) : nil),
            mealCount: 17, proteinPerMealG: 31,
            proteinBuckets: [.init(minG: 0, maxG: 10, meals: 1), .init(minG: 10, maxG: 20, meals: 3), .init(minG: 20, maxG: 30, meals: 4),
                             .init(minG: 30, maxG: 40, meals: 5), .init(minG: 40, maxG: nil, meals: 4)],
            lateMeals: 2, estimatedValuesShare: 0.64, lowConfidenceMeals: 3)
    }

    func account() -> Account {
        Account(displayName: "Alex Kim", email: "alex@example.com", linkedLogins: ["google", "apple"])
    }

    func settings() -> UserSettings { userSettings }

    func updateSettings(_ change: APIClient.SettingsChange) -> UserSettings {
        if let timeZone = change.timeZone { userSettings.timeZone = timeZone }
        if let unit = change.energyUnit { userSettings.energyUnit = unit }
        if let calm = change.calmMode { userSettings.calmMode = calm }
        if let tracking = change.weightTracking { userSettings.weightTracking = tracking }
        if let unit = change.weightUnit { userSettings.weightUnit = unit }
        for (field, range) in change.targets { userSettings.targets[field] = range }
        return userSettings
    }

    // MARK: Weight (D3 sample values; the trend comes from the board, not computed here)

    func weights(from: Date, to: Date) -> WeightHistory {
        let first = calendar.startOfDay(for: from), last = calendar.startOfDay(for: to)
        let today = calendar.startOfDay(for: .now)
        let trend = SampleData.weightPoints.compactMap { point -> WeightTrendDay? in
            guard let raw = point.raw,
                  let day = calendar.date(byAdding: .day, value: point.index - (SampleData.weightPoints.count - 1), to: today),
                  day >= first, day <= last else { return nil }
            return WeightTrendDay(date: day, weightKg: raw, trendKg: point.trend)
        }
        let entries = weighIns
            .filter { calendar.startOfDay(for: $0.measuredAt) >= first && calendar.startOfDay(for: $0.measuredAt) <= last }
            .sorted { $0.measuredAt < $1.measuredAt }
        return WeightHistory(
            firstDay: first, lastDay: last, entries: entries, trend: weighIns.isEmpty ? [] : trend,
            latestTrendKg: weighIns.isEmpty ? nil : trend.last?.trendKg,
            weeklyChangeKg: weighIns.isEmpty ? nil : -0.3, changeDays: weighIns.isEmpty ? nil : 28)
    }

    func addWeight(kg: Double, at date: Date) -> WeighIn {
        let entry = WeighIn(id: UUID(), weightKg: kg, measuredAt: date, source: .app)
        weighIns.append(entry)
        userSettings.weightTracking = true
        return entry
    }

    func updateWeight(_ id: UUID, kg: Double?, at date: Date?) throws(APIError) -> WeighIn {
        guard let index = weighIns.firstIndex(where: { $0.id == id }) else { throw .notFound }
        if let kg { weighIns[index].weightKg = kg }
        if let date { weighIns[index].measuredAt = date }
        return weighIns[index]
    }

    func deleteWeight(_ id: UUID) throws(APIError) {
        guard weighIns.contains(where: { $0.id == id }) else { throw .notFound }
        weighIns.removeAll { $0.id == id }
    }

    func deleteAllWeights() -> Int {
        defer { weighIns.removeAll() }
        return weighIns.count
    }

    func energyEstimate() -> EnergyEstimate {
        guard weighIns.count >= 6 else {
            return EnergyEstimate(countedDays: 28, weighIns: weighIns.count, weighInDays: weighIns.count,
                                  averageIntakeKcal: 2060, maintenanceKcal: nil, confidence: nil, missing: .weighIns)
        }
        return EnergyEstimate(countedDays: 28, weighIns: 22, weighInDays: 22, averageIntakeKcal: 2060,
                              maintenanceKcal: 2350, confidence: .medium, missing: nil)
    }

    func integrationStatus() -> IntegrationState {
        if newAccount, lastSaved == nil {
            statusChecks += 1
            if statusChecks >= 3 {
                var first = SampleData.meals[0]
                first.eatenAt = .now
                todayMeals = [first]
                lastSaved = (.now, first.assistant)
            }
        }
        return IntegrationState(
            lastMealSavedAt: lastSaved?.at,
            lastAssistant: lastSaved?.via,
            mealsToday: todayMeals.count,
            arrival: newAccount ? .unknown : .ok
        )
    }

    func connections() -> [Connection] { signIns }

    func revoke(signIn id: UUID) -> Bool {
        let wasCurrent = signIns.contains { $0.signIns.contains { $0.id == id && $0.isCurrent } }
        signIns = signIns.compactMap { connection in
            var connection = connection
            connection.signIns.removeAll { $0.id == id }
            return connection.signIns.isEmpty ? nil : connection
        }
        return wasCurrent
    }

    func setMark(_ mark: DayMark?, on day: Date) {
        marks[calendar.startOfDay(for: day)] = .some(mark)
    }

    func update(_ id: UUID, with edit: APIClient.MealEdit) throws(APIError) -> (meal: Meal, warnings: [String]) {
        guard let index = todayMeals.firstIndex(where: { $0.id == id }) else { throw .notFound }
        var meal = todayMeals[index]
        if let name = edit.dishName { meal.dishName = name }
        if let portion = edit.portionGrams { meal.portionGrams = portion }
        if let eatenAt = edit.eatenAt { meal.eatenAt = eatenAt }
        let changes: [(NutrientField, Double?, WritableKeyPath<Meal, Double>)] = [
            (.calories, edit.caloriesKcal, \.caloriesKcal), (.protein, edit.proteinG, \.proteinG),
            (.fat, edit.fatG, \.fatG), (.carbohydrates, edit.carbohydratesG, \.carbohydratesG),
        ]
        for (field, value, path) in changes {
            if let value, value != meal[keyPath: path] {
                meal[keyPath: path] = value
                meal.estimatedFields.remove(field)
            }
        }
        todayMeals[index] = meal
        return (meal, [])
    }

    func deleteMeal(_ id: UUID) throws(APIError) {
        guard todayMeals.contains(where: { $0.id == id }) else { throw .notFound }
        todayMeals.removeAll { $0.id == id }
    }

    func export(format: String) throws(APIError) -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "healthy-eating-sample-export.json")
        do {
            try Data(#"{"format_version":1,"meals":[]}"#.utf8).write(to: url)
        } catch {
            throw .unexpectedResponse("could not save the export")
        }
        return url
    }

    func deleteAccount() {}

    // MARK: Helpers

    private func pastState(_ day: Date) -> DayState {
        SampleData.pastState(dayOfMonth: calendar.component(.day, from: day))
    }

    private func totals(for day: Date) -> DayTotals {
        let today = calendar.startOfDay(for: .now)
        if day > today {
            return DayTotals(date: day, mealCount: 0, caloriesKcal: 0, proteinG: 0, fatG: 0, carbohydratesG: 0,
                             estimatedCaloriesShare: nil, status: nil, markedBy: nil, counted: false)
        }
        let meals = meals(on: day)
        let kcal = meals.map(\.caloriesKcal).reduce(0, +)
        let estimated = meals.filter { $0.estimatedFields.contains(.calories) }.map(\.caloriesKcal).reduce(0, +)
        let pattern: DayMark? = day < today ? (pastState(day) == .complete ? .complete : pastState(day) == .partial ? .partial : nil) : nil
        let mark: DayMark? = marks.keys.contains(day) ? (marks[day] ?? nil) : pattern
        return DayTotals(
            date: day, mealCount: meals.count, caloriesKcal: kcal, proteinG: meals.map(\.proteinG).reduce(0, +),
            fatG: meals.map(\.fatG).reduce(0, +), carbohydratesG: meals.map(\.carbohydratesG).reduce(0, +),
            estimatedCaloriesShare: kcal > 0 ? estimated / kcal : nil, status: mark, markedBy: mark == nil ? nil : .user,
            counted: mark == .complete && !meals.isEmpty,
            optional: Dictionary(uniqueKeysWithValues: OptionalNutrient.allCases.compactMap { nutrient in
                let amounts = meals.compactMap { $0.optional[nutrient] }
                return amounts.isEmpty ? nil : (nutrient, OptionalTotal(amount: amounts.reduce(0, +), mealCount: amounts.count))
            }))
    }
}
