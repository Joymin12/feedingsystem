import Foundation
import OSLog

// MARK: - 영속화 Repository 프로토콜
// 저장소를 프로토콜 뒤로 숨겨, 추후 SwiftData/CoreData/서버 동기화로 교체하더라도
// 계산/추천 엔진이나 스토어 로직을 다시 쓰지 않도록 한다.
// 현재 구현은 UserDefaults 기반이며 기존 저장 키/포맷을 그대로 유지한다.

protocol UserRepository {
    func loadUsers() -> [AppUser]
    func saveUsers(_ users: [AppUser])
    func loadCurrentLoginID() -> String?
    func saveCurrentLoginID(_ loginID: String?)
}

protocol PostRepository {
    func loadPosts() -> [CommunityPost]
    func savePosts(_ posts: [CommunityPost])
}

protocol UserIngredientRepository {
    func loadUserIngredients() -> [UserIngredientDefinition]
    func saveUserIngredients(_ ingredients: [UserIngredientDefinition])
}

protocol FormulaRepository {
    func loadFormulas() -> [FeedFormula]
    func saveFormulas(_ formulas: [FeedFormula])
}

protocol AnalysisHistoryRepository {
    func loadAnalyses() -> [SavedAnalysis]
    func saveAnalyses(_ analyses: [SavedAnalysis])
}

protocol PurchaseRepository {
    func loadPurchases() -> [FeedPurchase]
    func savePurchases(_ purchases: [FeedPurchase])
}

// 배열 디코딩 시 손상된 레코드 하나 때문에 전체를 잃지 않도록 요소 단위로 복구한다.
// 디코딩에 실패한 요소는 건너뛰고 로그만 남긴다.
private struct FailableRecord<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) {
        value = try? T(from: decoder)
    }
}

private let repositoryLogger = Logger(subsystem: "com.jowm.HanwooPrototype", category: "Persistence")

private func decodeRecords<T: Decodable>(_ type: T.Type, from data: Data, label: String) -> [T] {
    let decoder = JSONDecoder()
    if let decoded = try? decoder.decode([T].self, from: data) {
        return decoded
    }
    guard let partial = try? decoder.decode([FailableRecord<T>].self, from: data) else {
        repositoryLogger.error("\(label, privacy: .public) 저장 데이터를 해석할 수 없어 빈 목록으로 시작합니다.")
        return []
    }
    let values = partial.compactMap(\.value)
    let dropped = partial.count - values.count
    if dropped > 0 {
        repositoryLogger.error("\(label, privacy: .public) 레코드 \(dropped)건이 손상되어 건너뛰었습니다. (\(values.count)건 복구)")
    }
    return values
}

// MARK: - UserDefaults 구현

private enum StorageKey {
    static let users = "hanwoo.prototype.users"
    static let currentLoginID = "hanwoo.prototype.currentLoginID"
    static let posts = "hanwoo.prototype.posts"
    static let userIngredients = "hanwoo.prototype.userIngredients"
    static let formulas = "hanwoo.prototype.formulas"
    static let analysisHistory = "hanwoo.prototype.analysisHistory"
    static let purchases = "hanwoo.prototype.purchases"
}

struct UserDefaultsUserRepository: UserRepository {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadUsers() -> [AppUser] {
        guard let data = defaults.data(forKey: StorageKey.users),
              let decoded = try? JSONDecoder().decode([AppUser].self, from: data) else {
            return []
        }
        return decoded
    }

    func saveUsers(_ users: [AppUser]) {
        guard let data = try? JSONEncoder().encode(users) else { return }
        defaults.set(data, forKey: StorageKey.users)
    }

    func loadCurrentLoginID() -> String? {
        defaults.string(forKey: StorageKey.currentLoginID)
    }

    func saveCurrentLoginID(_ loginID: String?) {
        if let loginID {
            defaults.set(loginID, forKey: StorageKey.currentLoginID)
        } else {
            defaults.removeObject(forKey: StorageKey.currentLoginID)
        }
    }
}

struct UserDefaultsPostRepository: PostRepository {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPosts() -> [CommunityPost] {
        guard let data = defaults.data(forKey: StorageKey.posts),
              let decoded = try? JSONDecoder().decode([CommunityPost].self, from: data) else {
            return []
        }
        return decoded.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func savePosts(_ posts: [CommunityPost]) {
        guard let data = try? JSONEncoder().encode(posts) else { return }
        defaults.set(data, forKey: StorageKey.posts)
    }
}

struct UserDefaultsFormulaRepository: FormulaRepository {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadFormulas() -> [FeedFormula] {
        guard let data = defaults.data(forKey: StorageKey.formulas) else { return [] }
        return decodeRecords(FeedFormula.self, from: data, label: "배합")
    }

    func saveFormulas(_ formulas: [FeedFormula]) {
        guard let data = try? JSONEncoder().encode(formulas) else {
            repositoryLogger.error("배합 저장 인코딩에 실패했습니다.")
            return
        }
        defaults.set(data, forKey: StorageKey.formulas)
    }
}

struct UserDefaultsAnalysisHistoryRepository: AnalysisHistoryRepository {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAnalyses() -> [SavedAnalysis] {
        guard let data = defaults.data(forKey: StorageKey.analysisHistory) else { return [] }
        return decodeRecords(SavedAnalysis.self, from: data, label: "분석 이력")
    }

    func saveAnalyses(_ analyses: [SavedAnalysis]) {
        guard let data = try? JSONEncoder().encode(analyses) else {
            repositoryLogger.error("분석 이력 저장 인코딩에 실패했습니다.")
            return
        }
        defaults.set(data, forKey: StorageKey.analysisHistory)
    }
}

struct UserDefaultsPurchaseRepository: PurchaseRepository {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPurchases() -> [FeedPurchase] {
        guard let data = defaults.data(forKey: StorageKey.purchases) else { return [] }
        return decodeRecords(FeedPurchase.self, from: data, label: "원료 구매 기록")
    }

    func savePurchases(_ purchases: [FeedPurchase]) {
        guard let data = try? JSONEncoder().encode(purchases) else {
            repositoryLogger.error("원료 구매 기록 저장 인코딩에 실패했습니다.")
            return
        }
        defaults.set(data, forKey: StorageKey.purchases)
    }
}

struct UserDefaultsUserIngredientRepository: UserIngredientRepository {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadUserIngredients() -> [UserIngredientDefinition] {
        guard let data = defaults.data(forKey: StorageKey.userIngredients),
              let decoded = try? JSONDecoder().decode([UserIngredientDefinition].self, from: data) else {
            return []
        }
        return decoded
    }

    func saveUserIngredients(_ ingredients: [UserIngredientDefinition]) {
        guard let data = try? JSONEncoder().encode(ingredients) else { return }
        defaults.set(data, forKey: StorageKey.userIngredients)
    }
}
