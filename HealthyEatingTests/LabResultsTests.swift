import Foundation
import Testing
@testable import HealthyEating

struct LabResultsTests {
    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        return calendar
    }

    private func day(_ text: String) throws -> Date {
        try #require(APIDate.day(text, calendar: calendar))
    }

    private func result(
        _ name: String, _ analyte: LabAnalyte?, _ value: Double, _ unit: String?,
        low: Double? = nil, high: Double? = nil, canonical: LabResult.Canonical? = nil
    ) -> LabResult {
        LabResult(id: UUID(), name: name, analyte: analyte, value: value, comparator: nil, unit: unit,
                  referenceLow: low, referenceHigh: high, canonical: canonical, relatedNutrient: nil)
    }

    /// A result the server does not know.
    private func result(_ name: String, _ value: Double, _ unit: String?) -> LabResult {
        result(name, nil, value, unit)
    }

    @Test func valuesAndRangesReadAsPrinted() {
        #expect(LabFormat.value(18, unit: "ng/mL", locale: locale) == "18 ng/mL")
        #expect(LabFormat.value(0.5, comparator: .below, unit: "mg/dL", locale: locale) == "< 0.5 mg/dL")
        #expect(LabFormat.value(0.8234, unit: nil, locale: locale) == "0.823")
        #expect(LabFormat.value(1250, unit: "U/L", locale: locale) == "1,250 U/L")
        #expect(LabFormat.range(low: 30, high: 100, unit: "ng/mL", locale: locale) == "Lab range 30–100 ng/mL")
        #expect(LabFormat.range(low: 30, high: nil, unit: "ng/mL", locale: locale) == "Lab range at least 30 ng/mL")
        #expect(LabFormat.range(low: nil, high: 5.2, unit: "mmol/L", locale: locale) == "Lab range up to 5.2 mmol/L")
        #expect(LabFormat.range(low: nil, high: 3, unit: nil, locale: locale) == "Lab range up to 3")
        #expect(LabFormat.range(low: nil, high: nil, unit: "%", locale: locale) == nil)
        #expect(LabFormat.resultCount(1) == "1 result")
        #expect(LabFormat.resultCount(4) == "4 results")
    }

    @Test func historiesGroupKnownAnalytesByCodeAndOthersByName() throws {
        let newer = LabReport(id: UUID(), takenOn: try day("2026-10-20"), results: [
            result("25-OH-Vitamin D", .vitaminD, 18, "ng/mL"),
            result("CRP", 0.5, "mg/dL"),
        ])
        let older = LabReport(id: UUID(), takenOn: try day("2026-04-02"), results: [
            result("Ferritin", .ferritin, 15, "ng/mL"),
            result("Vitamin D (25-OH)", .vitaminD, 52, "nmol/L"),
            result(" crp ", 0.9, "mg/dL"),
        ])

        let histories = LabAnalyteHistory.histories([newer, older])

        #expect(histories.map(\.id) == ["analyte.vitamin_d_25oh", "name.crp", "analyte.ferritin"])
        // A known analyte has the app's name, any other the newest printed one.
        #expect(histories.map(\.title) == ["25-OH vitamin D", "CRP", "Ferritin"])
        #expect(histories[0].entries.map(\.result.value) == [18, 52])
        #expect(histories[0].latest.reportID == newer.id)
        #expect(histories[1].entries.count == 2)
    }

    @Test func oneUnitIsChartedAsPrinted() throws {
        let history = LabAnalyteHistory(id: "analyte.ferritin", title: "Ferritin", analyte: .ferritin, entries: [
            .init(takenOn: try day("2026-10-20"), reportID: UUID(), result: result("Ferritin", .ferritin, 22, "µg/L", low: 15, high: 150)),
            .init(takenOn: try day("2026-04-02"), reportID: UUID(), result: result("Ferritin", .ferritin, 15, "ug / l", low: 15, high: 150)),
        ])

        let series = LabChartSeries(history)

        #expect(series.unit == "µg/L")
        #expect(series.points.map(\.value) == [15, 22])
        #expect(!series.converted && series.leftOut == 0)
        #expect(series.sharedRange?.low == 15 && series.sharedRange?.high == 150)
        #expect(LabAnalyteView.chartNote(series) == nil)
    }

    @Test func mixedUnitsUseTheServersCanonicalValues() throws {
        let canonical = LabResult.Canonical(value: 44.928, unit: "nmol/L", referenceLow: 74.88, referenceHigh: 249.6)
        let history = LabAnalyteHistory(id: "analyte.vitamin_d_25oh", title: "25-OH vitamin D", analyte: .vitaminD, entries: [
            .init(takenOn: try day("2026-10-20"), reportID: UUID(),
                  result: result("Vitamin D", .vitaminD, 18, "ng/mL", low: 30, high: 100, canonical: canonical)),
            .init(takenOn: try day("2026-04-02"), reportID: UUID(),
                  result: result("Vitamin D", .vitaminD, 52, "nmol/L", low: 50, high: 125,
                                 canonical: .init(value: 52, unit: "nmol/L", referenceLow: 50, referenceHigh: 125))),
            .init(takenOn: try day("2025-12-01"), reportID: UUID(), result: result("Vitamin D", .vitaminD, 20, "IU")),
        ])

        let series = LabChartSeries(history)

        #expect(series.unit == "nmol/L")
        #expect(series.points.map(\.value) == [52, 44.928])
        #expect(series.points.last?.low == 74.88)
        #expect(series.converted && series.leftOut == 1)
        // Each report printed its own range, so each value gets its own band.
        #expect(series.sharedRange == nil && series.hasRange)
        #expect(LabAnalyteView.chartNote(series)
            == "Shown in nmol/L, converted from the units on your reports. 1 value in another unit is not in the chart.")
    }

    @Test func withoutCanonicalValuesOnlyTheNewestUnitIsCharted() throws {
        let history = LabAnalyteHistory(id: "name.crp", title: "CRP", analyte: nil, entries: [
            .init(takenOn: try day("2026-10-20"), reportID: UUID(), result: result("CRP", 0.5, "mg/dL")),
            .init(takenOn: try day("2026-04-02"), reportID: UUID(), result: result("CRP", 4, "mg/L")),
            .init(takenOn: try day("2026-01-02"), reportID: UUID(), result: result("CRP", 6, "mg/L")),
            .init(takenOn: try day("2025-10-02"), reportID: UUID(), result: result("CRP", 0.3, "mg/dL")),
        ])

        let series = LabChartSeries(history)

        #expect(series.unit == "mg/dL")
        #expect(series.points.map(\.value) == [0.3, 0.5])
        #expect(!series.converted && series.leftOut == 2)
        #expect(!series.hasRange)
        #expect(LabAnalyteView.chartNote(series) == "2 values in other units are not in the chart.")
    }

    @Test func theIntakeChartCoversTheLabValues() throws {
        let today = try day("2026-10-29")
        #expect(LabAnalyteView.intakePeriod(earliest: try day("2026-09-01"), today: today, calendar: calendar) == .twelveWeeks)
        #expect(LabAnalyteView.intakePeriod(earliest: try day("2026-03-01"), today: today, calendar: calendar) == .year)
        #expect(LabAnalyteView.intakeNote(.twelveWeeks) == "Average per day, week by week, over the last 12 weeks.")
        #expect(LabAnalyteView.intakeNote(.year) == "Average per day, week by week, over the last year.")
    }

    @Test func deletingAReportSaysWhatGoes() throws {
        let one = LabReport(id: UUID(), takenOn: .now, results: [result("CRP", 0.5, "mg/dL")])
        #expect(LabReportView.deleteMessage(one).hasSuffix("is deleted. This can’t be undone."))
        let four = LabReport(id: UUID(), takenOn: .now, results: Array(repeating: result("CRP", 0.5, "mg/dL"), count: 4))
        #expect(LabReportView.deleteMessage(four).hasPrefix("All 4 results from "))
    }

    @Test func aLargeUpperBoundStillLeavesRoomAboveTheValues() {
        let series = LabChartSeries(unit: "mmol/L", points: [
            .init(id: UUID(), date: .now, value: 3.4, comparator: nil, low: nil, high: 3),
        ], converted: false, leftOut: 0)
        #expect(abs(LabValuesChart.scaleMax(series) - 3.91) < 0.0001)
        #expect(LabValuesChart.scaleMax(.init(unit: nil, points: [], converted: false, leftOut: 0)) == 1)
    }
}

extension NetworkTests {
    struct LabResultsAPITests {
        private func api(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) throws -> APIClient {
            let server = try ServerAddress.parse("https://food.example.com")
            let session = StubProtocol.session(handler)
            let store = CredentialStore(store: MemoryStore())
            store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil), for: server)
            return APIClient(server: server, auth: AuthSession(server: server, store: store, session: session), session: session)
        }

        @Test func readsReportsWithTheirResults() async throws {
            let body = """
            {"reports":[{"report_id":"0b6f5a4e-6d3c-4e57-9a51-1d6f0f7c2a10","taken_on":"2026-10-20","results":[
              {"id":"5d1d2f4e-3c1a-4a0b-8f11-0c5a1e2b3c4d","name":"25-OH-Vitamin D","analyte":"vitamin_d_25oh","value":18.0,
               "comparator":null,"unit":"ng/mL","reference_low":30.0,"reference_high":100.0,
               "canonical":{"value":44.928,"unit":"nmol/L","reference_low":74.88,"reference_high":249.6},
               "related_nutrient":"vitamin_d_ug","created_at":"2026-10-29T09:00:00Z","updated_at":"2026-10-29T09:00:00Z"},
              {"id":"6e2e3f5f-4d2b-4b1c-9f22-1d6b2f3c4d5e","name":"CRP","analyte":null,"value":0.5,"comparator":"<",
               "unit":"mg/dL","reference_low":null,"reference_high":null,"canonical":null,"related_nutrient":null,
               "created_at":"2026-10-29T09:00:00Z","updated_at":"2026-10-29T09:00:00Z"},
              {"id":"7f3f4a6a-5e3c-4c2d-8a33-2e7c3a4d5e6f","name":"Something new","analyte":"a_future_analyte","value":1,
               "comparator":null,"unit":null,"reference_low":null,"reference_high":null,"canonical":null,
               "related_nutrient":null,"created_at":"2026-10-29T09:00:00Z","updated_at":"2026-10-29T09:00:00Z"}]}]}
            """
            let api = try api { _ in (200, Data(body.utf8)) }

            let reports = try await api.labReports()

            #expect(StubProtocol.requests.last?.url?.path() == "/api/v1/lab-results")
            let report = try #require(reports.first)
            #expect(report.id == UUID(uuidString: "0b6f5a4e-6d3c-4e57-9a51-1d6f0f7c2a10"))
            #expect(report.takenOn == APIDate.day("2026-10-20", calendar: api.calendar))
            let vitaminD = report.results[0]
            #expect(vitaminD.analyte == .vitaminD && vitaminD.relatedNutrient == .vitaminD)
            #expect((vitaminD.referenceLow, vitaminD.referenceHigh) == (30, 100))
            #expect(vitaminD.canonical == .init(value: 44.928, unit: "nmol/L", referenceLow: 74.88, referenceHigh: 249.6))
            #expect(report.results[1].comparator == .below && report.results[1].analyte == nil)
            // An analyte this version does not know is shown by its printed name.
            #expect(report.results[2].analyte == nil && report.results[2].name == "Something new")
        }

        @Test func deletesOneResultOrAWholeReport() async throws {
            let api = try api { _ in (204, Data()) }
            let id = try #require(UUID(uuidString: "0B6F5A4E-6D3C-4E57-9A51-1D6F0F7C2A10"))

            try await api.deleteLabResult(id)
            #expect(StubProtocol.requests.last?.httpMethod == "DELETE")
            #expect(StubProtocol.requests.last?.url?.path() == "/api/v1/lab-results/0b6f5a4e-6d3c-4e57-9a51-1d6f0f7c2a10")

            try await api.deleteLabReport(id)
            #expect(StubProtocol.requests.last?.url?.path() == "/api/v1/lab-results/reports/0b6f5a4e-6d3c-4e57-9a51-1d6f0f7c2a10")
        }

        @Test func anImportCountsLabResults() async throws {
            let body = """
            {"dry_run":true,"format":"json","exported_at":null,
             "meals":{"imported":0,"skipped_duplicates":2},"weights":{"imported":0,"skipped_duplicates":0},
             "lab_results":{"imported":4,"skipped_duplicates":1},
             "days_marked":0,"first_day":null,"last_day":null,"rejected_count":1,
             "rejected":[{"kind":"lab_result","index":2,"reason":"value: too large"}]}
            """
            let api = try api { _ in (200, Data(body.utf8)) }

            let summary = try await api.importData(Data("{}".utf8), isZip: false, preview: true)

            #expect((summary.newLabResults, summary.knownLabResults) == (4, 1))
            // Only lab results are new, so the import adds something.
            #expect(!summary.addsNothing)
            #expect(summary.rejected == [.init(kind: .labResult, position: 3, reason: "value: too large")])
            #expect(ImportFormat.rejected(summary.rejected[0]) == "Lab result 3: value: too large")
        }
    }
}
