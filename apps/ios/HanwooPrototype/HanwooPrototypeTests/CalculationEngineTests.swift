import XCTest
@testable import HanwooPrototype

// 계산 엔진: DM 환산·가중평균·수분·단위 처리 검증 (TEST_PLAN §1)
@MainActor
final class CalculationEngineTests: XCTestCase {

    private func engine(_ defs: [IngredientDefinition]) -> CalculationEngine {
        CalculationEngine(provider: StubIngredientProvider(
            definitions: Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
        ))
    }

    func testDryMatterConversion() {
        // 수분 60% 원료 10kg → 건물 4kg, 배합 수분 60%
        let silage = makeDefinition(id: "S", moisture: 60, cp: 10)
        let formula = FeedFormula(
            name: "t", stage: .fatteningEarly,
            items: [IngredientLine(name: "S", definitionID: "S", amount: 10)],
            checkedAt: .now
        )
        let result = engine([silage]).calculateMetrics(for: formula)
        XCTAssertEqual(result.metrics.totalDmKg, 4.0, accuracy: 0.001)
        XCTAssertEqual(result.metrics.moisturePct, 60.0, accuracy: 0.001)
        XCTAssertEqual(result.metrics.totalAsFedKg, 10.0, accuracy: 0.001)
    }

    func testDryMatterWeightedAverage() {
        // 같은 건물량의 CP 10%·20% 원료 → 배합 CP 15%
        let a = makeDefinition(id: "A", moisture: 10, cp: 10)
        let b = makeDefinition(id: "B", moisture: 10, cp: 20)
        let formula = FeedFormula(
            name: "t", stage: .fatteningEarly,
            items: [
                IngredientLine(name: "A", definitionID: "A", amount: 10),
                IngredientLine(name: "B", definitionID: "B", amount: 10),
            ],
            checkedAt: .now
        )
        let metrics = engine([a, b]).calculateMetrics(for: formula).metrics
        XCTAssertEqual(metrics.cpPctDm, 15.0, accuracy: 0.001)
    }

    func testUnevenWeightedAverage() {
        // 건물 기여가 다른 경우: (9kg×10% + 3kg×30%) / 12kg = 15%
        let a = makeDefinition(id: "A", moisture: 10, cp: 10)   // 10kg → DM 9
        let b = makeDefinition(id: "B", moisture: 70, cp: 30)   // 10kg → DM 3
        let formula = FeedFormula(
            name: "t", stage: .growing,
            items: [
                IngredientLine(name: "A", definitionID: "A", amount: 10),
                IngredientLine(name: "B", definitionID: "B", amount: 10),
            ],
            checkedAt: .now
        )
        let metrics = engine([a, b]).calculateMetrics(for: formula).metrics
        XCTAssertEqual(metrics.cpPctDm, 15.0, accuracy: 0.001)
    }

    func testWaterLineAffectsOnlyMassAndMoisture() {
        // 성분 미등록 라인(물)은 원물 총량·수분에만 반영되고 %DM은 불변
        let a = makeDefinition(id: "A", moisture: 10, cp: 12, tdn: 70)
        let base = FeedFormula(
            name: "t", stage: .fatteningEarly,
            items: [IngredientLine(name: "A", definitionID: "A", amount: 10)],
            checkedAt: .now
        )
        var withWater = base
        withWater.items.append(IngredientLine(name: "물", definitionID: nil, amount: 5))

        let e = engine([a])
        let dry = e.calculateMetrics(for: base)
        let wet = e.calculateMetrics(for: withWater)

        XCTAssertEqual(wet.metrics.cpPctDm, dry.metrics.cpPctDm, accuracy: 0.0001)
        XCTAssertEqual(wet.metrics.tdnPctDm, dry.metrics.tdnPctDm, accuracy: 0.0001)
        XCTAssertEqual(wet.metrics.totalAsFedKg, 15.0, accuracy: 0.001)
        XCTAssertEqual(wet.metrics.totalDmKg, dry.metrics.totalDmKg, accuracy: 0.001)
        XCTAssertGreaterThan(wet.metrics.moisturePct, dry.metrics.moisturePct)
        XCTAssertEqual(wet.missingIngredients, ["물"])
    }

    func testEmptyFormulaIsSafe() {
        let formula = FeedFormula(name: "빈 배합", stage: .growing, items: [], checkedAt: .now)
        let result = engine([]).calculateMetrics(for: formula)
        XCTAssertEqual(result.metrics.totalDmKg, 0)
        XCTAssertEqual(result.metrics.cpPctDm, 0)
    }

    func testGramUnitConversion() {
        // 1000g 라인은 1kg과 동일하게 계산돼야 한다
        let a = makeDefinition(id: "A", moisture: 10, cp: 10)
        let grams = FeedFormula(
            name: "t", stage: .growing,
            items: [IngredientLine(name: "A", definitionID: "A", amount: 1000, unit: .g)],
            checkedAt: .now
        )
        let kg = FeedFormula(
            name: "t", stage: .growing,
            items: [IngredientLine(name: "A", definitionID: "A", amount: 1, unit: .kg)],
            checkedAt: .now
        )
        let e = engine([a])
        XCTAssertEqual(
            e.calculateMetrics(for: grams).metrics.totalDmKg,
            e.calculateMetrics(for: kg).metrics.totalDmKg,
            accuracy: 0.0001
        )
    }
}
