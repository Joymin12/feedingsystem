import SwiftUI

// MARK: - PrototypeStore 세션 / 인증 책임
// 로그인, 회원가입, 로그아웃, 온보딩, Supabase 세션, 사용자 영속화.

extension PrototypeStore {
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

    /// 소셜 로그인 자리. 실제 카카오/네이버 OAuth는 아직 연동하지 않았고,
    /// 데모에서는 제공자별 로컬 계정을 만들어 같은 흐름(로그인 → 온보딩)을 태운다.
    /// SDK를 붙일 때 이 메서드 안쪽만 교체하면 화면 코드는 그대로 쓴다.
    func performSocialLogin(provider: SocialLoginProvider) {
        let loginID = "\(provider.rawValue)@social.local"
        if users.firstIndex(where: { $0.loginID == loginID }) == nil {
            users.append(
                AppUser(
                    loginID: loginID,
                    email: loginID,
                    password: "",
                    farmName: "\(provider.title) 연동 농장",
                    selectedIngredientIDs: []
                )
            )
            saveUsers()
        }
        currentLoginID = loginID
        userRepository.saveCurrentLoginID(loginID)
        syncSessionFromCurrentUser()
        isAuthenticated = true
    }

    func performLogout() async {
        if usesSupabase {
            await supabaseService.signOut()
        }
        logout()
    }

    func login(loginID: String, password: String) -> Bool {
        guard let user = users.first(where: {
            $0.loginID.caseInsensitiveCompare(loginID) == .orderedSame && $0.password == password
        }) else {
            return false
        }
        currentLoginID = user.loginID
        userRepository.saveCurrentLoginID(user.loginID)
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
        userRepository.saveCurrentLoginID(newUser.loginID)
        syncSessionFromCurrentUser()
        isAuthenticated = true
        return true
    }

    func logout() {
        currentLoginID = nil
        userRepository.saveCurrentLoginID(nil)
        isAuthenticated = false
        selectedStage = nil
        farmName = "행복한 한우 농장"
        if usesSupabase {
            users = []
            posts = []
        }
    }

    /// 첫 실행 온보딩 완료. 단계와 함께 고른 원료를 사용자에 저장한다.
    /// 원료를 하나도 고르지 않았으면 전체 원료가 보이므로 그대로 둔다.
    func completeOnboarding(stage: FarmStage, selectedIngredientIDs: [String]) {
        if !selectedIngredientIDs.isEmpty {
            updateCurrentUser { user in
                user.selectedIngredientIDs = selectedIngredientIDs
            }
        }
        completeOnboarding(stage: stage)
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
        // 고른 단계의 배합이 이미 있으면 그것을 대표로 삼는다.
        // 없을 때만 지금 배합의 단계를 바꾼다. 그러지 않으면
        // "비육전기 기본 배합"이 육성기 기준으로 판정되는 어긋남이 생긴다.
        if let match = selectableFormulas.first(where: { $0.stage == stage }) {
            selectedFormulaID = match.id
        } else if let index = formulas.firstIndex(where: { $0.id == selectedFormulaID }) {
            formulas[index].stage = stage
            // 시드가 준 기본 이름이라면 단계를 따라간다.
            // 사용자가 직접 지은 이름은 그대로 둔다.
            let defaultNames = FarmStage.allCases.map { "\($0.title) 기본 배합" }
            if defaultNames.contains(formulas[index].name) {
                formulas[index].name = "\(stage.title) 기본 배합"
            }
        }
    }

    func ensureAdminUser() {
        guard users.allSatisfy({ $0.loginID != "qwer123" }) else { return }
        users.append(
            AppUser(
                loginID: "qwer123",
                email: "admin@local",
                password: "asdf123",
                farmName: "관리자 계정",
                // 단계를 미리 넣어두면 온보딩이 건너뛰어진다. 첫 실행에서 직접 고르게 둔다.
                preferredStageRawValue: nil,
                selectedIngredientIDs: [],
                isAdmin: true
            )
        )
        saveUsers()
    }

    func syncSessionFromCurrentUser() {
        guard let currentUser else {
            isAuthenticated = false
            return
        }
        isAuthenticated = true
        farmName = currentUser.farmName
        selectedStage = currentUser.preferredStage
    }

    private func saveUsers() {
        userRepository.saveUsers(users)
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
