import SwiftUI

// MARK: - 인증 / 온보딩 화면

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
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppPalette.surface)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppPalette.hairline, lineWidth: 1))
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
