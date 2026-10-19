import Foundation

/// The design boards' sample data behind `NutritionDataSource`, kept in memory so edits,
/// deletes and day marks behave like the real server. Used with `-skipOnboarding` (UI tests,
/// screenshots) and in previews. Contains no logic the backend owns beyond simple sums.
actor SampleDataSource: NutritionDataSource {
    private var todayMeals: [Meal] = SampleData.meals
    /// Marks the person set; an explicit nil means "not marked" (overrides the board pattern).
    private var marks: [Date: DayMark?] = [:]
    private var userSettings = UserSettings(
        timeZone: TimeZone.current.identifier, energyUnit: .kcal, calmMode: false,
        targets: [
            .calories: TargetRange(min: 1900, max: 2200), .protein: TargetRange(min: 110, max: 140),
            .fat: TargetRange(min: 55, max: 80), .carbohydrates: TargetRange(min: 200, max: 260),
        ])
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
        guard day < calendar.startOfDay(for: .now), pastState(day) != .none else { return [] }
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
                                 averages: averages, estimatedCaloriesShare: 0.6),
            previous: TrendPeriod(firstDay: previousFirst, lastDay: previousLast, countedDays: sample.completeDays, loggedDays: logged,
                                  averages: NutrientValues(caloriesKcal: averages.caloriesKcal + 70, proteinG: averages.proteinG - 6,
                                                           fatG: averages.fatG, carbohydratesG: averages.carbohydratesG + 11),
                                  estimatedCaloriesShare: 0.55),
            change: change)
    }

    func account() -> Account {
        Account(displayName: "Alex Kim", email: "alex@example.com", linkedLogins: ["google", "apple"])
    }

    func settings() -> UserSettings { userSettings }

    func updateSettings(_ change: APIClient.SettingsChange) -> UserSettings {
        if let timeZone = change.timeZone { userSettings.timeZone = timeZone }
        if let unit = change.energyUnit { userSettings.energyUnit = unit }
        if let calm = change.calmMode { userSettings.calmMode = calm }
        for (field, range) in change.targets { userSettings.targets[field] = range }
        return userSettings
    }

    func integrationStatus() -> IntegrationState {
        IntegrationState(lastMealSavedAt: SampleData.lastSavedAt, lastAssistant: SampleData.lastSavedVia, mealsToday: todayMeals.count)
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
            counted: mark == .complete && !meals.isEmpty)
    }
}
