import Foundation

enum SupabaseRegistrationOutcome {
    case signedIn(AppUser)
    case confirmationRequired
}

enum SupabaseServiceError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case noSession
    case unexpectedResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Supabase 설정이 비어 있습니다."
        case .invalidURL:
            return "Supabase URL 구성이 잘못되었습니다."
        case .noSession:
            return "로그인 세션이 없습니다."
        case .unexpectedResponse:
            return "서버 응답을 처리하지 못했습니다."
        case let .serverMessage(message):
            return message
        }
    }
}

final class SupabaseService {
    private enum StorageKey {
        static let accessToken = "hanwoo.supabase.accessToken"
        static let refreshToken = "hanwoo.supabase.refreshToken"
        static let expiresAt = "hanwoo.supabase.expiresAt"
    }

    private let urlString: String
    private let anonKey: String
    private let session: URLSession

    init(
        urlString: String = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "",
        anonKey: String = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? "",
        session: URLSession = .shared
    ) {
        self.urlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        self.anonKey = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    var isConfigured: Bool {
        !urlString.isEmpty && !anonKey.isEmpty
    }

    func signUp(
        email: String,
        password: String,
        farmName: String,
        selectedIngredientIDs: [String]
    ) async throws -> SupabaseRegistrationOutcome {
        try ensureConfigured()

        let requestBody = SignUpRequest(
            email: email,
            password: password,
            data: SignUpMetadata(
                loginID: email,
                farmName: farmName,
                selectedIngredientIDs: selectedIngredientIDs
            )
        )

        let response: SignUpResponse = try await sendAuthRequest(
            path: "/auth/v1/signup",
            method: "POST",
            body: requestBody
        )

        if let session = response.session {
            persist(session: session)
            let user = try await buildCurrentUser(from: response.user)
            return .signedIn(user)
        }

        return .confirmationRequired
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        try ensureConfigured()

        let response: AuthSession = try await sendAuthRequest(
            path: "/auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: PasswordGrantRequest(email: email, password: password)
        )

        persist(session: response)
        return try await buildCurrentUser(from: response.user)
    }

    func restoreUser() async throws -> AppUser? {
        guard isConfigured, storedAccessToken != nil else { return nil }
        try await refreshSessionIfNeeded()
        return try await buildCurrentUser(from: nil)
    }

    func signOut() async {
        guard isConfigured else {
            clearSession()
            return
        }

        do {
            try await refreshSessionIfNeeded()
            try await sendAuthVoidRequest(
                path: "/auth/v1/logout",
                method: "POST",
                authMode: .sessionRequired
            )
        } catch {
            // Even if remote logout fails, local credentials must be cleared.
        }

        clearSession()
    }

    func updatePreferredStage(_ rawValue: String?) async throws {
        let user = try await fetchAuthUser()
        let payload = ProfileUpsertRow(
            id: user.id,
            email: user.email,
            loginID: user.userMetadata?.loginID ?? user.email,
            farmName: user.userMetadata?.farmName ?? defaultFarmName(for: user.email),
            preferredStage: rawValue,
            isAdmin: nil
        )

        _ = try await sendRestRequest(
            path: "/rest/v1/profiles",
            method: "POST",
            authMode: .sessionRequired,
            body: [payload],
            prefer: ["resolution=merge-duplicates", "return=representation"]
        ) as [ProfileRow]
    }

    func fetchPosts() async throws -> [CommunityPost] {
        let rows: [PostRow] = try await sendRestRequest(
            path: "/rest/v1/community_posts",
            method: "GET",
            authMode: .sessionOrAnon,
            queryItems: [
                URLQueryItem(name: "select", value: "id,title,excerpt,label,user_id,created_at"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )

        let authorIDs = Array(Set(rows.map(\.userID)))
        let authorMap = try await fetchProfileMap(for: authorIDs)

        return rows.map { row in
            let author = authorMap[row.userID]
            return CommunityPost(
                id: row.id,
                title: row.title,
                excerpt: row.excerpt,
                label: row.label,
                authorLoginID: author?.loginID ?? author?.email ?? row.userID.uuidString,
                authorDisplayName: author?.displayName ?? defaultDisplayName(from: author?.email ?? row.userID.uuidString),
                createdAt: row.createdAt
            )
        }
    }

    func createPost(title: String, excerpt: String, label: String) async throws -> [CommunityPost] {
        let user = try await fetchAuthUser()
        let payload = PostInsertRow(
            title: title,
            excerpt: excerpt,
            label: label,
            userID: user.id
        )

        _ = try await sendRestRequest(
            path: "/rest/v1/community_posts",
            method: "POST",
            authMode: .sessionRequired,
            body: [payload],
            prefer: ["return=representation"]
        ) as [PostRow]

        return try await fetchPosts()
    }

    func deletePost(id: UUID) async throws -> [CommunityPost] {
        try await sendRestVoidRequest(
            path: "/rest/v1/community_posts",
            method: "DELETE",
            authMode: .sessionRequired,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())")]
        )

        return try await fetchPosts()
    }

    private func buildCurrentUser(from providedUser: AuthUser?) async throws -> AppUser {
        let authUser = try await resolveAuthUser(providedUser)
        try await upsertProfileIfNeeded(from: authUser)
        let selectedIngredientIDs = try await syncAndFetchIngredientIDs(for: authUser)
        let profile = try await fetchProfile(id: authUser.id)

        return AppUser(
            id: authUser.id,
            loginID: profile?.loginID ?? authUser.userMetadata?.loginID ?? authUser.email ?? authUser.id.uuidString,
            email: profile?.email ?? authUser.email ?? "",
            password: "",
            farmName: profile?.farmName ?? authUser.userMetadata?.farmName ?? defaultFarmName(for: authUser.email),
            preferredStageRawValue: profile?.preferredStage,
            selectedIngredientIDs: selectedIngredientIDs,
            isAdmin: profile?.isAdmin ?? false
        )
    }

    private func resolveAuthUser(_ providedUser: AuthUser?) async throws -> AuthUser {
        if let providedUser {
            return providedUser
        }
        return try await fetchAuthUser()
    }

    private func upsertProfileIfNeeded(from authUser: AuthUser) async throws {
        let payload = ProfileUpsertRow(
            id: authUser.id,
            email: authUser.email,
            loginID: authUser.userMetadata?.loginID ?? authUser.email,
            farmName: authUser.userMetadata?.farmName ?? defaultFarmName(for: authUser.email),
            preferredStage: nil,
            isAdmin: nil
        )

        _ = try await sendRestRequest(
            path: "/rest/v1/profiles",
            method: "POST",
            authMode: .sessionRequired,
            body: [payload],
            prefer: ["resolution=merge-duplicates", "return=representation"]
        ) as [ProfileRow]
    }

    private func syncAndFetchIngredientIDs(for authUser: AuthUser) async throws -> [String] {
        let existing = try await fetchIngredientIDs(userID: authUser.id)
        if !existing.isEmpty {
            return existing
        }

        let pending = authUser.userMetadata?.selectedIngredientIDs ?? []
        guard !pending.isEmpty else { return [] }

        let insertRows = pending.map { IngredientRow(userID: authUser.id, ingredientID: $0) }
        _ = try await sendRestRequest(
            path: "/rest/v1/user_ingredients",
            method: "POST",
            authMode: .sessionRequired,
            body: insertRows,
            prefer: ["resolution=merge-duplicates", "return=representation"]
        ) as [IngredientResponseRow]

        return pending
    }

    private func fetchIngredientIDs(userID: UUID) async throws -> [String] {
        let rows: [IngredientResponseRow] = try await sendRestRequest(
            path: "/rest/v1/user_ingredients",
            method: "GET",
            authMode: .sessionRequired,
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())"),
                URLQueryItem(name: "select", value: "ingredient_id")
            ]
        )
        return rows.map(\.ingredientID)
    }

    private func fetchProfile(id: UUID) async throws -> ProfileRow? {
        let rows: [ProfileRow] = try await sendRestRequest(
            path: "/rest/v1/profiles",
            method: "GET",
            authMode: .sessionRequired,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())"),
                URLQueryItem(name: "select", value: "id,email,login_id,farm_name,preferred_stage,is_admin")
            ]
        )
        return rows.first
    }

    private func fetchProfileMap(for ids: [UUID]) async throws -> [UUID: ProfileRow] {
        guard !ids.isEmpty else { return [:] }
        let joinedIDs = ids.map { $0.uuidString.lowercased() }.joined(separator: ",")
        let rows: [ProfileRow] = try await sendRestRequest(
            path: "/rest/v1/profiles",
            method: "GET",
            authMode: .sessionOrAnon,
            queryItems: [
                URLQueryItem(name: "id", value: "in.(\(joinedIDs))"),
                URLQueryItem(name: "select", value: "id,email,login_id,farm_name,preferred_stage,is_admin")
            ]
        )
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
    }

    private func fetchAuthUser() async throws -> AuthUser {
        try await refreshSessionIfNeeded()
        return try await sendAuthRequest(
            path: "/auth/v1/user",
            method: "GET",
            authMode: .sessionRequired
        ) as AuthUser
    }

    private func refreshSessionIfNeeded() async throws {
        guard let refreshToken = storedRefreshToken else {
            guard storedAccessToken != nil else { throw SupabaseServiceError.noSession }
            return
        }

        if let expiresAt = storedExpiresAt, Date() < expiresAt.addingTimeInterval(-60) {
            return
        }

        let response: AuthSession = try await sendAuthRequest(
            path: "/auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: RefreshGrantRequest(refreshToken: refreshToken)
        )
        persist(session: response)
    }

    private func persist(session: AuthSession) {
        let defaults = UserDefaults.standard
        defaults.set(session.accessToken, forKey: StorageKey.accessToken)
        defaults.set(session.refreshToken, forKey: StorageKey.refreshToken)
        if let expiresAt = session.expiresAt {
            defaults.set(expiresAt, forKey: StorageKey.expiresAt)
        } else if let expiresIn = session.expiresIn {
            defaults.set(Date().addingTimeInterval(TimeInterval(expiresIn)), forKey: StorageKey.expiresAt)
        } else {
            defaults.removeObject(forKey: StorageKey.expiresAt)
        }
    }

    private func clearSession() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: StorageKey.accessToken)
        defaults.removeObject(forKey: StorageKey.refreshToken)
        defaults.removeObject(forKey: StorageKey.expiresAt)
    }

    private var storedAccessToken: String? {
        UserDefaults.standard.string(forKey: StorageKey.accessToken)
    }

    private var storedRefreshToken: String? {
        UserDefaults.standard.string(forKey: StorageKey.refreshToken)
    }

    private var storedExpiresAt: Date? {
        UserDefaults.standard.object(forKey: StorageKey.expiresAt) as? Date
    }

    private func ensureConfigured() throws {
        guard isConfigured else { throw SupabaseServiceError.missingConfiguration }
    }

    private enum AuthMode {
        case anonOnly
        case sessionRequired
        case sessionOrAnon
    }

    private func sendAuthRequest<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        authMode: AuthMode = .anonOnly,
        queryItems: [URLQueryItem] = [],
        body: Body? = nil
    ) async throws -> Response {
        try await sendRequest(
            path: path,
            method: method,
            authMode: authMode,
            queryItems: queryItems,
            body: body,
            prefer: []
        )
    }

    private func sendAuthRequest<Response: Decodable>(
        path: String,
        method: String,
        authMode: AuthMode = .anonOnly,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await sendRequest(
            path: path,
            method: method,
            authMode: authMode,
            queryItems: queryItems,
            body: Optional<EmptyRequestBody>.none,
            prefer: []
        )
    }

    private func sendAuthVoidRequest(
        path: String,
        method: String,
        authMode: AuthMode = .anonOnly,
        queryItems: [URLQueryItem] = []
    ) async throws {
        try await sendVoidRequest(
            path: path,
            method: method,
            authMode: authMode,
            queryItems: queryItems,
            prefer: []
        )
    }

    private func sendRestRequest<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        authMode: AuthMode,
        queryItems: [URLQueryItem] = [],
        body: Body? = nil,
        prefer: [String]
    ) async throws -> Response {
        try await sendRequest(
            path: path,
            method: method,
            authMode: authMode,
            queryItems: queryItems,
            body: body,
            prefer: prefer
        )
    }

    private func sendRestRequest<Response: Decodable>(
        path: String,
        method: String,
        authMode: AuthMode,
        queryItems: [URLQueryItem] = [],
        prefer: [String] = []
    ) async throws -> Response {
        try await sendRequest(
            path: path,
            method: method,
            authMode: authMode,
            queryItems: queryItems,
            body: Optional<EmptyRequestBody>.none,
            prefer: prefer
        )
    }

    private func sendRestVoidRequest(
        path: String,
        method: String,
        authMode: AuthMode,
        queryItems: [URLQueryItem] = [],
        prefer: [String] = []
    ) async throws {
        try await sendVoidRequest(
            path: path,
            method: method,
            authMode: authMode,
            queryItems: queryItems,
            prefer: prefer
        )
    }

    private func sendRequest<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        authMode: AuthMode,
        queryItems: [URLQueryItem],
        body: Body?,
        prefer: [String]
    ) async throws -> Response {
        var request = try makeRequest(
            path: path,
            method: method,
            authMode: authMode,
            queryItems: queryItems,
            prefer: prefer
        )

        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let decoder = makeDecoder()
        return try decoder.decode(Response.self, from: data)
    }

    private func sendVoidRequest(
        path: String,
        method: String,
        authMode: AuthMode,
        queryItems: [URLQueryItem],
        prefer: [String]
    ) async throws {
        let request = try makeRequest(
            path: path,
            method: method,
            authMode: authMode,
            queryItems: queryItems,
            prefer: prefer
        )
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func makeRequest(
        path: String,
        method: String,
        authMode: AuthMode,
        queryItems: [URLQueryItem],
        prefer: [String]
    ) throws -> URLRequest {
        try ensureConfigured()
        guard var components = URLComponents(string: urlString + path) else {
            throw SupabaseServiceError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw SupabaseServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        switch authMode {
        case .anonOnly:
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        case .sessionRequired:
            guard let token = storedAccessToken else {
                throw SupabaseServiceError.noSession
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .sessionOrAnon:
            let token = storedAccessToken ?? anonKey
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if !prefer.isEmpty {
            request.setValue(prefer.joined(separator: ","), forHTTPHeaderField: "Prefer")
        }

        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseServiceError.unexpectedResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? makeDecoder().decode(APIError.self, from: data) {
                throw SupabaseServiceError.serverMessage(apiError.readableMessage)
            }
            if let message = String(data: data, encoding: .utf8), !message.isEmpty {
                throw SupabaseServiceError.serverMessage(message)
            }
            throw SupabaseServiceError.unexpectedResponse
        }
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = Self.fractionalISO8601.date(from: string) ?? Self.iso8601.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "지원하지 않는 날짜 형식입니다.")
        }
        return decoder
    }

    private func defaultFarmName(for email: String?) -> String {
        guard let email, !email.isEmpty else { return "새 한우 농장" }
        let prefix = email.split(separator: "@").first.map(String.init) ?? "새 한우 농장"
        return prefix.isEmpty ? "새 한우 농장" : "\(prefix)의 한우 농장"
    }

    private func defaultDisplayName(from source: String) -> String {
        let prefix = source.split(separator: "@").first.map(String.init) ?? source
        return prefix.isEmpty ? source : prefix
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct PasswordGrantRequest: Encodable {
    let email: String
    let password: String
}

private struct RefreshGrantRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let data: SignUpMetadata
}

private struct SignUpMetadata: Codable {
    let loginID: String
    let farmName: String
    let selectedIngredientIDs: [String]

    enum CodingKeys: String, CodingKey {
        case loginID = "login_id"
        case farmName = "farm_name"
        case selectedIngredientIDs = "selected_ingredient_ids"
    }
}

private struct SignUpResponse: Decodable {
    let user: AuthUser?
    let session: AuthSession?
}

private struct AuthSession: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int?
    let expiresAt: Date?
    let tokenType: String?
    let user: AuthUser?
}

private struct AuthUser: Decodable {
    let id: UUID
    let email: String?
    let userMetadata: SignUpMetadata?
}

private struct ProfileUpsertRow: Encodable {
    let id: UUID
    let email: String?
    let loginID: String?
    let farmName: String
    let preferredStage: String?
    let isAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case loginID = "login_id"
        case farmName = "farm_name"
        case preferredStage = "preferred_stage"
        case isAdmin = "is_admin"
    }
}

private struct ProfileRow: Codable {
    let id: UUID
    let email: String?
    let loginID: String?
    let farmName: String?
    let preferredStage: String?
    let isAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case loginID = "login_id"
        case farmName = "farm_name"
        case preferredStage = "preferred_stage"
        case isAdmin = "is_admin"
    }

    var displayName: String {
        if isAdmin == true { return "관리자" }
        if let farmName, !farmName.isEmpty { return farmName }
        let source = email ?? loginID ?? id.uuidString
        let prefix = source.split(separator: "@").first.map(String.init) ?? source
        return prefix.isEmpty ? source : prefix
    }
}

private struct IngredientRow: Encodable {
    let userID: UUID
    let ingredientID: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case ingredientID = "ingredient_id"
    }
}

private struct IngredientResponseRow: Decodable {
    let ingredientID: String

    enum CodingKeys: String, CodingKey {
        case ingredientID = "ingredient_id"
    }
}

private struct PostInsertRow: Encodable {
    let title: String
    let excerpt: String
    let label: String
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case title
        case excerpt
        case label
        case userID = "user_id"
    }
}

private struct PostRow: Decodable {
    let id: UUID
    let title: String
    let excerpt: String
    let label: String
    let userID: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case excerpt
        case label
        case userID = "user_id"
        case createdAt = "created_at"
    }
}

private struct APIError: Decodable {
    let error: String?
    let errorDescription: String?
    let message: String?
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case message
        case msg
    }

    var readableMessage: String {
        errorDescription ?? message ?? msg ?? error ?? "Supabase 요청이 실패했습니다."
    }
}

private struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        encodeBlock = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}

private struct EmptyRequestBody: Encodable {}
