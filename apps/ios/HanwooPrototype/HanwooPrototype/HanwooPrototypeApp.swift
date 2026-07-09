import SwiftUI
import OSLog

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
                moistureBand: RangeThreshold(minimum: 40, maximum: 42, cautionMinimum: 38, cautionMaximum: 44),
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
                moistureBand: RangeThreshold(minimum: 40, maximum: 42, cautionMinimum: 38, cautionMaximum: 44),
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
                moistureBand: RangeThreshold(minimum: 40, maximum: 42, cautionMinimum: 38, cautionMaximum: 44),
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

enum IngredientCategory: String, CaseIterable, Identifiable {
    case concentrate   = "농후사료"
    case roughage      = "조사료"
    case agriByproduct = "농산부산물"
    case supplement    = "광물질 / 첨가제"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .concentrate:   "grain"
        case .roughage:      "leaf.fill"
        case .agriByproduct: "arrow.3.trianglepath"
        case .supplement:    "pills.fill"
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

struct IngredientLine: Identifiable, Equatable {
    let id: UUID
    var name: String
    var definitionID: String?
    var amount: Double
    var unit: WeightUnit
    var priceOverrideKrwPerKg: Int?   // nil → definition 기본가격 사용

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

struct IngredientNutritionProfile {
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

@MainActor
final class PrototypeStore: ObservableObject {
    private enum StorageKey {
        static let users = "hanwoo.prototype.users"
        static let currentLoginID = "hanwoo.prototype.currentLoginID"
        static let posts = "hanwoo.prototype.posts"
    }

    private let supabaseService = SupabaseService()
    private let debugLogger = Logger(subsystem: "com.jowm.HanwooPrototype", category: "RegressionRecommendations")

    // MARK: - 원료 DB (수집/정제된 실데이터 기반, 가격은 카테고리별 기본값)
    let ingredientDefinitions: [IngredientDefinition] = PrototypeStore.ingredientCatalog

    func ingredientDefinition(id: String) -> IngredientDefinition? {
        ingredientDefinitions.first(where: { $0.id == id })
    }

    func definitions(for category: IngredientCategory) -> [IngredientDefinition] {
        ingredientDefinitions.filter { $0.category == category }
    }

    func availableDefinitions(for category: IngredientCategory) -> [IngredientDefinition] {
        let all = definitions(for: category)
        guard let currentUser, !currentUser.selectedIngredientIDs.isEmpty else {
            return all
        }
        return all.filter { currentUser.selectedIngredientIDs.contains($0.id) }
    }

    @Published var isAuthenticated = false
    @Published var selectedStage: FarmStage?
    @Published var farmName = "행복한 한우 농장"
    @Published var formulas: [FeedFormula]
    @Published var diaryEntries: [DiaryEntry]
    @Published var posts: [CommunityPost]
    @Published var selectedFormulaID: UUID
    @Published var users: [AppUser]
    @Published var currentLoginID: String?

    init() {
        self.users = supabaseService.isConfigured ? [] : Self.loadUsers()
        self.currentLoginID = supabaseService.isConfigured ? nil : UserDefaults.standard.string(forKey: StorageKey.currentLoginID)
        let formulaA = FeedFormula(
            name: "비육전기 기본 배합",
            stage: .fatteningEarly,
            items: [
                IngredientLine(name: "파쇄옥수수", definitionID: "FEED_4", amount: 10),
                IngredientLine(name: "루핀씨드", definitionID: "FEED_91", amount: 3),
                IngredientLine(name: "보릿겨(맥강)", definitionID: "FEED_14", amount: 4),
                IngredientLine(name: "비지(두부박)", definitionID: "FEED_45", amount: 6),
                IngredientLine(name: "옥수수사일리지(황숙기)", definitionID: "FEED_72", amount: 8),
                IngredientLine(name: "볏짚(사일리지)", definitionID: "FEED_60", amount: 5),
            ],
            checkedAt: .now
        )
        let formulaB = FeedFormula(
            name: "육성기 기본 배합",
            stage: .growing,
            items: [
                IngredientLine(name: "알팔파 펠렛", definitionID: "FEED_56", amount: 5),
                IngredientLine(name: "보리사일리지(호숙기)", definitionID: "FEED_68", amount: 6),
                IngredientLine(name: "볏짚(사일리지)", definitionID: "FEED_60", amount: 5),
                IngredientLine(name: "루핀씨드", definitionID: "FEED_91", amount: 2),
                IngredientLine(name: "비트펄프", definitionID: "FEED_92", amount: 2),
            ],
            checkedAt: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
        )
        let formulaC = FeedFormula(
            name: "경기TMR 3000kg 테스트 배합",
            stage: .fatteningEarly,
            items: [
                IngredientLine(name: "대두박", definitionID: "CUSTOM_SOYBEAN_MEAL", amount: 90),
                IngredientLine(name: "루핀", definitionID: "FEED_91", amount: 90),
                IngredientLine(name: "파쇄옥수수", definitionID: "FEED_4", amount: 125),
                IngredientLine(name: "당밀", definitionID: "FEED_37", amount: 450),
                IngredientLine(name: "버섯배지", definitionID: "FEED_42", amount: 60),
                IngredientLine(name: "비지", definitionID: "FEED_45", amount: 543),
                IngredientLine(name: "깻묵", definitionID: "FEED_26", amount: 159),
                IngredientLine(name: "미강", definitionID: "FEED_16", amount: 300),
                IngredientLine(name: "맥강", definitionID: "FEED_14", amount: 90),
                IngredientLine(name: "석회석", definitionID: "FEED_109", amount: 6),
                IngredientLine(name: "소금", definitionID: "FEED_110", amount: 6),
                IngredientLine(name: "이스트컬쳐", definitionID: "CUSTOM_YEAST_CULTURE", amount: 1),
                IngredientLine(name: "볏짚", definitionID: "FEED_60", amount: 1080),
            ],
            isTestFormula: true,
            checkedAt: Calendar.current.date(byAdding: .hour, value: -6, to: .now) ?? .now
        )
        let formulaD = FeedFormula(
            name: "엔진검증 - CP 과잉",
            stage: .fatteningLate,
            items: [
                IngredientLine(name: "대두박", definitionID: "CUSTOM_SOYBEAN_MEAL", amount: 35),
                IngredientLine(name: "루핀씨드", definitionID: "FEED_91", amount: 12),
                IngredientLine(name: "비지(두부박)", definitionID: "FEED_45", amount: 8),
                IngredientLine(name: "파쇄옥수수", definitionID: "FEED_4", amount: 6),
                IngredientLine(name: "옥수수사일리지(황숙기)", definitionID: "FEED_72", amount: 10),
                IngredientLine(name: "볏짚(사일리지)", definitionID: "FEED_60", amount: 4),
            ],
            isTestFormula: true,
            checkedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        )
        let formulaE = FeedFormula(
            name: "엔진검증 - TDN 과잉",
            stage: .fatteningLate,
            items: [
                IngredientLine(name: "파쇄옥수수", definitionID: "FEED_4", amount: 16),
                IngredientLine(name: "옥수수(후레이크)", definitionID: "FEED_7", amount: 10),
                IngredientLine(name: "당밀", definitionID: "FEED_37", amount: 8),
                IngredientLine(name: "비지(두부박)", definitionID: "FEED_45", amount: 3),
                IngredientLine(name: "옥수수사일리지(황숙기)", definitionID: "FEED_72", amount: 3),
                IngredientLine(name: "볏짚(사일리지)", definitionID: "FEED_60", amount: 2),
            ],
            isTestFormula: true,
            checkedAt: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now
        )
        let formulaF = FeedFormula(
            name: "엔진검증 - CP 부족",
            stage: .growing,
            items: [
                IngredientLine(name: "옥수수사일리지(황숙기)", definitionID: "FEED_72", amount: 12),
                IngredientLine(name: "볏짚(사일리지)", definitionID: "FEED_60", amount: 6),
                IngredientLine(name: "파쇄옥수수", definitionID: "FEED_4", amount: 8),
                IngredientLine(name: "당밀", definitionID: "FEED_37", amount: 2),
            ],
            isTestFormula: true,
            checkedAt: Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now
        )
        let formulaG = FeedFormula(
            name: "엔진검증 - EE 과잉 + CP 부족",
            stage: .fatteningEarly,
            items: [
                IngredientLine(name: "쌀겨(생미강)", definitionID: "FEED_16", amount: 12),
                IngredientLine(name: "파쇄옥수수", definitionID: "FEED_4", amount: 8),
                IngredientLine(name: "옥수수사일리지(황숙기)", definitionID: "FEED_72", amount: 6),
                IngredientLine(name: "볏짚(사일리지)", definitionID: "FEED_60", amount: 6),
                IngredientLine(name: "당밀", definitionID: "FEED_37", amount: 2),
            ],
            isTestFormula: true,
            checkedAt: Calendar.current.date(byAdding: .day, value: -5, to: .now) ?? .now
        )

        self.formulas = [formulaA, formulaB, formulaC, formulaD, formulaE, formulaF, formulaG]
        self.selectedFormulaID = formulaA.id

        #if DEBUG
        let _debugFormulas = [formulaC, formulaD, formulaE, formulaF, formulaG]
        Task { @MainActor [weak self] in
            guard let self else { return }
            var lines: [String] = ["DEBUG START \(Date())"]
            for formula in _debugFormulas {
                let run = self.analysis(for: formula)
                lines.append(">>> [\(formula.name)]")
                for rec in run.recommendations {
                    let acts = rec.correctionActions.map { "\($0.type)==\($0.ingredientName) \(String(format:"%.1f",$0.amountKg))kg" }.joined(separator: " / ")
                    lines.append("    strategy=\(rec.strategy) full=\(rec.isFullyResolved) actions=[\(acts)]")
                }
                if run.recommendations.first?.strategy == .noSolution { lines.append("    noSolution") }
            }
            lines.append("DEBUG END")
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = docs.appendingPathComponent("hanwoo_regression.txt")
            try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        }
        #endif
        self.diaryEntries = [
            DiaryEntry(
                date: .now,
                formulaId: formulaA.id,
                stoolStatus: "약간 무름",
                growthStatus: "무난",
                nextFeedback: "옥수수 1kg 낮춰보고 변 상태 다시 보기",
                note: "오후에는 잘 먹었지만 분변이 조금 묽었습니다. 다음 급여에서는 습식 원료 비중을 낮춰볼 예정입니다."
            ),
            DiaryEntry(
                date: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now,
                formulaId: formulaB.id,
                stoolStatus: "안정",
                growthStatus: "좋아짐",
                nextFeedback: "조사료 유지, 오후 단백질원 1kg 보강 검토",
                note: "섭취 반응이 안정적이고 육성기 체형이 고르게 올라오는 느낌입니다."
            ),
        ]
        self.posts = supabaseService.isConfigured ? [] : Self.loadPosts()
        if supabaseService.isConfigured {
            Task {
                await bootstrapSupabaseSession()
            }
        } else {
            ensureAdminUser()
            if posts.isEmpty {
                posts = Self.seedPosts()
                savePosts()
            }
            syncSessionFromCurrentUser()
        }

        dumpRegressionRecommendationsIfNeeded()
    }

    var usesSupabase: Bool {
        supabaseService.isConfigured
    }

    var hasCompletedOnboarding: Bool {
        selectedStage != nil
    }

    var currentUser: AppUser? {
        guard let currentLoginID else { return nil }
        return users.first(where: { $0.loginID == currentLoginID })
    }

    private func dumpRegressionRecommendationsIfNeeded() {
        let processInfo = ProcessInfo.processInfo
        let shouldDumpFromEnv = processInfo.environment["DEBUG_RECOMMENDATION_DUMP"] == "1"
        let shouldDumpFromArgs = processInfo.arguments.contains("DEBUG_RECOMMENDATION_DUMP")
        guard shouldDumpFromEnv || shouldDumpFromArgs else { return }

        let targetNames = [
            "경기TMR 3000kg 테스트 배합",
            "엔진검증 - CP 과잉",
            "엔진검증 - TDN 과잉",
            "엔진검증 - CP 부족",
            "엔진검증 - EE 과잉 + CP 부족"
        ]

        var lines: [String] = []
        for name in targetNames {
            guard let formula = formulas.first(where: { $0.name == name }) else { continue }
            let analysis = analysis(for: formula)
            let recommendation = defaultRecommendation(from: analysis.recommendations) ?? analysis.recommendations.first
            lines.append("=== REGRESSION \(name) ===")
            lines.append("summary=\(analysis.summary)")
            if let recommendation {
                lines.append("strategy=\(recommendation.strategy.rawValue) resolved=\(recommendation.isFullyResolved) rate=\(String(format: "%.2f", recommendation.resolutionRate)) cost=\(recommendation.costDeltaKrw)")
                for action in recommendation.correctionActions {
                    lines.append("action=\(action.type) \(action.ingredientName) \(String(format: "%.1f", action.amountKg))kg")
                }
                lines.append("reason=\(recommendation.reason)")
            } else {
                lines.append("strategy=none")
            }
            lines.append("")
        }

        let text = lines.joined(separator: "\n")
        debugLogger.notice("\(text)")
        print(text)
        if let data = text.data(using: .utf8) {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recommendation-dump.txt")
            try? data.write(to: tempURL, options: .atomic)
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let documentsDumpURL = documentsURL.appendingPathComponent("recommendation-dump.txt")
                try? data.write(to: documentsDumpURL, options: .atomic)
            }
            if let explicitDumpPath = processInfo.environment["DEBUG_RECOMMENDATION_DUMP_PATH"],
               !explicitDumpPath.isEmpty {
                let explicitDumpURL = URL(fileURLWithPath: explicitDumpPath)
                try? data.write(to: explicitDumpURL, options: .atomic)
            }
        }
    }

    func bootstrapSupabaseSession() async {
        do {
            guard let restoredUser = try await supabaseService.restoreUser() else {
                isAuthenticated = false
                return
            }
            users = [restoredUser]
            currentLoginID = restoredUser.loginID
            posts = try await supabaseService.fetchPosts()
            syncSessionFromCurrentUser()
            isAuthenticated = true
        } catch {
            isAuthenticated = false
        }
    }

    func performLogin(loginID: String, password: String) async -> String? {
        if usesSupabase {
            do {
                let user = try await supabaseService.signIn(email: loginID, password: password)
                users = [user]
                currentLoginID = user.loginID
                posts = try await supabaseService.fetchPosts()
                syncSessionFromCurrentUser()
                isAuthenticated = true
                return nil
            } catch {
                return error.localizedDescription
            }
        }

        let succeeded = login(loginID: loginID, password: password)
        return succeeded ? nil : "아이디 또는 비밀번호가 맞지 않습니다."
    }

    func performRegistration(
        email: String,
        password: String,
        selectedIngredientIDs: [String]
    ) async -> (SupabaseRegistrationOutcome?, String?) {
        if usesSupabase {
            do {
                let outcome = try await supabaseService.signUp(
                    email: email,
                    password: password,
                    farmName: defaultFarmName(for: email),
                    selectedIngredientIDs: selectedIngredientIDs
                )

                switch outcome {
                case let .signedIn(user):
                    users = [user]
                    currentLoginID = user.loginID
                    posts = try await supabaseService.fetchPosts()
                    syncSessionFromCurrentUser()
                    isAuthenticated = true
                case .confirmationRequired:
                    isAuthenticated = false
                }

                return (outcome, nil)
            } catch {
                return (nil, error.localizedDescription)
            }
        }

        let succeeded = registerUser(
            email: email,
            password: password,
            selectedIngredientIDs: selectedIngredientIDs
        )
        if succeeded {
            let user = currentUser ?? AppUser(loginID: email, email: email, password: "", farmName: defaultFarmName(for: email))
            return (.signedIn(user), nil)
        }
        return (nil, "이미 가입된 이메일입니다.")
    }

    func performLogout() async {
        if usesSupabase {
            await supabaseService.signOut()
        }
        logout()
    }

    func performCreatePost(title: String, excerpt: String, label: String) async -> String? {
        if usesSupabase {
            do {
                posts = try await supabaseService.createPost(title: title, excerpt: excerpt, label: label)
                return nil
            } catch {
                return error.localizedDescription
            }
        }

        createPost(title: title, excerpt: excerpt, label: label)
        return nil
    }

    func performDeletePost(id: UUID) async -> String? {
        if usesSupabase {
            do {
                posts = try await supabaseService.deletePost(id: id)
                return nil
            } catch {
                return error.localizedDescription
            }
        }

        deletePost(id: id)
        return nil
    }

    var recentAnalyses: [AnalysisRun] {
        formulas
            .map { analysis(for: $0) }
            .sorted(by: { $0.checkedAt > $1.checkedAt })
    }

    var userFacingFormulas: [FeedFormula] {
        let visible = currentUser?.isAdmin == true ? formulas : formulas.filter { !$0.isTestFormula }
        return visible.sorted(by: { $0.checkedAt > $1.checkedAt })
    }

    var userFacingAnalyses: [AnalysisRun] {
        userFacingFormulas
            .map { analysis(for: $0) }
            .sorted(by: { $0.checkedAt > $1.checkedAt })
    }

    var regressionFormulas: [FeedFormula] {
        formulas
            .filter(\.isTestFormula)
            .sorted(by: { $0.checkedAt > $1.checkedAt })
    }

    func regressionSuiteResults() -> [RegressionScenarioResult] {
        regressionFormulas.map { formula in
            let analysis = analysis(for: formula)
            let primary = defaultRecommendation(from: analysis.recommendations)
            let projectedStatuses = primary.map {
                buildStatuses(stage: formula.stage, criteria: formula.stage.criteria, metrics: $0.simulatedMetrics)
            } ?? []
            return evaluateRegressionScenario(
                formula: formula,
                analysis: analysis,
                primaryRecommendation: primary,
                projectedStatuses: projectedStatuses
            )
        }
    }

    func login(loginID: String, password: String) -> Bool {
        guard let user = users.first(where: {
            $0.loginID.caseInsensitiveCompare(loginID) == .orderedSame && $0.password == password
        }) else {
            return false
        }
        currentLoginID = user.loginID
        UserDefaults.standard.set(user.loginID, forKey: StorageKey.currentLoginID)
        syncSessionFromCurrentUser()
        isAuthenticated = true
        return true
    }

    func registerUser(email: String, password: String, selectedIngredientIDs: [String]) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty else { return false }
        guard users.allSatisfy({ $0.loginID.caseInsensitiveCompare(trimmedEmail) != .orderedSame }) else {
            return false
        }

        let farmName = defaultFarmName(for: trimmedEmail)
        let newUser = AppUser(
            loginID: trimmedEmail,
            email: trimmedEmail,
            password: password,
            farmName: farmName,
            selectedIngredientIDs: selectedIngredientIDs,
            isAdmin: false
        )
        users.append(newUser)
        saveUsers()
        currentLoginID = newUser.loginID
        UserDefaults.standard.set(newUser.loginID, forKey: StorageKey.currentLoginID)
        syncSessionFromCurrentUser()
        isAuthenticated = true
        return true
    }

    func logout() {
        currentLoginID = nil
        UserDefaults.standard.removeObject(forKey: StorageKey.currentLoginID)
        isAuthenticated = false
        selectedStage = nil
        farmName = "행복한 한우 농장"
        if usesSupabase {
            users = []
            posts = []
        }
    }

    func completeOnboarding(stage: FarmStage) {
        selectedStage = stage
        if usesSupabase {
            if let index = users.firstIndex(where: { $0.loginID == currentLoginID }) {
                users[index].preferredStageRawValue = stage.rawValue
            }
            Task {
                try? await supabaseService.updatePreferredStage(stage.rawValue)
            }
            syncSessionFromCurrentUser()
        } else {
            updateCurrentUser { user in
                user.preferredStageRawValue = stage.rawValue
            }
        }
        if let index = formulas.firstIndex(where: { $0.id == selectedFormulaID }) {
            formulas[index].stage = stage
        }
    }

    func updateFormula(_ formula: FeedFormula) {
        guard let index = formulas.firstIndex(where: { $0.id == formula.id }) else { return }
        formulas[index] = formula
    }

    func addIngredient(to formulaID: UUID, definition: IngredientDefinition, amount: Double = 10) {
        guard let index = formulas.firstIndex(where: { $0.id == formulaID }) else { return }
        formulas[index].items.append(IngredientLine(
            name: definition.name,
            definitionID: definition.id,
            amount: amount
        ))
    }

    func addCustomIngredient(to formulaID: UUID, name: String, amount: Double = 10) {
        guard let index = formulas.firstIndex(where: { $0.id == formulaID }) else { return }
        formulas[index].items.append(IngredientLine(name: name, definitionID: nil, amount: amount))
    }

    func effectivePricePerKg(for item: IngredientLine) -> Int? {
        if let override = item.priceOverrideKrwPerKg { return override }
        guard let defID = item.definitionID else { return nil }
        return ingredientDefinition(id: defID)?.defaultPriceKrwPerKg
    }

    func totalCostKrw(for formula: FeedFormula) -> Int? {
        var total = 0
        var hasAnyPrice = false
        for item in formula.items {
            guard let price = effectivePricePerKg(for: item) else { continue }
            let kg = asFedKg(for: item)
            total += Int(kg * Double(price))
            hasAnyPrice = true
        }
        return hasAnyPrice ? total : nil
    }

    func removeIngredient(from formulaID: UUID, ingredientID: UUID) {
        guard let index = formulas.firstIndex(where: { $0.id == formulaID }) else { return }
        formulas[index].items.removeAll(where: { $0.id == ingredientID })
    }

    func formula(for id: UUID) -> FeedFormula? {
        formulas.first(where: { $0.id == id })
    }

    func preferredSelectedFormulaID() -> UUID {
        if let selected = formula(for: selectedFormulaID),
           currentUser?.isAdmin == true || !selected.isTestFormula {
            return selected.id
        }

        if let firstVisible = userFacingFormulas.first {
            return firstVisible.id
        }

        return selectedFormulaID
    }

    func createPost(title: String, excerpt: String, label: String) {
        guard let currentUser else { return }
        let post = CommunityPost(
            title: title,
            excerpt: excerpt,
            label: label,
            authorLoginID: currentUser.loginID,
            authorDisplayName: currentUser.displayName
        )
        posts.insert(post, at: 0)
        savePosts()
    }

    func canDelete(post: CommunityPost) -> Bool {
        guard let currentUser else { return false }
        return currentUser.isAdmin || currentUser.loginID == post.authorLoginID
    }

    func deletePost(id: UUID) {
        guard let post = posts.first(where: { $0.id == id }), canDelete(post: post) else { return }
        posts.removeAll(where: { $0.id == id })
        savePosts()
    }

    func analysis(for formula: FeedFormula) -> AnalysisRun {
        let stage = formula.stage
        let criteria = stage.criteria
        let calculation = calculateMetrics(for: formula)
        let metrics = calculation.metrics
        let statuses = buildStatuses(stage: stage, criteria: criteria, metrics: metrics)
        let recommendations = buildRecommendations(formula: formula, stage: stage, metrics: metrics)
        let summary = buildSummary(stage: stage, metrics: metrics, missingIngredients: calculation.missingIngredients, totalIngredients: formula.items.count)

        return AnalysisRun(
            formulaId: formula.id,
            formulaName: formula.name,
            stage: stage,
            checkedAt: formula.checkedAt,
            summary: summary,
            metrics: metrics,
            statuses: statuses,
            recommendations: recommendations
        )
    }


    func saveDiary(_ entry: DiaryEntry) {
        if let index = diaryEntries.firstIndex(where: { $0.id == entry.id }) {
            diaryEntries[index] = entry
        } else {
            diaryEntries.insert(entry, at: 0)
        }
        diaryEntries.sort(by: { $0.date > $1.date })
    }

    private func evaluateRegressionScenario(
        formula: FeedFormula,
        analysis: AnalysisRun,
        primaryRecommendation: Recommendation?,
        projectedStatuses: [NutrientStatus]
    ) -> RegressionScenarioResult {
        let currentIssues = issueLabels(from: analysis.statuses)
        let nextIssues = issueLabels(from: projectedStatuses)
        let checks = regressionChecks(
            formula: formula,
            analysis: analysis,
            primaryRecommendation: primaryRecommendation,
            projectedStatuses: projectedStatuses
        )

        return RegressionScenarioResult(
            formula: formula,
            analysis: analysis,
            primaryRecommendation: primaryRecommendation,
            projectedStatuses: projectedStatuses,
            expectationSummary: regressionExpectationSummary(for: formula),
            currentIssues: currentIssues,
            projectedIssues: nextIssues,
            checks: checks
        )
    }

    private func regressionExpectationSummary(for formula: FeedFormula) -> String {
        switch formula.name {
        case "경기TMR 3000kg 테스트 배합":
            return "사용자 제공 3000kg 테스트 배합 기준으로 복합 교정안과 광물질 보정까지 함께 검증합니다."
        case "엔진검증 - CP 과잉":
            return "단백질원 감량이 우선으로 나와야 하며, 감량 후 TDN과 섬유가 크게 무너지지 않아야 합니다."
        case "엔진검증 - TDN 과잉":
            return "에너지 기여가 큰 곡류와 당밀 감량이 먼저 제안되고, 조사료 부족으로 즉시 무너지지 않아야 합니다."
        case "엔진검증 - CP 부족":
            return "단백질 보강이 우선으로 나와야 하며, 조사료 부족이나 EE 과잉을 새로 만들지 않아야 합니다."
        case "엔진검증 - EE 과잉 + CP 부족":
            return "고지방 원료 감량 후 단백질 보강으로 이어지는 복합교정안이 나와야 합니다."
        default:
            return ""
        }
    }

    private func issueLabels(from statuses: [NutrientStatus]) -> [String] {
        statuses.compactMap { status in
            switch status.tone {
            case .adequate:
                return nil
            case .caution:
                return "\(status.nutrient) 주의"
            case .deficient:
                return "\(status.nutrient) 부족"
            case .excess:
                return "\(status.nutrient) 과잉"
            }
        }
    }

    private func regressionChecks(
        formula: FeedFormula,
        analysis: AnalysisRun,
        primaryRecommendation: Recommendation?,
        projectedStatuses: [NutrientStatus]
    ) -> [RegressionCheck] {
        guard let recommendation = primaryRecommendation else {
            return [
                RegressionCheck(
                    title: "추천안 생성",
                    passed: false,
                    detail: "대표 추천안이 생성되지 않았습니다."
                )
            ]
        }

        let correctionActions = recommendation.correctionActions
        let issueImproved = severityScore(for: projectedStatuses) < severityScore(for: analysis.statuses)
        var checks: [RegressionCheck] = [
            RegressionCheck(
                title: "복합교정안 형태",
                passed: correctionActions.count >= 2,
                detail: correctionActions.count >= 2
                    ? "교정 액션 \(correctionActions.count)개로 복합교정안 형태를 만족합니다."
                    : "현재 교정 액션이 \(correctionActions.count)개라 단일 조정에 가깝습니다."
            ),
            RegressionCheck(
                title: "적용 후 예상 개선",
                passed: issueImproved,
                detail: issueImproved
                    ? "적용 후 예상 이탈 점수가 줄어들었습니다."
                    : "적용 후 예상 이탈 점수가 충분히 줄지 않았습니다."
            )
        ]

        switch formula.name {
        case "엔진검증 - CP 과잉":
            let hasProteinDecrease = hasDecreaseAction(in: correctionActions, ingredientIDs: proteinSourceIDs)
            checks.append(
                RegressionCheck(
                    title: "단백질원 감량",
                    passed: hasProteinDecrease,
                    detail: hasProteinDecrease
                        ? "단백질 기여 원료 감량이 포함되었습니다."
                        : "단백질 기여 원료 감량이 추천안에 보이지 않습니다."
                )
            )
        case "엔진검증 - TDN 과잉":
            let hasEnergyDecrease = hasDecreaseAction(in: correctionActions, ingredientIDs: energySourceIDs)
            checks.append(
                RegressionCheck(
                    title: "에너지원 감량",
                    passed: hasEnergyDecrease,
                    detail: hasEnergyDecrease
                        ? "고에너지 원료 감량이 포함되었습니다."
                        : "고에너지 원료 감량이 추천안에 보이지 않습니다."
                )
            )
        case "엔진검증 - CP 부족":
            let hasProteinIncrease = hasIncreaseAction(in: correctionActions, ingredientIDs: proteinSourceIDs)
            checks.append(
                RegressionCheck(
                    title: "단백질원 보강",
                    passed: hasProteinIncrease,
                    detail: hasProteinIncrease
                        ? "단백질원 보강 액션이 포함되었습니다."
                        : "단백질원 보강 액션이 추천안에 보이지 않습니다."
                )
            )
        case "엔진검증 - EE 과잉 + CP 부족":
            let hasFatDecrease = hasDecreaseAction(in: correctionActions, ingredientIDs: fatHeavySourceIDs)
            let hasProteinIncrease = hasIncreaseAction(in: correctionActions, ingredientIDs: proteinSourceIDs)
            checks.append(
                RegressionCheck(
                    title: "고지방 원료 감량",
                    passed: hasFatDecrease,
                    detail: hasFatDecrease
                        ? "고지방 원료 감량이 포함되었습니다."
                        : "고지방 원료 감량이 추천안에 보이지 않습니다."
                )
            )
            checks.append(
                RegressionCheck(
                    title: "단백질원 보강 연결",
                    passed: hasProteinIncrease,
                    detail: hasProteinIncrease
                        ? "감량 후 단백질 보강이 연결되었습니다."
                        : "감량 후 단백질 보강 액션이 부족합니다."
                )
            )
        case "경기TMR 3000kg 테스트 배합":
            let caPRatioImproved = projectedStatuses.first(where: { $0.nutrient == "Ca:P" })?.tone != .deficient
            checks.append(
                RegressionCheck(
                    title: "Ca:P 우선 개선",
                    passed: caPRatioImproved,
                    detail: caPRatioImproved
                        ? "적용 후 예상에서 Ca:P 상태가 개선되었습니다."
                        : "Ca:P 비율 개선이 충분하지 않습니다."
                )
            )
        default:
            break
        }

        return checks
    }

    private func severityScore(for statuses: [NutrientStatus]) -> Int {
        statuses.reduce(0) { partial, status in
            switch status.tone {
            case .adequate:
                partial
            case .caution:
                partial + 1
            case .deficient, .excess:
                partial + 2
            }
        }
    }

    private func hasDecreaseAction(in actions: [CorrectionAction], ingredientIDs: Set<String>) -> Bool {
        actions.contains { action in
            guard action.type == .decrease, let ingredientID = action.ingredientID else { return false }
            return ingredientIDs.contains(ingredientID)
        }
    }

    private func hasIncreaseAction(in actions: [CorrectionAction], ingredientIDs: Set<String>) -> Bool {
        actions.contains { action in
            guard action.type != .decrease, let ingredientID = action.ingredientID else { return false }
            return ingredientIDs.contains(ingredientID)
        }
    }

    private static func loadUsers() -> [AppUser] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.users),
              let decoded = try? JSONDecoder().decode([AppUser].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func loadPosts() -> [CommunityPost] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.posts),
              let decoded = try? JSONDecoder().decode([CommunityPost].self, from: data) else {
            return []
        }
        return decoded.sorted(by: { $0.createdAt > $1.createdAt })
    }

    private static func seedPosts() -> [CommunityPost] {
        [
            CommunityPost(
                title: "비육전기 배합에서 수분이 높을 때",
                excerpt: "습식 원료를 바로 늘리기보다 먼저 현재 조사료 구조를 점검한 경험을 공유합니다.",
                label: "현장 팁",
                authorLoginID: "qwer123",
                authorDisplayName: "관리자"
            ),
            CommunityPost(
                title: "육성기 조사료 비율 조정 후기",
                excerpt: "반추위 발달을 위해 조사료를 유지했을 때 섭취 반응이 어떻게 달라졌는지 정리했습니다.",
                label: "후기",
                authorLoginID: "qwer123",
                authorDisplayName: "관리자"
            ),
            CommunityPost(
                title: "사육일지를 어떻게 쓰고 있는지",
                excerpt: "배합 기준과 실제 급여 차이를 기록하는 방법을 예시로 적었습니다.",
                label: "기록법",
                authorLoginID: "qwer123",
                authorDisplayName: "관리자"
            )
        ]
    }

    private func ensureAdminUser() {
        guard users.allSatisfy({ $0.loginID != "qwer123" }) else { return }
        users.append(
            AppUser(
                loginID: "qwer123",
                email: "admin@local",
                password: "asdf123",
                farmName: "관리자 계정",
                preferredStageRawValue: FarmStage.fatteningEarly.rawValue,
                selectedIngredientIDs: [],
                isAdmin: true
            )
        )
        saveUsers()
    }

    private func syncSessionFromCurrentUser() {
        guard let currentUser else {
            isAuthenticated = false
            return
        }
        isAuthenticated = true
        farmName = currentUser.farmName
        selectedStage = currentUser.preferredStage
    }

    private func saveUsers() {
        guard let data = try? JSONEncoder().encode(users) else { return }
        UserDefaults.standard.set(data, forKey: StorageKey.users)
    }

    private func savePosts() {
        guard let data = try? JSONEncoder().encode(posts) else { return }
        UserDefaults.standard.set(data, forKey: StorageKey.posts)
    }

    private func updateCurrentUser(_ mutate: (inout AppUser) -> Void) {
        guard let currentLoginID, let index = users.firstIndex(where: { $0.loginID == currentLoginID }) else { return }
        mutate(&users[index])
        saveUsers()
        syncSessionFromCurrentUser()
    }

    private func defaultFarmName(for email: String) -> String {
        let prefix = email.split(separator: "@").first.map(String.init) ?? "새 한우 농장"
        return prefix.isEmpty ? "새 한우 농장" : "\(prefix)의 한우 농장"
    }
}

@main
struct HanwooPrototypeApp: App {
    @StateObject private var store = PrototypeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task {
                    #if DEBUG
                    print("=== REGRESSION START ===")
                    for formula in store.formulas.filter(\.isTestFormula) {
                        let run = store.analysis(for: formula)
                        print(">>> [\(formula.name)]")
                        for rec in run.recommendations {
                            let acts = rec.correctionActions.map { "\($0.type)==\($0.ingredientName) \(String(format:"%.1f",$0.amountKg))kg" }.joined(separator: " / ")
                            print("    strategy=\(rec.strategy) full=\(rec.isFullyResolved) actions=[\(acts)]")
                        }
                        if run.recommendations.first?.strategy == .noSolution { print("    noSolution") }
                    }
                    print("=== REGRESSION END ===")
                    #endif
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: PrototypeStore

    var body: some View {
        Group {
            if !store.isAuthenticated {
                AuthGatewayView()
            } else if !store.hasCompletedOnboarding {
                StageOnboardingView()
            } else {
                MainTabView()
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct AuthGatewayView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var isSignupMode = false
    @State private var loginID = ""
    @State private var loginPassword = ""
    @State private var signupEmail = ""
    @State private var signupPassword = ""
    @State private var signupPasswordConfirm = ""
    @State private var emailVerificationCode = ""
    @State private var emailVerificationInput = ""
    @State private var emailVerified = false
    @State private var selectedIngredientIDs: Set<String> = []
    @State private var isShowingPassword = false
    @State private var isShowingPasswordConfirm = false
    @State private var authMessage = ""
    @State private var authError = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("한우 사육 앱")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("배합 분석, 복합교정안 추천, 사육일지 기록을 한 흐름으로 묶는 설치형 앱입니다.")
                            .foregroundStyle(.secondary)
                    }

                    Picker("모드", selection: $isSignupMode) {
                        Text("로그인").tag(false)
                        Text("회원가입").tag(true)
                    }
                    .pickerStyle(.segmented)

                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            if isSignupMode {
                                signupFields
                            } else {
                                loginFields
                            }
                        }
                        .padding(.top, 8)
                    }

                    if !authError.isEmpty {
                        Text(authError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if !authMessage.isEmpty {
                        Text(authMessage)
                            .font(.footnote)
                            .foregroundStyle(AppPalette.primary)
                    }

                    Text(helperMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .background(AppScreenBackground())
        }
    }

    private var loginFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledTextField(
                title: store.usesSupabase ? "이메일" : "이메일 또는 관리자 아이디",
                text: $loginID,
                placeholder: store.usesSupabase ? "예: farm@example.com" : "예: qwer123 또는 farm@example.com"
            )
            passwordField(
                title: "비밀번호",
                text: $loginPassword,
                isShowing: $isShowingPassword
            )
            Button("로그인") {
                submitLogin()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSubmitting)
        }
    }

    private var signupFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledTextField(title: "이메일", text: $signupEmail, placeholder: "예: farm@example.com")
            passwordField(
                title: "비밀번호",
                text: $signupPassword,
                isShowing: $isShowingPassword
            )
            passwordField(
                title: "비밀번호 재확인",
                text: $signupPasswordConfirm,
                isShowing: $isShowingPasswordConfirm
            )

            if store.usesSupabase {
                VStack(alignment: .leading, spacing: 8) {
                    Text("이메일 인증")
                        .font(.headline)
                    Text("회원가입 후 Supabase에서 실제 인증 메일을 보냅니다. 메일 확인 후 앱으로 돌아와 로그인하면 됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 10) {
                    LabeledTextField(title: "이메일 인증칸", text: $emailVerificationInput, placeholder: "인증 코드 입력")
                    Button("인증코드 생성") {
                        let email = signupEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        guard email.contains("@"), email.contains(".") else {
                            authError = "이메일 형식을 먼저 확인해 주세요."
                            authMessage = ""
                            return
                        }
                        authError = ""
                        emailVerificationCode = String(Int.random(in: 100000...999999))
                        authMessage = "프로토타입 인증코드: \(emailVerificationCode)"
                        emailVerified = false
                    }
                    .buttonStyle(.bordered)
                }

                Button(emailVerified ? "이메일 인증완료" : "이메일 인증확인") {
                    authError = ""
                    if emailVerificationInput == emailVerificationCode, !emailVerificationCode.isEmpty {
                        emailVerified = true
                        authMessage = "이메일 인증이 확인되었습니다."
                    } else {
                        emailVerified = false
                        authError = "이메일 인증코드가 맞지 않습니다."
                    }
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("자신의 원료 선택")
                        .font(.headline)
                    Spacer()
                    Text("\(selectedIngredientIDs.count)개 선택")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text("회원가입 시에만 건너뛰기가 가능하며, 선택한 원료만 배합의 원료 추가 목록에 표시됩니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(IngredientCategory.allCases) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.rawValue)
                                    .font(.subheadline.bold())
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(store.definitions(for: category)) { definition in
                                        Button {
                                            toggleIngredient(definition.id)
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: selectedIngredientIDs.contains(definition.id) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedIngredientIDs.contains(definition.id) ? AppPalette.primary : .secondary)
                                                Text(definition.name)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(selectedIngredientIDs.contains(definition.id) ? AppPalette.primary.opacity(0.10) : AppPalette.surfaceMuted)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                }
                .frame(height: 260)
            }

            HStack(spacing: 12) {
                Button("건너뛰기") {
                    submitRegistration(selectedIngredientIDs: [])
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting)

                Button("회원가입") {
                    submitRegistration(selectedIngredientIDs: Array(selectedIngredientIDs))
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSubmitting)
            }
        }
    }

    private func passwordField(title: String, text: Binding<String>, isShowing: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            HStack(spacing: 10) {
                Group {
                    if isShowing.wrappedValue {
                        TextField(title, text: text)
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField(title, text: text)
                    }
                }
                .textFieldStyle(.roundedBorder)

                Button {
                    isShowing.wrappedValue.toggle()
                } label: {
                    Image(systemName: isShowing.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func toggleIngredient(_ id: String) {
        if selectedIngredientIDs.contains(id) {
            selectedIngredientIDs.remove(id)
        } else {
            selectedIngredientIDs.insert(id)
        }
    }

    private var helperMessage: String {
        if isSignupMode {
            if store.usesSupabase {
                return "회원가입 후 실제 이메일 인증을 거쳐 로그인합니다. 회원가입 시 선택한 원료는 계정별 원료 목록으로 저장됩니다."
            }
            return "회원가입 후 사육 단계를 고르면 바로 전체 탭형 앱으로 진입합니다. 회원가입에서는 자신이 실제로 쓰는 원료만 골라서 저장할 수 있고, 건너뛰면 전체 원료를 보게 됩니다."
        }
        if store.usesSupabase {
            return "로그인은 Supabase 이메일 계정 기준입니다. 로컬 관리자 계정은 사용하지 않습니다."
        }
        return "로그인은 이메일 또는 관리자 아이디로 바로 들어갑니다. 관리자 계정은 qwer123 / asdf123 입니다."
    }

    private func submitLogin() {
        authError = ""
        authMessage = ""
        isSubmitting = true

        Task {
            let error = await store.performLogin(
                loginID: loginID.trimmingCharacters(in: .whitespacesAndNewlines),
                password: loginPassword
            )
            await MainActor.run {
                isSubmitting = false
                if let error {
                    authError = error
                }
            }
        }
    }

    private func submitRegistration(selectedIngredientIDs: [String]) {
        authError = ""
        let email = signupEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.contains("@"), email.contains(".") else {
            authError = "올바른 이메일 형식을 입력해 주세요."
            return
        }
        guard !signupPassword.isEmpty else {
            authError = "비밀번호를 입력해 주세요."
            return
        }
        guard signupPassword == signupPasswordConfirm else {
            authError = "비밀번호와 비밀번호 재확인이 일치하지 않습니다."
            return
        }
        guard store.usesSupabase || emailVerified else {
            authError = "이메일 인증을 먼저 완료해 주세요."
            return
        }
        authMessage = ""
        isSubmitting = true

        Task {
            let (outcome, error) = await store.performRegistration(
                email: email,
                password: signupPassword,
                selectedIngredientIDs: selectedIngredientIDs
            )

            await MainActor.run {
                isSubmitting = false
                if let outcome {
                    switch outcome {
                    case .signedIn:
                        authMessage = "회원가입이 완료되었습니다."
                    case .confirmationRequired:
                        authMessage = "회원가입이 접수되었습니다. 이메일 인증 후 로그인해 주세요."
                        isSignupMode = false
                    }
                } else if let error {
                    authError = error
                }
            }
        }
    }
}

struct StageOnboardingView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var selectedStage: FarmStage = .growing

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("주 사육 단계를 골라주세요")
                        .font(.largeTitle.bold())
                    Text("홈과 분석 결과에서 이 단계를 대표 기준으로 먼저 보여줍니다.")
                        .foregroundStyle(.secondary)

                    ForEach(FarmStage.allCases) { stage in
                        Button {
                            selectedStage = stage
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(stage.title)
                                        .font(.headline)
                                    Text(stage.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedStage == stage ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedStage == stage ? Color.green : .secondary)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                        }
                        .buttonStyle(.plain)
                    }

                    Button("이 단계로 시작") {
                        store.completeOnboarding(stage: selectedStage)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            NavigationStack { BlendView() }
                .tabItem {
                    Label("배합", systemImage: "carrot.fill")
                }

            NavigationStack { HistoryView() }
                .tabItem {
                    Label("최근 분석", systemImage: "clock.fill")
                }

            NavigationStack { CommunityView() }
                .tabItem {
                    Label("커뮤니티", systemImage: "bubble.left.and.bubble.right.fill")
                }

            NavigationStack { FarmView() }
                .tabItem {
                    Label("내 농장", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(AppPalette.primary)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: PrototypeStore

    private var productionFormulaCount: Int {
        store.userFacingFormulas.filter { !$0.isTestFormula }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("현장 운영 대시보드")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.primary)
                    Text(store.farmName)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(store.selectedStage?.title ?? "단계 미선택")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("배합 입력부터 분석, 교정안 확인, 일지 기록까지 한 흐름으로 빠르게 점검합니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        MetricTile(
                            title: "실제 배합",
                            value: "\(productionFormulaCount)개",
                            accent: AppPalette.primary
                        )
                        MetricTile(
                            title: "최근 분석",
                            value: "\(store.userFacingAnalyses.count)건",
                            accent: AppPalette.ink
                        )
                        MetricTile(
                            title: "사육일지",
                            value: "\(store.diaryEntries.count)건",
                            accent: AppPalette.warning
                        )
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppPalette.heroGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

                SectionCard(title: "오늘의 기준", subtitle: store.selectedStage?.summary ?? "대표 단계 기준을 아직 고르지 않았습니다") {
                    Text(store.selectedStage?.criteria.feedingNote ?? "온보딩에서 대표 단계를 선택하면 기준과 설명이 함께 표시됩니다.")
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    BlendView()
                } label: {
                    QuickActionCard(title: "배합하기", subtitle: "원료와 배합 이름을 입력하고 분석합니다", icon: "carrot.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HistoryView()
                } label: {
                    QuickActionCard(title: "최근 분석", subtitle: "저장된 배합의 분석 결과를 다시 봅니다", icon: "clock.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DiaryListView()
                } label: {
                    QuickActionCard(title: "사육일지", subtitle: "경과 기록을 추가하고 수정합니다", icon: "book.pages.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("홈")
    }
}

struct BlendView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var isShowingIngredientSheet = false

    private func binding(for id: UUID) -> Binding<FeedFormula>? {
        guard let index = store.formulas.firstIndex(where: { $0.id == id }) else { return nil }
        return $store.formulas[index]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("배합 입력")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                let currentID = store.preferredSelectedFormulaID()
                if let formula = binding(for: currentID) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("현재 작업 배합")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.primary)
                        HStack(spacing: 12) {
                            MetricTile(title: "단계", value: formula.wrappedValue.stage.title, accent: AppPalette.primary)
                            MetricTile(title: "원료 수", value: "\(formula.wrappedValue.items.count)종", accent: AppPalette.ink)
                            MetricTile(title: "유형", value: formula.wrappedValue.isTestFormula ? "테스트" : "실제", accent: AppPalette.warning)
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(AppPalette.surfaceStrong)
                    )

                    SectionCard(title: "배합 이름", subtitle: "이 배합을 구분할 이름을 적습니다") {
                        VStack(alignment: .leading, spacing: 12) {
                            if formula.wrappedValue.isTestFormula {
                                StatusPill(title: "테스트 배합", tone: .caution)
                            }
                            LabeledTextField(
                                title: "배합 이름",
                                text: formula.name,
                                placeholder: "예: 육성기 오전 배합"
                            )
                        }
                    }

                    SectionCard(title: "성장 단계 선택", subtitle: "이 배합을 어떤 기준으로 판정할지 정합니다") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("성장 단계", selection: formula.stage) {
                                ForEach(FarmStage.allCases) { stage in
                                    Text(stage.title).tag(stage)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text(formula.wrappedValue.stage.summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("원료 구성")
                            .font(.title3.bold())
                        Spacer()
                        Button("원료 추가") {
                            isShowingIngredientSheet = true
                        }
                        .font(.subheadline.weight(.semibold))
                    }

                    SectionCard(title: "원료 구성", subtitle: "배합에 들어가는 원료와 중량을 정리합니다") {
                        VStack(spacing: 14) {
                            ForEach(formula.items) { item in
                                IngredientAmountEditor(
                                    item: item,
                                    onRemove: {
                                        store.removeIngredient(from: currentID, ingredientID: item.wrappedValue.id)
                                    },
                                    defaultPricePerKg: item.wrappedValue.definitionID.flatMap {
                                        store.ingredientDefinition(id: $0)?.defaultPriceKrwPerKg
                                    }
                                )
                            }
                        }
                    }

                    if let totalCost = store.totalCostKrw(for: formula.wrappedValue) {
                        HStack {
                            Text("총 원료비 (원물 기준)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(krwString(totalCost))
                                .font(.title3.bold())
                                .foregroundStyle(Color.green)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                    }

                    NavigationLink {
                        AnalysisDetailView(formulaID: formula.wrappedValue.id)
                    } label: {
                        Text("분석 결과 보기")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("배합")
        .sheet(isPresented: $isShowingIngredientSheet) {
            let formulaID = store.preferredSelectedFormulaID()
            IngredientPickerSheet(formulaID: formulaID)
                .environmentObject(store)
        }
    }
}

struct AnalysisDetailView: View {
    @EnvironmentObject private var store: PrototypeStore
    let formulaID: UUID

    var body: some View {
        ScrollView {
            if let formula = store.formula(for: formulaID) {
                let analysis = store.analysis(for: formula)

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            Text(formula.name)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                            if formula.isTestFormula {
                                StatusPill(title: "테스트 배합", tone: .caution)
                            }
                        }

                        Text(dateTimeString(analysis.checkedAt))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(analysis.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        MetricTile(title: "수분", value: percentString(analysis.metrics.moisturePct), accent: AppPalette.primary)
                        MetricTile(title: "CP", value: percentString(analysis.metrics.cpPctDm), accent: AppPalette.ink)
                        MetricTile(title: "TDN", value: percentString(analysis.metrics.tdnPctDm), accent: AppPalette.warning)
                    }

                    SectionCard(title: "원물 투입 현황", subtitle: "원료별 원물 투입량과 건물 환산량") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("원료")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("원물량")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .trailing)
                                Text("건물량")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.bottom, 6)
                            Divider()

                            ForEach(formula.items) { item in
                                let fedKg = asFedKg(for: item)
                                let dmKg: Double? = item.definitionID
                                    .flatMap { store.ingredientDefinition(id: $0)?.nutrition.dmPct }
                                    .map { fedKg * $0 / 100 }
                                HStack {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(numberString(fedKg))kg")
                                        .font(.subheadline.monospacedDigit())
                                        .frame(width: 72, alignment: .trailing)
                                    if let dm = dmKg {
                                        Text("\(numberString(dm))kg")
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                    } else {
                                        Text("—")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                }
                                .padding(.vertical, 6)
                                Divider()
                            }

                            HStack {
                                Text("합계")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(numberString(analysis.metrics.totalAsFedKg))kg")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .frame(width: 72, alignment: .trailing)
                                Text("\(numberString(analysis.metrics.totalDmKg))kg")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(Color.green)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.top, 6)
                        }
                    }

                    SectionCard(title: "건물 기준 영양소", subtitle: "DM 기준 영양소 함량 (총 건물량 대비 %)") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            NutrientMetricCell(title: "수분", value: percentString(analysis.metrics.moisturePct))
                            NutrientMetricCell(title: "Ca:P", value: ratioString(analysis.metrics.caPRatio))
                            NutrientMetricCell(title: "CP", value: percentString(analysis.metrics.cpPctDm))
                            NutrientMetricCell(title: "TDN", value: percentString(analysis.metrics.tdnPctDm))
                            NutrientMetricCell(title: "NDF", value: percentString(analysis.metrics.ndfPctDm))
                            NutrientMetricCell(title: "ADF", value: percentString(analysis.metrics.adfPctDm))
                            NutrientMetricCell(title: "NFC", value: percentString(analysis.metrics.nfcPctDm))
                            NutrientMetricCell(title: "EE", value: percentString(analysis.metrics.eePctDm))
                            NutrientMetricCell(title: "Ca", value: percentString(analysis.metrics.caPctDm))
                            NutrientMetricCell(title: "P", value: percentString(analysis.metrics.pPctDm))
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("판정 결과")
                            .font(.title3.bold())
                        ForEach(analysis.statuses) { status in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(status.nutrient)
                                        .font(.headline)
                                    Spacer()
                                    StatusPill(title: status.tone.title, tone: status.tone)
                                }
                                Text("현재 \(status.currentValue) · 기준 \(status.targetValue)")
                                    .font(.subheadline)
                                Text(status.message)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                        }
                    }

                    NavigationLink {
                        AIRecommendationView(formulaID: formulaID)
                    } label: {
                        Text("추천안 보기")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    NavigationLink {
                        DiaryListView()
                    } label: {
                        Text("사육일지 열기")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
            }
        }
        .background(AppScreenBackground())
        .navigationTitle("분석 결과")
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: PrototypeStore

    var body: some View {
        List(store.userFacingAnalyses) { analysis in
            NavigationLink {
                AnalysisDetailView(formulaID: analysis.formulaId)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(analysis.formulaName)
                            .font(.headline)
                        if store.formula(for: analysis.formulaId)?.isTestFormula == true {
                            StatusPill(title: "테스트 배합", tone: .caution)
                        }
                    }
                    Text(analysis.stage.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(analysis.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("최근 분석")
    }
}

struct DiaryListView: View {
    @EnvironmentObject private var store: PrototypeStore

    var body: some View {
        List {
            Section {
                NavigationLink {
                    DiaryEditorView(mode: .create)
                } label: {
                    Text("오늘 기록 추가")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Section("전체 사육일지") {
                ForEach(store.diaryEntries) { entry in
                    NavigationLink {
                        DiaryDetailView(entryID: entry.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dateString(entry.date))
                                .font(.headline)
                            HStack(spacing: 8) {
                                Text(store.formula(for: entry.formulaId)?.name ?? "분석 기준 배합")
                                    .font(.subheadline)
                                if store.formula(for: entry.formulaId)?.isTestFormula == true {
                                    StatusPill(title: "테스트 배합", tone: .caution)
                                }
                            }
                            Text("변 \(entry.stoolStatus) · 성장 \(entry.growthStatus)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(entry.nextFeedback)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .navigationTitle("사육일지")
    }
}

struct DiaryDetailView: View {
    @EnvironmentObject private var store: PrototypeStore
    let entryID: UUID

    var body: some View {
        ScrollView {
            if let entry = store.diaryEntries.first(where: { $0.id == entryID }),
               let formula = store.formula(for: entry.formulaId) {
                VStack(alignment: .leading, spacing: 20) {
                    SectionCard(title: "분석 기준 배합", subtitle: formula.name) {
                        VStack(alignment: .leading, spacing: 8) {
                            if formula.isTestFormula {
                                StatusPill(title: "테스트 배합", tone: .caution)
                            }
                            Text(formula.items.map { "\($0.name) \(formattedAmount($0))" }.joined(separator: " · "))
                                .font(.headline)
                        }
                        Text("이 배합을 기준으로 실제 급여와 경과를 수기로 기록하는 구조입니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    SectionCard(title: dateString(entry.date), subtitle: "기록 상세") {
                        DetailRow(title: "변 상태", value: entry.stoolStatus)
                        DetailRow(title: "성장 속도", value: entry.growthStatus)
                        DetailRow(title: "다음 피드백", value: entry.nextFeedback)
                        DetailRow(title: "자유 기록", value: entry.note)
                    }

                    NavigationLink {
                        DiaryEditorView(mode: .edit(entryID))
                    } label: {
                        Text("기록 수정")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("기록 상세")
    }
}

struct DiaryEditorView: View {
    enum Mode {
        case create
        case edit(UUID)
    }

    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var selectedFormulaID: UUID?
    @State private var date = Date.now
    @State private var stoolStatus = ""
    @State private var growthStatus = ""
    @State private var nextFeedback = ""
    @State private var note = ""
    @State private var editingID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(modeTitle)
                    .font(.largeTitle.bold())

                SectionCard(title: "배합비 선택", subtitle: "분석 기준 배합 1개를 연결합니다") {
                    VStack(spacing: 12) {
                        ForEach(store.userFacingFormulas) { formula in
                            Button {
                                selectedFormulaID = formula.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text(formula.name)
                                                .font(.headline)
                                            if formula.isTestFormula {
                                                StatusPill(title: "테스트 배합", tone: .caution)
                                            }
                                        }
                                        Text(formula.items.map { "\($0.name) \(formattedAmount($0))" }.joined(separator: " · "))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: selectedFormulaID == formula.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedFormulaID == formula.id ? Color.green : .secondary)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(.secondarySystemBackground))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SectionCard(title: "글쓰기", subtitle: "경과를 직접 기록합니다") {
                    VStack(spacing: 16) {
                        DatePicker("기록 날짜", selection: $date, displayedComponents: .date)

                        LabeledTextField(title: "변 상태", text: $stoolStatus, placeholder: "예: 약간 무름")
                        LabeledTextField(title: "성장 속도", text: $growthStatus, placeholder: "예: 무난")
                        LabeledTextField(title: "다음 피드백", text: $nextFeedback, placeholder: "예: 옥수수 1kg 낮춰보기")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("자유 기록")
                                .font(.headline)
                            TextEditor(text: $note)
                                .frame(height: 140)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                        }
                    }
                }

                Button(modeButtonTitle) {
                    save()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: loadIfNeeded)
    }

    private var modeTitle: String {
        switch mode {
        case .create: "기록 추가"
        case .edit: "기록 수정"
        }
    }

    private var modeButtonTitle: String {
        switch mode {
        case .create: "기록 저장"
        case .edit: "수정 저장"
        }
    }

    private func loadIfNeeded() {
        switch mode {
        case .create:
            if selectedFormulaID == nil {
                selectedFormulaID = store.preferredSelectedFormulaID()
            }
        case let .edit(entryID):
            guard let entry = store.diaryEntries.first(where: { $0.id == entryID }) else { return }
            editingID = entry.id
            selectedFormulaID = entry.formulaId
            date = entry.date
            stoolStatus = entry.stoolStatus
            growthStatus = entry.growthStatus
            nextFeedback = entry.nextFeedback
            note = entry.note
        }
    }

    private func save() {
        guard let formulaID = selectedFormulaID else { return }
        let entry = DiaryEntry(
            id: editingID ?? UUID(),
            date: date,
            formulaId: formulaID,
            stoolStatus: stoolStatus.isEmpty ? "미입력" : stoolStatus,
            growthStatus: growthStatus.isEmpty ? "미입력" : growthStatus,
            nextFeedback: nextFeedback.isEmpty ? "다음 기록 때 보완" : nextFeedback,
            note: note.isEmpty ? "현장 기록이 아직 없습니다." : note,
            lastUpdatedAt: .now
        )
        store.saveDiary(entry)
        dismiss()
    }
}

struct CommunityView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var isShowingComposer = false
    @State private var communityError = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("커뮤니티")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("첫 설치형 프로토타입에서는 읽기 중심 화면으로 둡니다.")
                    .foregroundStyle(.secondary)

                ForEach(store.posts) { post in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                StatusPill(title: post.label, tone: .adequate)
                                Text(post.title)
                                    .font(.headline)
                                Text(post.excerpt)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("\(post.authorDisplayName) · \(dateString(post.createdAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.canDelete(post: post) {
                                Button(role: .destructive) {
                                    Task {
                                        if let error = await store.performDeletePost(id: post.id) {
                                            await MainActor.run {
                                                communityError = error
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(AppPalette.surface)
                    )
                }

                if !communityError.isEmpty {
                    Text(communityError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("커뮤니티")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("글쓰기") {
                    isShowingComposer = true
                }
            }
        }
        .sheet(isPresented: $isShowingComposer) {
            CommunityPostComposerView()
                .environmentObject(store)
        }
    }
}

struct CommunityPostComposerView: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var excerpt = ""
    @State private var label = "현장 팁"
    @State private var submitError = ""
    @State private var isSubmitting = false

    private let labels = ["현장 팁", "후기", "기록법", "질문"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionCard(title: "커뮤니티 글쓰기", subtitle: "제목, 본문 요약, 분류를 입력합니다") {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledTextField(title: "제목", text: $title, placeholder: "예: 비지 비중을 낮췄을 때 반응")
                            VStack(alignment: .leading, spacing: 8) {
                                Text("분류")
                                    .font(.headline)
                                Picker("분류", selection: $label) {
                                    ForEach(labels, id: \.self) { item in
                                        Text(item).tag(item)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("요약")
                                    .font(.headline)
                                TextEditor(text: $excerpt)
                                    .frame(height: 180)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                            }
                        }
                    }

                    Button("등록") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedExcerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedTitle.isEmpty, !trimmedExcerpt.isEmpty else { return }
                        isSubmitting = true
                        submitError = ""
                        Task {
                            let error = await store.performCreatePost(title: trimmedTitle, excerpt: trimmedExcerpt, label: label)
                            await MainActor.run {
                                isSubmitting = false
                                if let error {
                                    submitError = error
                                } else {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSubmitting)

                    if !submitError.isEmpty {
                        Text(submitError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(AppScreenBackground())
            .navigationTitle("글쓰기")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

private extension FeedFormula {
    var formulaTypeLabel: String {
        isTestFormula ? "테스트 배합" : "실제 배합"
    }
}

struct FarmView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var isLoggingOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionCard(title: store.farmName, subtitle: store.selectedStage?.title ?? "단계 미선택") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("최근 분석과 사육일지를 이곳에서 다시 확인합니다.")
                        if let currentUser = store.currentUser {
                            Text("로그인 계정: \(currentUser.loginID)\(currentUser.isAdmin ? " · 관리자" : "")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    DiaryListView()
                } label: {
                    QuickActionCard(title: "사육일지", subtitle: "기록 추가와 수정", icon: "book.closed.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HistoryView()
                } label: {
                    QuickActionCard(title: "최근 분석", subtitle: "배합 기준 다시 보기", icon: "chart.bar.doc.horizontal.fill")
                }
                .buttonStyle(.plain)

                if store.currentUser?.isAdmin == true {
                    NavigationLink {
                        RegressionSuiteView()
                    } label: {
                        QuickActionCard(title: "엔진 검증", subtitle: "테스트 배합 7종의 추천안 방향 확인", icon: "checklist.checked")
                    }
                    .buttonStyle(.plain)
                }

                Button("로그아웃") {
                    isLoggingOut = true
                    Task {
                        await store.performLogout()
                        await MainActor.run {
                            isLoggingOut = false
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoggingOut)
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("내 농장")
    }
}

struct IngredientPickerSheet: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss

    let formulaID: UUID

    var body: some View {
        NavigationStack {
            List {
                ForEach(IngredientCategory.allCases) { category in
                    let defs = store.availableDefinitions(for: category)
                    NavigationLink {
                        IngredientCategoryListView(
                            category: category,
                            formulaID: formulaID,
                            onAdded: { dismiss() }
                        )
                        .environmentObject(store)
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundStyle(Color.green)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.rawValue)
                                    .font(.headline)
                                Text("\(defs.count)종")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("기타") {
                    NavigationLink {
                        CustomIngredientInputView(formulaID: formulaID, onAdded: { dismiss() })
                            .environmentObject(store)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            Text("직접 입력")
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("원료 분류")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

}

struct RegressionSuiteView: View {
    @EnvironmentObject private var store: PrototypeStore

    var body: some View {
        let results = store.regressionSuiteResults()

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionCard(
                    title: "엔진 검증",
                    subtitle: "\(results.count)개 테스트 배합"
                ) {
                    let passedCount = results.filter(\.overallPassed).count
                    Text("복합교정안이 기대 방향과 맞는지 테스트 배합으로 빠르게 확인합니다.")
                        .foregroundStyle(.secondary)
                    Text("통과 \(passedCount) / \(results.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(passedCount == results.count ? Color.green : Color.orange)
                }

                ForEach(results) { result in
                    SectionCard(title: result.formula.name, subtitle: result.formula.stage.title) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                StatusPill(title: "테스트 배합", tone: .caution)
                                StatusPill(title: result.overallPassed ? "통과" : "점검 필요", tone: result.overallPassed ? .adequate : .excess)
                            }

                            Text(result.expectationSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if !result.currentIssues.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("현재 주요 이탈")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(result.currentIssues.joined(separator: ", "))
                                        .font(.subheadline)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("기본 추천안")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                if let recommendation = result.primaryRecommendation {
                                    Text(recommendation.title)
                                        .font(.subheadline.weight(.semibold))
                                    if !recommendation.correctionActions.isEmpty {
                                        ForEach(recommendation.correctionActions) { action in
                                            Text(correctionActionLabel(action))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } else {
                                    Text("추천안 생성 실패")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.red)
                                }
                            }

                            if !result.projectedIssues.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("적용 후 예상 이탈")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(result.projectedIssues.joined(separator: ", "))
                                        .font(.subheadline)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("검증 체크")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(result.checks) { check in
                                    HStack(alignment: .top, spacing: 8) {
                                        StatusPill(title: check.passed ? "통과" : "실패", tone: check.tone)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(check.title)
                                                .font(.subheadline.weight(.semibold))
                                            Text(check.detail)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }

                            NavigationLink {
                                AIRecommendationView(formulaID: result.formula.id)
                            } label: {
                                Text("추천안 상세 보기")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("엔진 검증")
    }
}

struct IngredientCategoryListView: View {
    @EnvironmentObject private var store: PrototypeStore
    let category: IngredientCategory
    let formulaID: UUID
    let onAdded: () -> Void

    var body: some View {
        List(store.availableDefinitions(for: category)) { definition in
            Button {
                store.addIngredient(to: formulaID, definition: definition)
                onAdded()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(definition.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(definition.defaultPriceKrwPerKg)원/kg")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        NutrientBadge(label: "수분", value: "\(numberString(definition.nutrition.moisturePct))%")
                        NutrientBadge(label: "CP", value: "\(numberString(definition.nutrition.cpPctDm))%")
                        NutrientBadge(label: "TDN", value: "\(numberString(definition.nutrition.tdnPctDm))%")
                        NutrientBadge(label: "NDF", value: "\(numberString(definition.nutrition.ndfPctDm))%")
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(category.rawValue)
    }
}

struct CustomIngredientInputView: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss
    let formulaID: UUID
    let onAdded: () -> Void
    @State private var customName = ""

    var body: some View {
        List {
            Section("원료명 입력") {
                TextField("예: 청보리 사일리지", text: $customName)
                    .textInputAutocapitalization(.never)
            }
            Section {
                Button("추가 (10kg 기본)") {
                    let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.addCustomIngredient(to: formulaID, name: trimmed)
                    onAdded()
                }
                .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("직접 입력한 원료는 성분 DB와 연결되지 않아 영양소 계산에서 제외됩니다.")
            }
        }
        .navigationTitle("직접 입력")
    }
}

struct NutrientBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
    }
}

struct IngredientAmountEditor: View {
    @Binding var item: IngredientLine
    let onRemove: () -> Void
    let defaultPricePerKg: Int?

    private var amountText: Binding<String> {
        Binding(
            get: {
                if item.amount == 0 { return "" }
                if item.amount.rounded() == item.amount { return String(Int(item.amount)) }
                return String(item.amount)
            },
            set: { newValue in
                let filtered = filteredDecimal(newValue)
                if filtered.isEmpty { item.amount = 0 }
                else if let value = Double(filtered) { item.amount = value }
            }
        )
    }

    private var priceText: Binding<String> {
        Binding(
            get: {
                let price = item.priceOverrideKrwPerKg ?? defaultPricePerKg
                return price.map { String($0) } ?? ""
            },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                item.priceOverrideKrwPerKg = Int(filtered)
            }
        )
    }

    private var effectivePricePerKg: Int? {
        item.priceOverrideKrwPerKg ?? defaultPricePerKg
    }

    private var subtotalKrw: Int? {
        guard let price = effectivePricePerKg else { return nil }
        return Int(asFedKg(for: item) * Double(price))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.name)
                    .font(.headline)
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
            }

            HStack(spacing: 10) {
                TextField("0", text: amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                    .frame(maxWidth: .infinity)

                Picker("단위", selection: $item.unit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }

            HStack(spacing: 8) {
                Image(systemName: "wonsign")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("단가 (원/kg)", text: priceText)
                    .keyboardType(.numberPad)
                    .font(.subheadline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))

                if let subtotal = subtotalKrw {
                    Text("= \(krwString(subtotal))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.green)
                }
            }

            if item.priceOverrideKrwPerKg == nil, defaultPricePerKg != nil {
                Text("기본단가 \(krwString(defaultPricePerKg!)) 적용 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppPalette.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppPalette.primary.opacity(0.14)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
    }
}

struct StatusPill: View {
    let title: String
    let tone: StatusTone

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tone.color.opacity(0.12))
            .foregroundStyle(tone.color)
            .clipShape(Capsule())
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppPalette.primary.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .shadow(color: AppPalette.primary.opacity(0.25), radius: 14, x: 0, y: 10)
    }
}

private func dateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter.string(from: date)
}

private func dateTimeString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 HH:mm"
    return formatter.string(from: date)
}

private func filteredDecimal(_ value: String) -> String {
    var result = ""
    var hasDecimalPoint = false

    for character in value {
        if character.isNumber {
            result.append(character)
        } else if character == ".", !hasDecimalPoint {
            hasDecimalPoint = true
            result.append(character)
        }
    }

    return result
}

private func formattedAmount(_ item: IngredientLine) -> String {
    let amountText: String
    if item.amount.rounded() == item.amount {
        amountText = String(Int(item.amount))
    } else {
        amountText = String(format: "%.1f", item.amount)
    }
    return "\(amountText)\(item.unit.rawValue)"
}

func asFedKg(for item: IngredientLine) -> Double {
    switch item.unit {
    case .kg:
        return item.amount
    case .g:
        return item.amount / 1000
    }
}

func nutrientKg(dmKg: Double, pctDm: Double) -> Double {
    dmKg * pctDm / 100
}

func pctDm(_ nutrientKg: Double, _ totalDmKg: Double) -> Double {
    guard totalDmKg > 0 else { return 0 }
    return nutrientKg / totalDmKg * 100
}

func numberString(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }
    return String(format: "%.1f", value)
}

func percentString(_ value: Double) -> String {
    "\(numberString(value))%"
}

func ratioString(_ value: Double) -> String {
    "\(numberString(value)) : 1"
}

func quantityString(_ value: Double) -> String {
    "\(numberString(value))kg"
}

func minimumString(_ value: Double) -> String {
    "\(numberString(value))% 이상"
}

func maximumString(_ value: Double) -> String {
    "\(numberString(value))% 이하"
}

func rangeString(_ minimum: Double, _ maximum: Double) -> String {
    "\(numberString(minimum)) ~ \(numberString(maximum))%"
}

func ratioRangeString(_ minimum: Double, _ maximum: Double) -> String {
    "\(numberString(minimum)) ~ \(numberString(maximum)) : 1"
}

func kgRangeString(_ minimum: Double, _ maximum: Double) -> String {
    "\(numberString(minimum)) ~ \(numberString(maximum))kg"
}

func krwString(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "ko_KR")
    return (formatter.string(from: NSNumber(value: value)) ?? "\(value)") + "원"
}

func correctionActionLabel(_ action: CorrectionAction) -> String {
    let prefix: String
    switch action.type {
    case .decrease:
        prefix = "-"
    case .increase, .add:
        prefix = "+"
    }
    return "\(action.ingredientName) \(prefix)\(action.displayAmount)"
}

let proteinSourceIDs: Set<String> = [
    "CUSTOM_SOYBEAN_MEAL",
    "FEED_23",
    "FEED_24",
    "FEED_25",
    "FEED_31",
    "FEED_45",
    "FEED_201",
    "FEED_208",
    "FEED_209",
    "FEED_210",
    "FEED_217",
    "FEED_218",
    "FEED_219",
    "FEED_220",
    "FEED_222",
    "FEED_91"
]

let energySourceIDs: Set<String> = [
    "FEED_4",
    "FEED_7",
    "FEED_8",
    "FEED_33",
    "FEED_37",
    "FEED_211"
]

let fatHeavySourceIDs: Set<String> = [
    "FEED_200",
    "FEED_16",
    "FEED_29",
    "FEED_32",
    "FEED_48",
    "FEED_49",
    "FEED_207",
    "FEED_215",
    "FEED_216",
    "FEED_217",
    "FEED_218",
    "FEED_220"
]

func defaultRecommendation(from recommendations: [Recommendation]) -> Recommendation? {
    recommendations.max { lhs, rhs in
        if lhs.isFullyResolved != rhs.isFullyResolved {
            return !lhs.isFullyResolved && rhs.isFullyResolved
        }

        if lhs.isReferenceOnly != rhs.isReferenceOnly {
            return lhs.isReferenceOnly && !rhs.isReferenceOnly
        }

        if abs(lhs.resolutionRate - rhs.resolutionRate) > 0.03 {
            return lhs.resolutionRate < rhs.resolutionRate
        }

        if lhs.correctionActions.count != rhs.correctionActions.count {
            return lhs.correctionActions.count > rhs.correctionActions.count
        }

        if abs(lhs.costDeltaKrw) != abs(rhs.costDeltaKrw) {
            return abs(lhs.costDeltaKrw) > abs(rhs.costDeltaKrw)
        }

        let preferredOrder: [RecommendationStrategy] = [.ownedFirst, .costEffective, .maintenance, .noSolution]
        let lhsIndex = preferredOrder.firstIndex(of: lhs.strategy) ?? preferredOrder.count
        let rhsIndex = preferredOrder.firstIndex(of: rhs.strategy) ?? preferredOrder.count
        return lhsIndex > rhsIndex
    }
}

func thresholdTone(
    _ value: Double,
    minimum: Double,
    maximum: Double,
    cautionMinimum: Double,
    cautionMaximum: Double
) -> StatusTone {
    // Non-overlapping bands:
    // deficient: value < cautionMinimum
    // caution-low: cautionMinimum <= value < minimum
    // adequate: minimum <= value <= maximum
    // caution-high: maximum < value <= cautionMaximum
    // excess: value > cautionMaximum
    if value < cautionMinimum {
        return .deficient
    }
    if value < minimum {
        return .caution
    }
    if value <= maximum {
        return .adequate
    }
    if value <= cautionMaximum {
        return .caution
    }
    return .excess
}

func upperThresholdTone(_ value: Double, recommendedMaximum: Double, cautionMaximum: Double) -> StatusTone {
    if value <= recommendedMaximum {
        return .adequate
    }
    if value <= cautionMaximum {
        return .caution
    }
    return .excess
}

func moistureTone(_ moisturePct: Double, criteria: StageCriteria) -> StatusTone {
    thresholdTone(
        moisturePct,
        minimum: criteria.moistureMinimumPct,
        maximum: criteria.moistureMaximumPct,
        cautionMinimum: criteria.moistureCautionMinimumPct,
        cautionMaximum: criteria.moistureCautionMaximumPct
    )
}

func moistureMessage(_ moisturePct: Double, criteria: StageCriteria) -> String {
    let target = rangeString(criteria.moistureMinimumPct, criteria.moistureMaximumPct)
    let tone = moistureTone(moisturePct, criteria: criteria)
    switch tone {
    case .adequate:
        return "수분 수준이 적정합니다. (\(numberString(moisturePct))% vs 기준 \(target))"
    case .caution:
        if moisturePct < criteria.moistureMinimumPct {
            return "수분이 살짝 낮습니다. (\(numberString(moisturePct))% vs 기준 \(target)) 혼합 균일성과 기호성을 위해 수분 구성 조정을 고려해보세요."
        }
        return "수분이 살짝 높습니다. (\(numberString(moisturePct))% vs 기준 \(target)) 습식 원료 비중과 저장 안정성 점검을 권장합니다."
    case .deficient:
        return "수분이 부족합니다. (\(numberString(moisturePct))% vs 기준 \(target)) 혼합성과 섭취 균일성 점검이 필요합니다."
    case .excess:
        return "수분이 과잉입니다. (\(numberString(moisturePct))% vs 기준 \(target)) 변패와 저장 안정성 문제를 막기 위해 배합 수분 구성 점검이 필요합니다."
    }
}

func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
    min(max(value, lower), upper)
}

func rangeDistance(_ value: Double, minimum: Double, maximum: Double) -> Double {
    if value < minimum { return minimum - value }
    if value > maximum { return value - maximum }
    return 0
}

func caPRatioDistance(_ ratio: Double, criteria: StageCriteria) -> Double {
    rangeDistance(ratio, minimum: criteria.caPRatioMin, maximum: criteria.caPRatioMax)
}

struct MetricTile: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }
}

struct NutrientMetricCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppPalette.surfaceMuted)
        )
    }
}

enum AppPalette {
    static let primary = Color(red: 0.12, green: 0.51, blue: 0.28)
    static let ink = Color(red: 0.10, green: 0.18, blue: 0.14)
    static let warning = Color(red: 0.79, green: 0.48, blue: 0.09)
    static let canvas = Color(red: 0.95, green: 0.96, blue: 0.92)
    static let surface = Color.white.opacity(0.92)
    static let surfaceMuted = Color(red: 0.96, green: 0.97, blue: 0.94)
    static let surfaceStrong = Color(red: 0.93, green: 0.96, blue: 0.90)
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.83, green: 0.92, blue: 0.78),
            Color(red: 0.96, green: 0.94, blue: 0.84)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppScreenBackground: View {
    var body: some View {
        ZStack {
            AppPalette.canvas
            LinearGradient(
                colors: [
                    Color.white.opacity(0.55),
                    Color(red: 0.89, green: 0.93, blue: 0.87).opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 280, height: 280)
                .offset(x: 150, y: -240)
            Circle()
                .fill(AppPalette.primary.opacity(0.08))
                .frame(width: 360, height: 360)
                .offset(x: -180, y: 260)
        }
        .ignoresSafeArea()
    }
}

struct ComparisonRow: View {
    let title: String
    let current: String
    let projected: String
    let projectedTone: StatusTone

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(current)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack(spacing: 6) {
                Text(projected)
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.primary)
                StatusPill(title: projectedTone.title, tone: projectedTone)
            }
        }
    }
}

struct BulletLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(Color.secondary)
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
