import SwiftUI
import OSLog

@MainActor
final class PrototypeStore: ObservableObject {
    let supabaseService = SupabaseService()
    let debugLogger = Logger(subsystem: "com.jowm.HanwooPrototype", category: "RegressionRecommendations")

    // MARK: - 영속화 Repository (UserDefaults 구현은 Repositories.swift)
    let userRepository: UserRepository
    let postRepository: PostRepository
    let userIngredientRepository: UserIngredientRepository
    let formulaRepository: FormulaRepository
    let analysisHistoryRepository: AnalysisHistoryRepository
    let purchaseRepository: PurchaseRepository

    /// 분석 결과 캐시.
    /// analysis(for:)는 교정 엔진(좌표하강 + 재시작 탐색)을 돌리므로 한 번 계산이 무겁다.
    /// SwiftUI는 body를 자주 다시 그리므로 캐시가 없으면 같은 배합을 반복해서 다시 푼다.
    /// 키는 배합의 내용이며, 원료·투입량·단계가 하나라도 바뀌면 자동으로 무효화된다.
    var analysisCache: [String: AnalysisRun] = [:]

    // MARK: - 원료 DB (수집/정제된 실데이터 기반, 가격은 카테고리별 기본값)
    let ingredientDefinitions: [IngredientDefinition] = PrototypeStore.ingredientCatalog

    @Published var isAuthenticated = false
    @Published var selectedStage: FarmStage?
    @Published var farmName = "행복한 한우 농장"
    // 배합은 수정 즉시 자동 저장된다(초안 복구). 시드 테스트 배합은 저장 대상에서 제외.
    @Published var formulas: [FeedFormula] {
        didSet { formulaRepository.saveFormulas(formulas.filter { !$0.isTestFormula }) }
    }
    // 저장된 분석 이력. 변경 즉시 영속화.
    @Published var savedAnalyses: [SavedAnalysis] {
        didSet { analysisHistoryRepository.saveAnalyses(savedAnalyses) }
    }
    // 원료 구매 기록(가계부). 변경 즉시 영속화.
    @Published var purchases: [FeedPurchase] {
        didSet { purchaseRepository.savePurchases(purchases) }
    }
    @Published var diaryEntries: [DiaryEntry]
    @Published var posts: [CommunityPost]
    @Published var userIngredientDefinitions: [UserIngredientDefinition]
    @Published var selectedFormulaID: UUID
    @Published var users: [AppUser]
    @Published var currentLoginID: String?

    init() {
        let userRepo = UserDefaultsUserRepository()
        let postRepo = UserDefaultsPostRepository()
        let ingredientRepo = UserDefaultsUserIngredientRepository()
        let formulaRepo = UserDefaultsFormulaRepository()
        let historyRepo = UserDefaultsAnalysisHistoryRepository()
        let purchaseRepo = UserDefaultsPurchaseRepository()
        self.userRepository = userRepo
        self.postRepository = postRepo
        self.userIngredientRepository = ingredientRepo
        self.formulaRepository = formulaRepo
        self.analysisHistoryRepository = historyRepo
        self.purchaseRepository = purchaseRepo
        self.users = supabaseService.isConfigured ? [] : userRepo.loadUsers()
        self.currentLoginID = supabaseService.isConfigured ? nil : userRepo.loadCurrentLoginID()
        self.userIngredientDefinitions = ingredientRepo.loadUserIngredients()
        self.savedAnalyses = historyRepo.loadAnalyses()
        self.purchases = purchaseRepo.loadPurchases()
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

        let formulaH = FeedFormula(
            name: "농가 배합 테스트",
            stage: .fatteningEarly,
            items: [
                IngredientLine(name: "제과부산물", definitionID: "FEED_48", amount: 100),
                IngredientLine(name: "옥수수 주정박", definitionID: "FEED_33", amount: 90),
                IngredientLine(name: "쌀겨(생미강)", definitionID: "FEED_16", amount: 60),
                IngredientLine(name: "파쇄옥수수", definitionID: "FEED_4", amount: 125),
                IngredientLine(name: "소맥피(밀기울)", definitionID: "FEED_212", amount: 40),
                IngredientLine(name: "도토리박", definitionID: "FEED_38", amount: 20),
                IngredientLine(name: "들깻묵(임자박)", definitionID: "FEED_26", amount: 15),
                IngredientLine(name: "석회석", definitionID: "FEED_109", amount: 10),
                IngredientLine(name: "벤토나이트", definitionID: nil, amount: 5),
                IngredientLine(name: "소금", definitionID: "FEED_110", amount: 10),
                IngredientLine(name: "이스트컬쳐", definitionID: "CUSTOM_YEAST_CULTURE", amount: 1),
                IngredientLine(name: "물", definitionID: nil, amount: 70),
                IngredientLine(name: "이탈리안라이그라스사일리지(출수기)", definitionID: "FEED_73", amount: 90),
            ],
            checkedAt: .now
        )

        // 저장된 사용자 배합이 있으면 복원하고, 없으면 기본 시드를 사용한다.
        // 엔진 검증용 테스트 배합(C~G)은 항상 코드 시드에서 온다.
        let savedUserFormulas = formulaRepo.loadFormulas()
        let userFormulas = savedUserFormulas.isEmpty ? [formulaA, formulaB, formulaH] : savedUserFormulas
        self.formulas = userFormulas + [formulaC, formulaD, formulaE, formulaF, formulaG]
        self.selectedFormulaID = userFormulas.first?.id ?? formulaA.id

        // 시작 시 회귀 배합을 자동 실행하던 코드를 제거했다.
        // 실행할 때마다 테스트 배합 5종에 교정 엔진을 돌려 첫 화면이 그만큼 늦어졌다.
        // 회귀 확인은 내 농장 > 엔진 검증 화면에서 필요할 때만 한다.
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
        self.posts = supabaseService.isConfigured ? [] : postRepo.loadPosts()
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

}
