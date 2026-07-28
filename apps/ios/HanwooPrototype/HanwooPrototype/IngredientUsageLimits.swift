import Foundation

// MARK: - 원료별 급여 사용수준 (실무 제한)
//
// 출처: 농촌진흥청 농사로 농식품부산물영양정보, 축종 필터 "한우"
//       (USE_LEVEL_ATPN_CN 필드 원문. 수집 근거: docs/seeds/hanwoo-usage-levels.json)
//
// 왜 필요한가: 영양 9축 수치만 맞추면 특정 원료가 실무 급여 범위를 넘길 수 있다.
// 예를 들어 비지를 과도하게 늘리면 CP·수분은 맞아도 연변(묽은 변) 위험이 커진다.
// 사양학 관점의 상한을 하드 제약으로 걸어 시뮬레이션이 현실적인 범위에서만
// 증감하도록 한다.
//
// 해석 규칙
// - ratioOfTotal: 배합 총 원물 kg 대비 상한 비율
// - ratioOfConcentrate: 농후사료 합계 대비 상한 비율(원문이 "농후사료의 N%"인 경우)
// - advisory: 수치화할 수 없는 서술형 주의사항. 제약이 아니라 안내 문구로만 노출한다.

struct IngredientUsageLimit {
    let ingredientID: String
    let name: String
    /// 배합 총 원물 kg 대비 상한 (nil이면 비율 제한 없음)
    var ratioOfTotal: Double?
    /// 농후사료 합계 대비 상한 (nil이면 해당 없음)
    var ratioOfConcentrate: Double?
    /// 원문 사용수준 (화면 안내용)
    let useLevel: String
    /// 성장단계별로 상한이 다른 경우의 재정의.
    /// 농사로 원문이 월령·사육단계를 구분해 서술한 원료에만 채운다.
    /// 예) 맥주박 "생후 4개월~초산까지 20% 미만, 비육 후기 10% 이내"
    var stageOverrides: [FarmStage: Double] = [:]
    /// 단계별 안내 문구 재정의 (없으면 useLevel 사용)
    var stageNotes: [FarmStage: String] = [:]

    /// 해당 성장단계에서 적용할 총량 대비 상한
    func ratioOfTotal(for stage: FarmStage) -> Double? {
        stageOverrides[stage] ?? ratioOfTotal
    }

    /// 해당 성장단계에서 보여줄 안내 문구
    func useLevel(for stage: FarmStage) -> String {
        stageNotes[stage] ?? useLevel
    }
}

enum IngredientUsageLimits {

    // 수치 상한이 있는 원료. 값의 근거는 각 항목의 useLevel 원문.
    static let all: [IngredientUsageLimit] = [
        .init(ingredientID: "FEED_208", name: "채종박", ratioOfTotal: 0.07, ratioOfConcentrate: nil,
              useLevel: "반추동물 사료에 7% 이내로 제한하는 것이 좋습니다."),
        .init(ingredientID: "FEED_216", name: "미강", ratioOfTotal: 0.10, ratioOfConcentrate: nil,
              useLevel: "비육우에 다량 급여 시 연지방 축적·체지방 황색화 우려가 있어 10% 이내 사용을 권장합니다.",
              stageOverrides: [.growing: 0.20],
              stageNotes: [
                  .growing: "육성기에는 농후사료의 20~30% 범위로 급여할 수 있습니다. 비육 단계에서는 연지방 우려로 10% 이내로 낮춰야 합니다."
              ]),
        .init(ingredientID: "FEED_16", name: "쌀겨(생미강)", ratioOfTotal: 0.10, ratioOfConcentrate: nil,
              useLevel: "비육우에 다량 급여 시 연지방 축적·체지방 황색화 우려가 있어 10% 이내 사용을 권장합니다.",
              stageOverrides: [.growing: 0.20],
              stageNotes: [
                  .growing: "육성기에는 농후사료의 20~30% 범위로 급여할 수 있습니다. 비육 단계에서는 연지방 우려로 10% 이내로 낮춰야 합니다."
              ]),
        // 맥주박: 원문이 사육단계를 구분한다.
        // "생후 4개월~초산까지 20% 미만" → 육성기·비육전기 20%
        // "비육 후기 급여 시 섭취량이 떨어질 수 있어 10% 이내" → 비육후기 10%
        .init(ingredientID: "FEED_218", name: "맥주박", ratioOfTotal: 0.10, ratioOfConcentrate: nil,
              useLevel: "생후 4개월 이후 20% 미만으로 급여합니다. 비육 후기에는 섭취량 저하 우려가 있어 10% 이내를 권장합니다.",
              stageOverrides: [.growing: 0.20, .fatteningEarly: 0.20, .fatteningLate: 0.10],
              stageNotes: [
                  .growing: "생후 4개월 이후 20% 미만으로 급여합니다. 생후 4개월 미만에는 급여하지 않는 것이 좋습니다.",
                  .fatteningEarly: "생후 4개월 이후 20% 미만으로 급여합니다.",
                  .fatteningLate: "비육 후기에는 섭취량이 떨어질 수 있어 10% 이내 사용을 권장합니다."
              ]),
        .init(ingredientID: "FEED_201", name: "아마박", ratioOfTotal: 0.10, ratioOfConcentrate: nil,
              useLevel: "반추동물에는 5~10%까지 배합 가능합니다. 다량 급여 시 연지방이 생겨 도체품질이 떨어질 수 있습니다."),
        .init(ingredientID: "FEED_219", name: "루핀", ratioOfTotal: 0.10, ratioOfConcentrate: nil,
              useLevel: "10% 정도 사용이 가능합니다."),
        .init(ingredientID: "FEED_91", name: "루핀씨드", ratioOfTotal: 0.10, ratioOfConcentrate: nil,
              useLevel: "10% 정도 사용이 가능합니다."),
        .init(ingredientID: "FEED_220", name: "들깻묵(임자박)", ratioOfTotal: 0.10, ratioOfConcentrate: nil,
              useLevel: "10% 정도 사용이 가능하며 대두박의 12%까지 대체할 수 있습니다."),
        .init(ingredientID: "FEED_26", name: "들깻묵(임자박)", ratioOfTotal: 0.10, ratioOfConcentrate: nil,
              useLevel: "10% 정도 사용이 가능하며 대두박의 12%까지 대체할 수 있습니다."),
        .init(ingredientID: "FEED_204", name: "장유박", ratioOfTotal: 0.10, ratioOfConcentrate: nil,
              useLevel: "염분이 약 7%까지 들어 있어 배합 시 유의해야 합니다. 사용 범위는 10% 수준입니다."),
        .init(ingredientID: "FEED_202", name: "낙화생피", ratioOfTotal: 0.15, ratioOfConcentrate: nil,
              useLevel: "체지방을 연화시키는 현상이 있어 15% 이상은 사용하지 않는 것이 좋습니다."),
        .init(ingredientID: "FEED_223", name: "감귤박", ratioOfTotal: 0.15, ratioOfConcentrate: nil,
              useLevel: "비육우에 15% 이내로 사용이 가능합니다. 고수분이라 저장에 주의하세요."),
        .init(ingredientID: "FEED_213", name: "사과박", ratioOfTotal: 0.15, ratioOfConcentrate: nil,
              useLevel: "비육우의 적정 급여량은 10~15% 수준입니다. 임신우 급여 시 주의가 필요합니다."),
        .init(ingredientID: "FEED_215", name: "비지", ratioOfTotal: 0.40, ratioOfConcentrate: nil,
              useLevel: "발효 처리 기준 전체 사료의 40% 수준까지 보고되어 있습니다. 생비지를 다량 급여하면 묽은 변이 나올 수 있어 단계적으로 늘리세요."),
        .init(ingredientID: "FEED_45", name: "비지(두부박)", ratioOfTotal: 0.40, ratioOfConcentrate: nil,
              useLevel: "발효 처리 기준 전체 사료의 40% 수준까지 보고되어 있습니다. 생비지를 다량 급여하면 묽은 변이 나올 수 있어 단계적으로 늘리세요."),
        .init(ingredientID: "FEED_222", name: "대두박", ratioOfTotal: 0.50, ratioOfConcentrate: nil,
              useLevel: "반추동물용 사료에 50%까지 사용 가능합니다."),
        .init(ingredientID: "FEED_210", name: "주정박", ratioOfTotal: nil, ratioOfConcentrate: 0.05,
              useLevel: "농후사료의 5% 이하로 배합하는 것이 좋습니다. 다량 급여 시 기호성이 떨어집니다."),
        .init(ingredientID: "FEED_33", name: "옥수수 주정박", ratioOfTotal: nil, ratioOfConcentrate: 0.05,
              useLevel: "농후사료의 5% 이하로 배합하는 것이 좋습니다. 다량 급여 시 기호성이 떨어집니다."),
        .init(ingredientID: "FEED_212", name: "소맥피(밀기울)", ratioOfTotal: nil, ratioOfConcentrate: 0.30,
              useLevel: "농후사료의 25~30% 정도 사용합니다. 비육우 급여 시 고단백·고에너지 사료와 배합하세요."),
    ]

    private static let byID: [String: IngredientUsageLimit] = Dictionary(
        all.map { ($0.ingredientID, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    static func limit(for ingredientID: String) -> IngredientUsageLimit? {
        byID[ingredientID]
    }

    /// 사용수준을 배합 기준 최대 kg으로 환산한다.
    /// - Parameters:
    ///   - stage: 성장단계. 원문이 사육단계를 구분한 원료는 단계별 상한이 적용된다.
    ///   - totalAsFedKg: 배합 총 원물 kg
    ///   - concentrateAsFedKg: 농후사료 합계 원물 kg
    static func maxKg(
        for ingredientID: String,
        stage: FarmStage,
        totalAsFedKg: Double,
        concentrateAsFedKg: Double
    ) -> Double? {
        guard let limit = byID[ingredientID] else { return nil }
        var candidates: [Double] = []
        if let ratio = limit.ratioOfTotal(for: stage) { candidates.append(totalAsFedKg * ratio) }
        if let ratio = limit.ratioOfConcentrate { candidates.append(concentrateAsFedKg * ratio) }
        return candidates.min()
    }
}
