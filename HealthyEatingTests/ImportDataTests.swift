import Foundation
import Testing
@testable import HealthyEating

@MainActor
struct ImportDataTests {
    @Test func aFileIsCheckedBeforeItIsImported() async {
        let model = ImportDataModel()
        let source = SampleDataSource()

        let error = await model.check(Data("{}".utf8), using: source)

        #expect(error == nil)
        guard case .preview(let preview) = model.state else {
            Issue.record("expected a preview, got \(model.state)")
            return
        }
        #expect(preview.isPreview && preview.format == .json)
        #expect(await model.importFile(using: source))
        guard case .done(let result) = model.state else {
            Issue.record("expected a result, got \(model.state)")
            return
        }
        #expect(!result.isPreview)
        // The checked file is used once; importing again needs a new check.
        #expect(await model.importFile(using: source) == false)
    }

    @Test func aZipIsRecognizedByItsContent() async {
        let model = ImportDataModel()

        _ = await model.check(Data([0x50, 0x4B, 0x03, 0x04]), using: SampleDataSource())

        guard case .preview(let preview) = model.state else {
            Issue.record("expected a preview, got \(model.state)")
            return
        }
        #expect(preview.format == .csv)
    }

    @Test func aFileOverTheServersLimitIsNotSent() async {
        let model = ImportDataModel()

        let error = await model.check(Data(count: ImportDataModel.maxBytes + 1), using: SampleDataSource())

        #expect(error == .invalid(message: "The file is larger than 50 MB.", fields: [:]))
        #expect(model.state == .idle)
    }

    @Test func previewWording() {
        #expect(ImportFormat.counts(new: 42, known: 0) == "42 new")
        #expect(ImportFormat.counts(new: 42, known: 3) == "42 new, 3 already here")
        #expect(ImportFormat.rejected(.init(kind: .meal, position: 2, reason: "calories_kcal: too large")) == "Meal 2: calories_kcal: too large")
    }
}
