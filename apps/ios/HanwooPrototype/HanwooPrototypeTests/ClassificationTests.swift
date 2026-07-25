import XCTest
@testable import HanwooPrototype

// 판정 엔진: 성장단계 기준 대비 부족/주의/적정/과잉 경계 검증 (TEST_PLAN §2)
@MainActor
final class ClassificationTests: XCTestCase {

    private let engine = CalculationEngine(provider: StubIngredientProvider())

    private func tone(of nutrient: String, metrics: AnalysisSummaryMetrics, stage: FarmStage = .fatteningEarly) -> StatusTone? {
        engine.buildStatuses(stage: stage, criteria: stage.criteria, metrics: metrics)
            .first(where: { $0.nutrient == nutrient })?.tone
    }

    // 비육전기 CP 기준: 적정 12~15, 주의 11~16
    func testCPBands() {
        XCTAssertEqual(tone(of: "CP", metrics: makeMetrics(cp: 13.0)), .adequate)
        XCTAssertEqual(tone(of: "CP", metrics: makeMetrics(cp: 11.5)), .caution)
        XCTAssertEqual(tone(of: "CP", metrics: makeMetrics(cp: 10.5)), .deficient)
        XCTAssertEqual(tone(of: "CP", metrics: makeMetrics(cp: 15.5)), .caution)
        XCTAssertEqual(tone(of: "CP", metrics: makeMetrics(cp: 16.5)), .excess)
    }

    // EE 상한형: 적정 ≤5, 주의 ≤6, 초과 시 과잉
    func testEEUpperBands() {
        XCTAssertEqual(tone(of: "EE", metrics: makeMetrics(ee: 4.5)), .adequate)
        XCTAssertEqual(tone(of: "EE", metrics: makeMetrics(ee: 5.5)), .caution)
        XCTAssertEqual(tone(of: "EE", metrics: makeMetrics(ee: 6.5)), .excess)
    }

    // 수분: 적정 40~45, 주의 36~49
    func testMoistureBands() {
        XCTAssertEqual(tone(of: "수분", metrics: makeMetrics(moisture: 42)), .adequate)
        XCTAssertEqual(tone(of: "수분", metrics: makeMetrics(moisture: 38)), .caution)
        XCTAssertEqual(tone(of: "수분", metrics: makeMetrics(moisture: 34)), .deficient)
        XCTAssertEqual(tone(of: "수분", metrics: makeMetrics(moisture: 47)), .caution)
        XCTAssertEqual(tone(of: "수분", metrics: makeMetrics(moisture: 50.5)), .excess)
    }

    // Ca:P 비율: 적정 1.5~2.0, 주의 1.4~2.1
    func testCaPRatioBands() {
        XCTAssertEqual(tone(of: "Ca:P", metrics: makeMetrics(caP: 1.7)), .adequate)
        XCTAssertEqual(tone(of: "Ca:P", metrics: makeMetrics(caP: 1.45)), .caution)
        XCTAssertEqual(tone(of: "Ca:P", metrics: makeMetrics(caP: 1.0)), .deficient)
        XCTAssertEqual(tone(of: "Ca:P", metrics: makeMetrics(caP: 2.5)), .excess)
    }

    // 성장단계에 따라 같은 값의 판정이 달라져야 한다 (육성기 CP 적정 14~18)
    func testStageDependentClassification() {
        let metrics = makeMetrics(cp: 13.0)
        XCTAssertEqual(tone(of: "CP", metrics: metrics, stage: .fatteningEarly), .adequate)
        XCTAssertEqual(tone(of: "CP", metrics: metrics, stage: .growing), .caution)
    }

    // 건물량 0이면 판정 불가 안내를 반환해야 한다 (크래시 금지)
    func testZeroDryMatterIsSafe() {
        let statuses = engine.buildStatuses(
            stage: .growing,
            criteria: FarmStage.growing.criteria,
            metrics: makeMetrics(totalDmKg: 0)
        )
        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses.first?.tone, .caution)
    }
}
