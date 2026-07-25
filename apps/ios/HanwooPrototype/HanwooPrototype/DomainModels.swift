import SwiftUI

enum FarmStage: String, CaseIterable, Identifiable {
    case growing
    case fatteningEarly
    case fatteningLate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .growing: "육성기"
        case .fatteningEarly: "비육전기"
        case .fatteningLate: "비육후기"
        }
    }

    var summary: String {
        criteria.goalSummary
    }

    var criteria: StageCriteria {
        switch self {
        case .growing:
            StageCriteria(
                ageRangeLabel: "6~14개월",
                goalSummary: "반추위 발달과 골격 형성이 우선입니다.",
                cpBand: RangeThreshold(minimum: 14, maximum: 18, cautionMinimum: 13, cautionMaximum: 19),
                tdnBand: RangeThreshold(minimum: 68, maximum: 72, cautionMinimum: 66, cautionMaximum: 74),
                eeBand: UpperThreshold(recommendedMaximum: 5, cautionMaximum: 6),
                caBand: RangeThreshold(minimum: 0.45, maximum: 0.80, cautionMinimum: 0.38, cautionMaximum: 0.90),
                pBand: RangeThreshold(minimum: 0.28, maximum: 0.45, cautionMinimum: 0.24, cautionMaximum: 0.52),
                caPRatioBand: RangeThreshold(minimum: 1.5, maximum: 2.0, cautionMinimum: 1.4, cautionMaximum: 2.1),
                ndfBand: RangeThreshold(minimum: 35, maximum: 45, cautionMinimum: 32, cautionMaximum: 48),
                adfBand: RangeThreshold(minimum: 20, maximum: 28, cautionMinimum: 18, cautionMaximum: 30),
                moistureBand: RangeThreshold(minimum: 40, maximum: 45, cautionMinimum: 36, cautionMaximum: 49),
                moistureHardMaximumPct: 50,
                feedingNote: "조사료 비율을 높게 가져가며 반추위 발달을 먼저 확보합니다."
            )
        case .fatteningEarly:
            StageCriteria(
                ageRangeLabel: "14~20개월",
                goalSummary: "에너지를 올리기 시작하면서 증체 균형을 맞춥니다.",
                cpBand: RangeThreshold(minimum: 12, maximum: 15, cautionMinimum: 11, cautionMaximum: 16),
                tdnBand: RangeThreshold(minimum: 72, maximum: 76, cautionMinimum: 70, cautionMaximum: 78),
                eeBand: UpperThreshold(recommendedMaximum: 5, cautionMaximum: 6),
                caBand: RangeThreshold(minimum: 0.35, maximum: 0.65, cautionMinimum: 0.30, cautionMaximum: 0.75),
                pBand: RangeThreshold(minimum: 0.22, maximum: 0.38, cautionMinimum: 0.19, cautionMaximum: 0.44),
                caPRatioBand: RangeThreshold(minimum: 1.5, maximum: 2.0, cautionMinimum: 1.4, cautionMaximum: 2.1),
                ndfBand: RangeThreshold(minimum: 32, maximum: 38, cautionMinimum: 29, cautionMaximum: 40),
                adfBand: RangeThreshold(minimum: 18, maximum: 24, cautionMinimum: 16, cautionMaximum: 26),
                moistureBand: RangeThreshold(minimum: 40, maximum: 45, cautionMinimum: 36, cautionMaximum: 49),
                moistureHardMaximumPct: 50,
                feedingNote: "조사료와 농후사료의 균형을 유지하면서 에너지 증가를 시작합니다."
            )
        case .fatteningLate:
            StageCriteria(
                ageRangeLabel: "20개월~출하",
                goalSummary: "TDN 확보와 마무리 비육, 광물질 균형이 핵심입니다.",
                cpBand: RangeThreshold(minimum: 11, maximum: 13, cautionMinimum: 10, cautionMaximum: 14),
                tdnBand: RangeThreshold(minimum: 73, maximum: 78, cautionMinimum: 71, cautionMaximum: 80),
                eeBand: UpperThreshold(recommendedMaximum: 5, cautionMaximum: 6),
                caBand: RangeThreshold(minimum: 0.30, maximum: 0.60, cautionMinimum: 0.25, cautionMaximum: 0.70),
                pBand: RangeThreshold(minimum: 0.20, maximum: 0.35, cautionMinimum: 0.17, cautionMaximum: 0.41),
                caPRatioBand: RangeThreshold(minimum: 1.5, maximum: 2.0, cautionMinimum: 1.4, cautionMaximum: 2.1),
                ndfBand: RangeThreshold(minimum: 25, maximum: 32, cautionMinimum: 23, cautionMaximum: 35),
                adfBand: RangeThreshold(minimum: 15, maximum: 20, cautionMinimum: 13, cautionMaximum: 22),
                moistureBand: RangeThreshold(minimum: 40, maximum: 45, cautionMinimum: 36, cautionMaximum: 49),
                moistureHardMaximumPct: 50,
                feedingNote: "TDN을 우선하면서도 NDF 최소선은 유지해야 합니다.",
                tradeoffNote: "비육후기는 NDF를 높이면 증체에는 유리할 수 있지만, 너무 낮게 가져가면 육질 쪽으로 유리해질 수 있어 목표에 따라 조정이 필요합니다."
            )
        }
    }
}

struct RangeThreshold {
    var minimum: Double
    var maximum: Double
    var cautionMinimum: Double
    var cautionMaximum: Double
}

struct UpperThreshold {
    var recommendedMaximum: Double
    var cautionMaximum: Double
}

struct StageCriteria {
    var ageRangeLabel: String
    var goalSummary: String
    var cpBand: RangeThreshold
    var tdnBand: RangeThreshold
    var eeBand: UpperThreshold
    var caBand: RangeThreshold
    var pBand: RangeThreshold
    var caPRatioBand: RangeThreshold
    var ndfBand: RangeThreshold
    var adfBand: RangeThreshold
    var moistureBand: RangeThreshold
    var moistureHardMaximumPct: Double
    var feedingNote: String
    var tradeoffNote: String? = nil

    var cpMinimumPctDm: Double { cpBand.minimum }
    var cpMaximumPctDm: Double { cpBand.maximum }
    var cpCautionMinimumPctDm: Double { cpBand.cautionMinimum }
    var cpCautionMaximumPctDm: Double { cpBand.cautionMaximum }

    var tdnMinimumPctDm: Double { tdnBand.minimum }
    var tdnMaximumPctDm: Double { tdnBand.maximum }
    var tdnCautionMinimumPctDm: Double { tdnBand.cautionMinimum }
    var tdnCautionMaximumPctDm: Double { tdnBand.cautionMaximum }

    var eeMaxPctDm: Double { eeBand.recommendedMaximum }
    var eeCautionMaxPctDm: Double { eeBand.cautionMaximum }

    var caMinPctDm: Double { caBand.minimum }
    var caMaxPctDm: Double { caBand.maximum }
    var caCautionMinPctDm: Double { caBand.cautionMinimum }
    var caCautionMaxPctDm: Double { caBand.cautionMaximum }

    var pMinPctDm: Double { pBand.minimum }
    var pMaxPctDm: Double { pBand.maximum }
    var pCautionMinPctDm: Double { pBand.cautionMinimum }
    var pCautionMaxPctDm: Double { pBand.cautionMaximum }

    var caPRatioMin: Double { caPRatioBand.minimum }
    var caPRatioMax: Double { caPRatioBand.maximum }
    var caPRatioCautionMin: Double { caPRatioBand.cautionMinimum }
    var caPRatioCautionMax: Double { caPRatioBand.cautionMaximum }

    var ndfMinPctDm: Double { ndfBand.minimum }
    var ndfMaxPctDm: Double { ndfBand.maximum }
    var ndfCautionMinPctDm: Double { ndfBand.cautionMinimum }
    var ndfCautionMaxPctDm: Double { ndfBand.cautionMaximum }

    var adfMinPctDm: Double { adfBand.minimum }
    var adfMaxPctDm: Double { adfBand.maximum }
    var adfCautionMinPctDm: Double { adfBand.cautionMinimum }
    var adfCautionMaxPctDm: Double { adfBand.cautionMaximum }

    var moistureMinimumPct: Double { moistureBand.minimum }
    var moistureMaximumPct: Double { moistureBand.maximum }
    var moistureCautionMinimumPct: Double { moistureBand.cautionMinimum }
    var moistureCautionMaximumPct: Double { moistureBand.cautionMaximum }
}

enum StatusTone: String {
    case deficient
    case adequate
    case excess
    case caution

    var title: String {
        switch self {
        case .deficient: "부족"
        case .adequate: "적정"
        case .excess: "과잉"
        case .caution: "주의"
        }
    }

    var color: Color {
        switch self {
        case .deficient: .red
        case .adequate: .green
        case .excess: .orange
        case .caution: .yellow
        }
    }
}

enum WeightUnit: String, CaseIterable, Identifiable, Equatable {
    case kg
    case g

    var id: String { rawValue }
}

enum IngredientCategory: String, CaseIterable, Identifiable, Codable {
    case concentrate = "농후사료"
    case roughage = "조사료"
    case agriByproduct = "농산부산물"
    case supplement = "광물질 / 첨가제"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .concentrate: "grain"
        case .roughage: "leaf.fill"
        case .agriByproduct: "arrow.3.trianglepath"
        case .supplement: "pills.fill"
        }
    }
}

struct IngredientDefinition: Identifiable {
    let id: String
    let sourceFeedNo: Int
    let name: String
    let sourceCategory: String
    let selectionGroup: IngredientSelectionGroup
    let category: IngredientCategory
    let defaultPriceKrwPerKg: Int
    let nutrition: IngredientNutritionProfile
}

struct UserIngredientDefinition: Identifiable, Codable, Equatable {
    var id: String
    var ownerLoginID: String?
    var name: String
    var category: IngredientCategory
    var defaultPriceKrwPerKg: Int
    var nutrition: IngredientNutritionProfile
    var createdAt: Date

    init(
        id: String = "USER_\(UUID().uuidString)",
        ownerLoginID: String?,
        name: String,
        category: IngredientCategory,
        defaultPriceKrwPerKg: Int,
        nutrition: IngredientNutritionProfile,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerLoginID = ownerLoginID
        self.name = name
        self.category = category
        self.defaultPriceKrwPerKg = defaultPriceKrwPerKg
        self.nutrition = nutrition
        self.createdAt = createdAt
    }

    var ingredientDefinition: IngredientDefinition {
        IngredientDefinition(
            id: id,
            sourceFeedNo: -1,
            name: name,
            sourceCategory: "사용자 입력",
            selectionGroup: category == .supplement ? .mineral : .tmr,
            category: category,
            defaultPriceKrwPerKg: defaultPriceKrwPerKg,
            nutrition: nutrition
        )
    }
}

struct IngredientLine: Identifiable, Equatable {
    let id: UUID
    var name: String
    var definitionID: String?
    var amount: Double
    var unit: WeightUnit
    var priceOverrideKrwPerKg: Int?

    init(
        id: UUID = UUID(),
        name: String,
        definitionID: String? = nil,
        amount: Double,
        unit: WeightUnit = .kg,
        priceOverrideKrwPerKg: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.definitionID = definitionID
        self.amount = amount
        self.unit = unit
        self.priceOverrideKrwPerKg = priceOverrideKrwPerKg
    }
}

struct FeedFormula: Identifiable, Equatable {
    let id: UUID
    var name: String
    var stage: FarmStage
    var items: [IngredientLine]
    var isTestFormula: Bool
    var checkedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        stage: FarmStage,
        items: [IngredientLine],
        isTestFormula: Bool = false,
        checkedAt: Date
    ) {
        self.id = id
        self.name = name
        self.stage = stage
        self.items = items
        self.isTestFormula = isTestFormula
        self.checkedAt = checkedAt
    }
}

struct NutrientStatus: Identifiable {
    let id = UUID()
    var nutrient: String
    var currentValue: String
    var targetValue: String
    var tone: StatusTone
    var message: String
}

enum RecommendationStrategy: String, CaseIterable, Identifiable {
    case ownedFirst
    case costEffective
    case maintenance
    case noSolution

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ownedFirst: "보유원료 우선안"
        case .costEffective: "가성비 우선안"
        case .maintenance: "현재 배합 유지 권장"
        case .noSolution: "추가 교정 필요"
        }
    }
}

struct Recommendation: Identifiable {
    var id: String { strategy.rawValue }
    var strategy: RecommendationStrategy
    var title: String
    var ingredientID: String?
    var ingredient: String
    var action: String
    var reason: String
    var suggestedAmount: String?
    var amountNote: String?
    var trialAmountKg: Double
    var simulatedMetrics: AnalysisSummaryMetrics
    var costDeltaKrw: Int
    var isAlreadyInFormula: Bool
    var correctionActions: [CorrectionAction]
    var pros: [String]
    var cons: [String]
    var resolutionRate: Double
    var isFullyResolved: Bool
    var isReferenceOnly: Bool
}

enum CorrectionActionType {
    case decrease
    case increase
    case add
}

struct CorrectionAction: Identifiable {
    let id = UUID()
    var ingredientID: String?
    var ingredientName: String
    var type: CorrectionActionType
    var amountKg: Double
    var displayAmount: String
}

struct AnalysisSummaryMetrics {
    var totalAsFedKg: Double
    var totalDmKg: Double
    var moisturePct: Double
    var cpPctDm: Double
    var tdnPctDm: Double
    var ndfPctDm: Double
    var adfPctDm: Double
    var nfcPctDm: Double
    var eePctDm: Double
    var caPctDm: Double
    var pPctDm: Double
    var caPRatio: Double
}

struct AnalysisRun: Identifiable {
    let id = UUID()
    var formulaId: UUID
    var formulaName: String
    var stage: FarmStage
    var checkedAt: Date
    var summary: String
    var metrics: AnalysisSummaryMetrics
    var statuses: [NutrientStatus]
    var recommendations: [Recommendation]
}

struct RegressionCheck: Identifiable {
    let id = UUID()
    var title: String
    var passed: Bool
    var detail: String

    var tone: StatusTone {
        passed ? .adequate : .excess
    }
}

struct RegressionScenarioResult: Identifiable {
    let id = UUID()
    var formula: FeedFormula
    var analysis: AnalysisRun
    var primaryRecommendation: Recommendation?
    var projectedStatuses: [NutrientStatus]
    var expectationSummary: String
    var currentIssues: [String]
    var projectedIssues: [String]
    var checks: [RegressionCheck]

    var overallPassed: Bool {
        !checks.isEmpty && checks.allSatisfy(\.passed)
    }
}

struct DiaryEntry: Identifiable {
    var id: UUID
    var date: Date
    var formulaId: UUID
    var stoolStatus: String
    var growthStatus: String
    var nextFeedback: String
    var note: String
    var lastUpdatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        formulaId: UUID,
        stoolStatus: String,
        growthStatus: String,
        nextFeedback: String,
        note: String,
        lastUpdatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.formulaId = formulaId
        self.stoolStatus = stoolStatus
        self.growthStatus = growthStatus
        self.nextFeedback = nextFeedback
        self.note = note
        self.lastUpdatedAt = lastUpdatedAt
    }
}

struct CommunityPost: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var excerpt: String
    var label: String
    var authorLoginID: String
    var authorDisplayName: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        excerpt: String,
        label: String,
        authorLoginID: String,
        authorDisplayName: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.label = label
        self.authorLoginID = authorLoginID
        self.authorDisplayName = authorDisplayName
        self.createdAt = createdAt
    }
}

struct AppUser: Identifiable, Codable, Equatable {
    var id: UUID
    var loginID: String
    var email: String
    var password: String
    var farmName: String
    var preferredStageRawValue: String?
    var selectedIngredientIDs: [String]
    var isAdmin: Bool

    init(
        id: UUID = UUID(),
        loginID: String,
        email: String,
        password: String,
        farmName: String,
        preferredStageRawValue: String? = nil,
        selectedIngredientIDs: [String] = [],
        isAdmin: Bool = false
    ) {
        self.id = id
        self.loginID = loginID
        self.email = email
        self.password = password
        self.farmName = farmName
        self.preferredStageRawValue = preferredStageRawValue
        self.selectedIngredientIDs = selectedIngredientIDs
        self.isAdmin = isAdmin
    }

    var preferredStage: FarmStage? {
        preferredStageRawValue.flatMap(FarmStage.init(rawValue:))
    }

    var displayName: String {
        if isAdmin { return "관리자" }
        let prefix = email.split(separator: "@").first.map(String.init) ?? loginID
        return prefix.isEmpty ? loginID : prefix
    }
}

struct IngredientNutritionProfile: Codable, Equatable {
    var moisturePct: Double
    var dmPct: Double
    var cpPctDm: Double
    var tdnPctDm: Double
    var ndfPctDm: Double
    var adfPctDm: Double
    var nfcPctDm: Double
    var eePctDm: Double
    var ashPctDm: Double
    var caPctDm: Double
    var pPctDm: Double
}
