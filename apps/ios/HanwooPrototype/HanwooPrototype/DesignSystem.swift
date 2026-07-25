import SwiftUI

enum AppPalette {
    static let primary = Color(red: 0.12, green: 0.51, blue: 0.28)
    static let ink = Color(red: 0.10, green: 0.18, blue: 0.14)
    static let warning = Color(red: 0.79, green: 0.48, blue: 0.09)
    static let canvas = Color(red: 0.95, green: 0.96, blue: 0.92)
    static let surface = Color.white.opacity(0.92)
    static let surfaceMuted = Color(red: 0.96, green: 0.97, blue: 0.94)
    static let surfaceStrong = Color(red: 0.93, green: 0.96, blue: 0.90)
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.83, green: 0.92, blue: 0.78),
            Color(red: 0.96, green: 0.94, blue: 0.84)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppScreenBackground: View {
    var body: some View {
        ZStack {
            AppPalette.canvas
            LinearGradient(
                colors: [
                    Color.white.opacity(0.55),
                    Color(red: 0.89, green: 0.93, blue: 0.87).opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 280, height: 280)
                .offset(x: 150, y: -240)
            Circle()
                .fill(AppPalette.primary.opacity(0.08))
                .frame(width: 360, height: 360)
                .offset(x: -180, y: 260)
        }
        .ignoresSafeArea()
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppPalette.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppPalette.primary.opacity(0.14)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tone.color.opacity(0.12))
        .foregroundStyle(tone.color)
        .clipShape(Capsule())
        .accessibilityLabel("\(title) 상태")
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
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
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
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(kind.color.opacity(0.10))
        )
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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.primary.opacity(configuration.isPressed ? 0.4 : 0.8), lineWidth: 1.5)
            )
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
                .font(.headline)
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
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppPalette.primary.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .shadow(color: AppPalette.primary.opacity(0.25), radius: 14, x: 0, y: 10)
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
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.9))
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                    .foregroundStyle(.primary)
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
