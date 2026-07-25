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

    func ensureAdminUser() {
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
