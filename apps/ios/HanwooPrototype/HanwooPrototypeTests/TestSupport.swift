import Foundation
@testable import HanwooPrototype

// 테스트 전용 원료 제공자: 카탈로그에 의존하지 않고 성분을 직접 지정한다.
@MainActor
struct StubIngredientProvider: IngredientProviding {
    var definitions: [String: IngredientDefinition] = [:]

    func ingredientDefinition(id: String) -> IngredientDefinition? {
        definitions[id]
    }
}

@MainActor
func makeDefinition(
    id: String,
    name: String? = nil,
    category: IngredientCategory = .concentrate,
    price: Int = 500,
    moisture: Double,
    cp: Double = 0,
    tdn: Double = 0,
    ndf: Double = 0,
    adf: Double = 0,
    nfc: Double = 0,
    ee: Double = 0,
    ash: Double = 0,
    ca: Double = 0,
    p: Double = 0
) -> IngredientDefinition {
    IngredientDefinition(
        id: id,
        sourceFeedNo: 9_000,
        name: name ?? id,
        sourceCategory: "테스트",
        selectionGroup: .tmr,
        category: category,
        defaultPriceKrwPerKg: price,
        nutrition: IngredientNutritionProfile(
            moisturePct: moisture,
            dmPct: 100 - moisture,
            cpPctDm: cp,
            tdnPctDm: tdn,
            ndfPctDm: ndf,
            adfPctDm: adf,
            nfcPctDm: nfc,
            eePctDm: ee,
            ashPctDm: ash,
            caPctDm: ca,
            pPctDm: p
        )
    )
}

@MainActor
func makeMetrics(
    totalAsFedKg: Double = 100,
    totalDmKg: Double = 60,
    moisture: Double = 42,
    cp: Double = 13.5,
    tdn: Double = 74,
    ndf: Double = 35,
    adf: Double = 21,
    nfc: Double = 30,
    ee: Double = 4,
    ca: Double = 0.5,
    p: Double = 0.3,
    caP: Double = 1.7
) -> AnalysisSummaryMetrics {
    AnalysisSummaryMetrics(
        totalAsFedKg: totalAsFedKg,
        totalDmKg: totalDmKg,
        moisturePct: moisture,
        cpPctDm: cp,
        tdnPctDm: tdn,
        ndfPctDm: ndf,
        adfPctDm: adf,
        nfcPctDm: nfc,
        eePctDm: ee,
        caPctDm: ca,
        pPctDm: p,
        caPRatio: caP
    )
}
