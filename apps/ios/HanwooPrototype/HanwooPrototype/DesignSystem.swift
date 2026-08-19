import SwiftUI

// MARK: - 디자인 시스템
// 출시형 비주얼 언어. 화면들은 여기 정의된 토큰·컴포넌트만 사용하므로
// 이 파일을 바꾸면 앱 전체 룩이 함께 바뀐다.
//
// 원칙
// - 배경은 흰색 한 장. 카드를 겹쳐 쌓지 않고 여백과 얇은 선으로 구분한다.
// - 색은 초록 하나. 버튼과 활성 탭에만 쓰고, 빨강은 실제 문제에만 최소로 쓴다.
// - 각 화면에서 가장 큰 글자는 그 화면의 핵심 숫자다.
// - 상태는 배지 대신 작은 글자로 적는다. 배지가 화면마다 깔리면 화면이 시끄러워진다.

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
    static let canvas = Color(light: (1.0, 1.0, 1.0), dark: (0.071, 0.075, 0.071))
    static let surface = Color(light: (1.0, 1.0, 1.0), dark: (0.125, 0.137, 0.125))
    static let surfaceMuted = Color(light: (0.965, 0.965, 0.972), dark: (0.145, 0.153, 0.145))
    static let surfaceStrong = Color(light: (0.906, 0.945, 0.882), dark: (0.184, 0.208, 0.180))
    static let hairline = Color(
        light: UIColor.black.withAlphaComponent(0.07),
        dark: UIColor.white.withAlphaComponent(0.12)
    )

    /// 문제 표시용 빨강. 부족·과잉에만 쓴다.
    static let alert = Color(light: (0.753, 0.227, 0.169), dark: (0.937, 0.412, 0.353))

    /// 보조 글자. 라벨, 단위, 설명에 쓴다.
    static let subtle = Color(light: (0.604, 0.604, 0.627), dark: (0.541, 0.557, 0.541))

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
// 카드는 기본적으로 쓰지 않는다. 묶어서 보여줘야 할 때만 옅은 면을 깐다.
// 테두리와 그림자를 빼서 배경 위에 떠 보이지 않게 한다.
private struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppPalette.surfaceMuted)
            )
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 14) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}

/// 섹션. 카드로 감싸지 않고 작은 머리글 + 내용으로 둔다.
struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppPalette.subtle)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.subtle)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 화면 상단의 큰 숫자. 각 화면의 핵심 지표를 한 번에 전달한다.
struct DisplayStat: View {
    let value: String
    let suffix: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 42, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.ink)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppPalette.subtle)
                }
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.subtle)
            }
        }
    }
}

/// 값 칩. 요약 수치를 늘어놓을 때 쓴다.
struct ValueChip: View {
    let name: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(name)
                .font(.system(size: 13))
                .foregroundStyle(AppPalette.subtle)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppPalette.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppPalette.surfaceMuted)
        )
    }
}

/// 목록 한 줄을 나누는 선.
struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppPalette.hairline)
            .frame(height: 1)
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

/// 상태 표시. 배경을 깐 배지 대신 작은 글자로 적는다.
/// 문제가 있는 항목만 색을 쓰고, 주의와 적정은 회색으로 둬서 화면이 조용하게 유지된다.
struct StatusPill: View {
    let title: String
    let tone: StatusTone

    private var textColor: Color {
        switch tone {
        case .deficient, .excess: AppPalette.alert
        case .caution, .adequate: AppPalette.subtle
        }
    }

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(textColor)
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
