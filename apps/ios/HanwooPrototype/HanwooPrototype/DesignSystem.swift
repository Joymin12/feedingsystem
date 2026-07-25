import SwiftUI

// MARK: - 디자인 시스템
// 출시형 비주얼 언어. 화면들은 여기 정의된 토큰·컴포넌트만 사용하므로
// 이 파일을 바꾸면 앱 전체 룩이 함께 바뀐다.
//
// 원칙
// - 배경은 차분한 중성 그레이, 콘텐츠는 흰 카드로 명확한 위계
// - 브랜드 그린은 행동(버튼·활성 탭·강조)에만 사용
// - 상태(부족/주의/적정/과잉)는 색 + 아이콘 + 텍스트를 항상 병기

enum AppPalette {
    // 브랜드
    static let primary = Color(red: 0.07, green: 0.44, blue: 0.26)
    static let primaryDeep = Color(red: 0.04, green: 0.30, blue: 0.18)
    static let ink = Color(red: 0.09, green: 0.12, blue: 0.11)
    static let warning = Color(red: 0.78, green: 0.47, blue: 0.10)

    // 표면
    static let canvas = Color(red: 0.953, green: 0.957, blue: 0.962)
    static let surface = Color.white
    static let surfaceMuted = Color(red: 0.965, green: 0.968, blue: 0.972)
    static let surfaceStrong = Color(red: 0.922, green: 0.936, blue: 0.928)
    static let hairline = Color.black.opacity(0.06)

    // 히어로(홈 상단) 전용
    static let heroGradient = LinearGradient(
        colors: [primary, primaryDeep],
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
            .foregroundStyle(.white)
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
