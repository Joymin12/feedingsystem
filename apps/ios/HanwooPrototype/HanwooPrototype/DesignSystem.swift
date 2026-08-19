import SwiftUI

// MARK: - 디자인 시스템
// 출시형 비주얼 언어. 화면들은 여기 정의된 토큰·컴포넌트만 사용하므로
// 이 파일을 바꾸면 앱 전체 룩이 함께 바뀐다.
//
// 원칙
// - 배경은 차분한 중성 그레이, 콘텐츠는 흰 카드로 명확한 위계
// - 브랜드 그린은 행동(버튼·활성 탭·강조)에만 사용
// - 상태(부족/주의/적정/과잉)는 색 + 아이콘 + 텍스트를 항상 병기

// 라이트/다크 한 쌍으로 색을 정의한다.
// 시스템 외양 설정을 따라 자동으로 바뀌므로 화면 코드는 모드를 신경 쓰지 않는다.
private extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
        self.init(
            light: UIColor(red: light.0, green: light.1, blue: light.2, alpha: 1),
            dark: UIColor(red: dark.0, green: dark.1, blue: dark.2, alpha: 1)
        )
    }
}

enum AppPalette {
    // 브랜드 — 흰 바탕에 연두 계열 포인트.
    // 다크 모드에서는 같은 계열을 한 단계 밝혀 어두운 배경 위에서도 눈에 띄게 한다.
    static let primary = Color(light: (0.29, 0.60, 0.22), dark: (0.55, 0.82, 0.42))
    static let primaryDeep = Color(light: (0.18, 0.44, 0.16), dark: (0.38, 0.62, 0.30))
    static let ink = Color(light: (0.10, 0.13, 0.10), dark: (0.93, 0.95, 0.92))
    static let warning = Color(light: (0.78, 0.47, 0.10), dark: (0.95, 0.66, 0.28))

    // 표면 — 라이트는 흰색에 옅은 연두 기운, 다크는 녹색 기운이 도는 짙은 회색
    static let canvas = Color(light: (0.969, 0.980, 0.961), dark: (0.075, 0.086, 0.075))
    static let surface = Color(light: (1.0, 1.0, 1.0), dark: (0.125, 0.137, 0.125))
    static let surfaceMuted = Color(light: (0.949, 0.969, 0.937), dark: (0.157, 0.173, 0.157))
    static let surfaceStrong = Color(light: (0.906, 0.945, 0.882), dark: (0.184, 0.208, 0.180))
    static let hairline = Color(
        light: UIColor.black.withAlphaComponent(0.06),
        dark: UIColor.white.withAlphaComponent(0.10)
    )

    // 연두 강조면 — 선택된 칩, 인기 배지 등 브랜드 색 배경이 필요할 때
    static let accentSoft = Color(light: (0.898, 0.957, 0.847), dark: (0.157, 0.227, 0.129))

    // 브랜드 색 위에 올라가는 글자. 다크 모드의 primary는 밝은 연두라 흰 글자가 묻힌다.
    static let onPrimary = Color(light: (1.0, 1.0, 1.0), dark: (0.04, 0.10, 0.04))

    // 히어로(홈 상단) 전용 — 흰 글자를 얹으므로 두 모드 모두 짙은 녹색을 유지한다
    static let heroGradient = LinearGradient(
        colors: [
            Color(light: (0.24, 0.52, 0.20), dark: (0.16, 0.34, 0.14)),
            Color(light: (0.14, 0.36, 0.13), dark: (0.10, 0.24, 0.10)),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppScreenBackground: View {
    var body: some View {
        AppPalette.canvas
            .ignoresSafeArea()
    }
}

// 카드 공통 스타일
private struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppPalette.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppPalette.primary)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppPalette.primary.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .cardSurface()
    }
}

struct StatusPill: View {
    let title: String
    let tone: StatusTone

    var body: some View {
        // 접근성: 색상에만 의존하지 않도록 아이콘 + 텍스트 라벨을 함께 표기한다.
        HStack(spacing: 4) {
            Image(systemName: tone.iconName)
                .font(.caption2)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tone.color.opacity(0.13))
        .foregroundStyle(tone.color)
        .clipShape(Capsule())
        .accessibilityLabel("\(title) 상태")
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
                .font(.subheadline.weight(.semibold))
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppPalette.onPrimary)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppPalette.primary.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .shadow(color: AppPalette.primary.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppPalette.primary)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppPalette.primary.opacity(configuration.isPressed ? 0.35 : 0.65), lineWidth: 1.2)
            )
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
                .foregroundStyle(AppPalette.ink)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(AppPalette.surfaceMuted)
        )
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
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
                .foregroundStyle(AppPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppPalette.surfaceMuted)
        )
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
                    .foregroundStyle(AppPalette.ink)
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

// 빈 목록 상태 안내
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// 경고/안내 배너 (색상 + 아이콘 + 텍스트 병기)
struct NoticeBanner: View {
    enum Kind {
        case info, warning

        var icon: String {
            switch self {
            case .info: "info.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .info: .blue
            case .warning: .orange
            }
        }
    }

    let kind: Kind
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.icon)
                .foregroundStyle(kind.color)
            Text(message)
                .font(.footnote)
                .foregroundStyle(AppPalette.ink.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(kind.color.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(kind.color.opacity(0.18), lineWidth: 1)
        )
    }
}
