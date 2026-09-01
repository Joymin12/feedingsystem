import SwiftUI

// MARK: - 인증 화면
//
// 소셜 로그인만 둔다. 이메일 회원가입은 주 사용자층(농가)에게 문턱이 높아 뺐다.
// 세 버튼 모두 지금은 데모용 로컬 세션이고, OAuth SDK를 붙일 때
// PrototypeStore.performSocialLogin 안쪽만 교체한다.

struct AuthGatewayView: View {
    @EnvironmentObject private var store: PrototypeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("하누핏")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text("한우 배합, 계산부터 교정까지")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.subtle)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 10) {
                socialButton(
                    provider: .kakao,
                    label: "카카오로 시작하기",
                    icon: { Image(systemName: "message.fill").font(.system(size: 15)) },
                    background: Color(red: 0.996, green: 0.898, blue: 0.0),
                    foreground: Color.black.opacity(0.85)
                )
                socialButton(
                    provider: .naver,
                    label: "네이버로 시작하기",
                    icon: { Text("N").font(.system(size: 16, weight: .heavy)) },
                    background: Color(red: 0.012, green: 0.78, blue: 0.353),
                    foreground: .white
                )
                socialButton(
                    provider: .apple,
                    label: "Apple로 시작하기",
                    icon: { Image(systemName: "applelogo").font(.system(size: 16)) },
                    background: Color.black,
                    foreground: .white
                )
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppScreenBackground())
    }

    private func socialButton<Icon: View>(
        provider: SocialLoginProvider,
        label: String,
        @ViewBuilder icon: () -> Icon,
        background: Color,
        foreground: Color
    ) -> some View {
        Button {
            store.performSocialLogin(provider: provider)
        } label: {
            HStack(spacing: 8) {
                icon()
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(background)
            )
        }
        .buttonStyle(.plain)
    }
}
