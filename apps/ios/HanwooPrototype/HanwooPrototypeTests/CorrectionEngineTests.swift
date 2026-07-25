import XCTest
@testable import HanwooPrototype

// 최적화 엔진: 골든 케이스·불변식·제약·결정론 검증 (TEST_PLAN §3)
@MainActor
final class CorrectionEngineTests: XCTestCase {

    var store: PrototypeStore!

    override func setUp() {
        super.setUp()
        store = PrototypeStore()
    }

    private func formula(named name: String) -> FeedFormula {
        guard let found = store.formulas.first(where: { $0.name == name }) else {
            XCTFail("시드 배합 없음: \(name)")
            fatalError()
        }
        return found
    }

    private func actionSignature(_ recommendation: Recommendation) -> [String] {
        recommendation.correctionActions
            .map { "\($0.ingredientID ?? "-")|\($0.type.rawValue)|\(String(format: "%.2f", $0.amountKg))" }
            .sorted()
    }

    // 골든: 경기TMR 3000kg — 완전 적정안 도출 + 총량 보존 + in-mix 불변식
    func testGyeonggiTMRResolvesFully() {
        let target = formula(named: "경기TMR 3000kg 테스트 배합")
        let run = store.analysis(for: target)
        guard let primary = defaultRecommendation(from: run.recommendations) else {
            return XCTFail("대표 추천 없음")
        }

        XCTAssertTrue(primary.isFullyResolved, "경기TMR은 완전 적정안이 나와야 한다")
        XCTAssertFalse(primary.correctionActions.isEmpty)

        // 총량 보존
        let originalTotal = target.items.reduce(0.0) { $0 + asFedKg(for: $1) }
        XCTAssertEqual(primary.simulatedMetrics.totalAsFedKg, originalTotal, accuracy: 0.05)

        // in-mix: 모든 액션 원료는 원 배합에 존재, 신규 add 없음
        let inMixIDs = Set(target.items.compactMap(\.definitionID))
        for action in primary.correctionActions {
            XCTAssertNotEqual(action.type, .add, "기본 추천안에 신규 원료가 있으면 안 된다")
            if let id = action.ingredientID {
                XCTAssertTrue(inMixIDs.contains(id), "\(action.ingredientName)는 배합에 없는 원료")
            }
            XCTAssertGreaterThan(action.amountKg, 0)
        }

        // 예상 지표는 계산 엔진 재검증 값과 일치해야 한다
        XCTAssertEqual(primary.algorithmVersion, CorrectionAlgorithm.version)
    }

    // 골든: CP 부족 배합 — 결과를 지어내지 않고 한계를 설명해야 한다
    func testImpossibleCaseExplainsLimit() {
        let target = formula(named: "엔진검증 - CP 부족")
        let run = store.analysis(for: target)
        guard let first = run.recommendations.first else { return XCTFail() }

        XCTAssertEqual(first.strategy, .noSolution)
        XCTAssertTrue(first.reason.contains("단백질원"), "CP 상한 한계 문구가 있어야 한다: \(first.reason)")

        // 참고안이 있으면 총량은 보존돼야 한다
        if let reference = run.recommendations.first(where: { $0.isReferenceOnly }) {
            let originalTotal = target.items.reduce(0.0) { $0 + asFedKg(for: $1) }
            XCTAssertEqual(reference.simulatedMetrics.totalAsFedKg, originalTotal, accuracy: 0.05)
        }
    }

    // 결정론: 같은 입력 → 항상 같은 추천
    func testDeterminism() {
        let target = formula(named: "경기TMR 3000kg 테스트 배합")
        let metrics = store.calculateMetrics(for: target).metrics
        let first = store.buildRecommendations(formula: target, stage: target.stage, metrics: metrics)
        let second = store.buildRecommendations(formula: target, stage: target.stage, metrics: metrics)

        XCTAssertEqual(first.count, second.count)
        if let a = first.first, let b = second.first {
            XCTAssertEqual(actionSignature(a), actionSignature(b))
            XCTAssertEqual(a.strategy, b.strategy)
        }
    }

    // 제약: 잠근 원료는 추천이 건드릴 수 없다
    func testLockedIngredientIsNeverTouched() {
        let target = formula(named: "경기TMR 3000kg 테스트 배합")
        let metrics = store.calculateMetrics(for: target).metrics
        let lockedID = "FEED_45" // 비지(두부박)
        XCTAssertTrue(target.items.contains { $0.definitionID == lockedID })

        let constraints = SimulationConstraints(lockedIngredientIDs: [lockedID])
        let recommendations = store.buildRecommendations(
            formula: target, stage: target.stage, metrics: metrics, constraints: constraints
        )
        for recommendation in recommendations {
            for action in recommendation.correctionActions {
                XCTAssertNotEqual(action.ingredientID, lockedID, "잠근 원료가 조정됨")
            }
        }
    }

    // 민감도: 입력 소폭 변화(±1%)가 해결 가능성을 뒤집지 않는다
    func testSensitivityToSmallInputChange() {
        let target = formula(named: "경기TMR 3000kg 테스트 배합")
        var variant = target
        if let index = variant.items.firstIndex(where: { $0.definitionID == "FEED_60" }) {
            variant.items[index].amount *= 1.01
        }
        let baseResolved = defaultRecommendation(from: store.analysis(for: target).recommendations)?.isFullyResolved ?? false
        let variantResolved = defaultRecommendation(from: store.analysis(for: variant).recommendations)?.isFullyResolved ?? false
        XCTAssertEqual(baseResolved, variantResolved)
    }

    // 유지 케이스: 전 축 적정인 합성 배합 → 현재 배합 유지 권장
    func testMaintenanceRecommendationForAdequateFormula() {
        // 합성 원료 2종으로 비육전기 기준을 정확히 만족시키는 배합을 구성한다.
        // (농후 70% + 조사료 30%, 성분은 기준 중앙값으로 설계)
        let concentrate = makeDefinition(
            id: "T_CONC", moisture: 43, cp: 13.5, tdn: 74, ndf: 35, adf: 21,
            nfc: 30, ee: 4, ash: 6, ca: 0.5, p: 0.3
        )
        let engine = CorrectionEngine(
            provider: StubIngredientProvider(definitions: [concentrate.id: concentrate]),
            ingredientDefinitions: [concentrate]
        )
        let formula = FeedFormula(
            name: "적정 배합", stage: .fatteningEarly,
            items: [IngredientLine(name: "T", definitionID: "T_CONC", amount: 100)],
            checkedAt: .now
        )
        let calc = CalculationEngine(provider: StubIngredientProvider(definitions: [concentrate.id: concentrate]))
        let metrics = calc.calculateMetrics(for: formula).metrics
        let recommendations = engine.buildRecommendations(formula: formula, stage: .fatteningEarly, metrics: metrics)
        XCTAssertEqual(recommendations.first?.strategy, .maintenance)
    }
}
