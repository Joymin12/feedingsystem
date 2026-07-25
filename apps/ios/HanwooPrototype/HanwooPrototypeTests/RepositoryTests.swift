import XCTest
@testable import HanwooPrototype

// 영속화: 저장/복구 라운드트립·손상 레코드 복구·엔진 버전 기록 (TEST_PLAN §4)
@MainActor
final class RepositoryTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "test.hanwoo.repositories"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func sampleFormula(name: String = "저장 테스트") -> FeedFormula {
        FeedFormula(
            name: name, stage: .fatteningEarly,
            items: [
                IngredientLine(name: "파쇄옥수수", definitionID: "FEED_4", amount: 10),
                IngredientLine(name: "물", definitionID: nil, amount: 5),
            ],
            checkedAt: .now
        )
    }

    private func sampleAnalysis() -> SavedAnalysis {
        SavedAnalysis(
            savedAt: .now,
            algorithmVersion: CorrectionAlgorithm.version,
            formula: sampleFormula(),
            summary: "요약",
            metrics: makeMetrics(),
            statuses: [NutrientStatus(nutrient: "CP", currentValue: "13%", targetValue: "12~15%", tone: .adequate, message: "적정")],
            recommendations: []
        )
    }

    func testFormulaRoundTrip() {
        let repo = UserDefaultsFormulaRepository(defaults: defaults)
        let original = [sampleFormula(name: "A"), sampleFormula(name: "B")]
        repo.saveFormulas(original)
        let loaded = repo.loadFormulas()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.map(\.name), ["A", "B"])
        XCTAssertEqual(loaded[0].items.count, 2)
        XCTAssertEqual(loaded[0].items[0].definitionID, "FEED_4")
        XCTAssertNil(loaded[0].items[1].definitionID)
    }

    func testAnalysisHistoryRoundTripKeepsAlgorithmVersion() {
        let repo = UserDefaultsAnalysisHistoryRepository(defaults: defaults)
        repo.saveAnalyses([sampleAnalysis()])
        let loaded = repo.loadAnalyses()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].algorithmVersion, CorrectionAlgorithm.version)
        XCTAssertEqual(loaded[0].statuses.first?.tone, .adequate)
        XCTAssertEqual(loaded[0].formula.items.count, 2)
    }

    func testCorruptedRecordIsSkippedNotFatal() throws {
        // 유효 레코드 1건 + 손상 레코드 1건이 섞인 저장 데이터 → 유효분만 복구
        let valid = try JSONEncoder().encode([sampleAnalysis()])
        var json = String(data: valid, encoding: .utf8)!
        json.removeLast() // "]" 제거
        json += ",{\"broken\":true}]"
        defaults.set(json.data(using: .utf8)!, forKey: "hanwoo.prototype.analysisHistory")

        let repo = UserDefaultsAnalysisHistoryRepository(defaults: defaults)
        let loaded = repo.loadAnalyses()
        XCTAssertEqual(loaded.count, 1, "손상 레코드는 건너뛰고 유효 레코드는 살려야 한다")
    }

    func testGarbageDataYieldsEmptyListNotCrash() {
        defaults.set(Data("완전히 깨진 데이터".utf8), forKey: "hanwoo.prototype.analysisHistory")
        let repo = UserDefaultsAnalysisHistoryRepository(defaults: defaults)
        XCTAssertEqual(repo.loadAnalyses().count, 0)
    }
}
