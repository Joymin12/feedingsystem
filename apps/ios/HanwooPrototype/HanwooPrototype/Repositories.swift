import Foundation

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

// MARK: - UserDefaults 구현

private enum StorageKey {
    static let users = "hanwoo.prototype.users"
    static let currentLoginID = "hanwoo.prototype.currentLoginID"
    static let posts = "hanwoo.prototype.posts"
    static let userIngredients = "hanwoo.prototype.userIngredients"
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
