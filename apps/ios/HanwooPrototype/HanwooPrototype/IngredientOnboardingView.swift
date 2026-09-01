import SwiftUI

// MARK: - 원료 선택 온보딩
//
// 회원가입 시 자기 농가가 쓰는 원료를 고르는 화면.
// 네 카테고리를 한 화면에 늘어놓지 않고 단계별로 하나씩 보여준다.
// 한 번에 한 가지 질문만 하는 쪽이 처음 쓰는 사람에게 부담이 적다.
//
// 정렬은 서버의 사용 통계를 따른다. 다른 농가들이 많이 쓰는 원료가 위로 오고
// "인기" 배지가 붙는다. 처음 고르는 사람에게는 남들이 무엇을 쓰는지가
// 가장 좋은 출발점이기 때문이다. 서버가 없으면 기본 순서로 보여준다.

struct IngredientOnboardingView: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss

    @Binding var selection: Set<String>
    var onComplete: () -> Void

    @State private var stepIndex = 0
    /// 원료 ID → 사용 농가 수. 서버 응답으로 채워진다.
    @State private var popularity: [String: Int] = [:]

    private var categories: [IngredientCategory] { IngredientCategory.allCases }
    private var category: IngredientCategory { categories[stepIndex] }
    private var isLastStep: Bool { stepIndex == categories.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                progressHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("쓰고 있는 \(category.rawValue)")
                            .font(.title2.bold())
                            .foregroundStyle(AppPalette.ink)
                            .padding(.top, 18)

                        chipGrid
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }

                bottomBar
            }
            .background(AppPalette.canvas.ignoresSafeArea())
            .navigationTitle("원료 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task {
                popularity = await UsageStatsService().popularity()
            }
        }
    }

    // MARK: 진행 표시

    private var progressHeader: some View {
        HStack(spacing: 6) {
            ForEach(categories.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= stepIndex ? AppPalette.primary : AppPalette.surfaceStrong)
                    .frame(height: 5)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: stepIndex)
        .accessibilityLabel("\(categories.count)단계 중 \(stepIndex + 1)단계")
    }

    // MARK: 원료 칩

    private var chipGrid: some View {
        let definitions = sortedDefinitions()
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(definitions) { definition in
                chip(definition, isPopular: isPopular(definition, in: definitions))
            }
        }
    }

    private func chip(_ definition: IngredientDefinition, isPopular: Bool) -> some View {
        let isSelected = selection.contains(definition.id)
        return Button {
            if isSelected {
                selection.remove(definition.id)
            } else {
                selection.insert(definition.id)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppPalette.primary : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                        .multilineTextAlignment(.leading)
                    if isPopular {
                        Text("인기")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppPalette.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AppPalette.accentSoft : AppPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppPalette.primary : AppPalette.hairline, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(definition.name)\(isPopular ? ", 인기 원료" : "")\(isSelected ? ", 선택됨" : "")")
    }

    // MARK: 하단 이동

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if stepIndex > 0 {
                Button("이전") {
                    stepIndex -= 1
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 110)
            }

            Button(isLastStep ? "선택 완료 (\(selection.count)개)" : "다음") {
                if isLastStep {
                    onComplete()
                    dismiss()
                } else {
                    stepIndex += 1
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppPalette.surface.ignoresSafeArea(edges: .bottom))
    }

    // MARK: 정렬

    /// 서버 통계 기준으로 많이 쓰는 원료가 앞에 온다. 통계가 없으면 기본 순서.
    private func sortedDefinitions() -> [IngredientDefinition] {
        let definitions = store.definitions(for: category)
        guard !popularity.isEmpty else { return definitions }
        return definitions.sorted {
            let a = popularity[$0.id] ?? 0
            let b = popularity[$1.id] ?? 0
            if a != b { return a > b }
            return $0.name < $1.name
        }
    }

    /// 카테고리 안에서 사용 농가가 있는 상위 3개에만 인기 배지를 붙인다.
    private func isPopular(_ definition: IngredientDefinition, in sorted: [IngredientDefinition]) -> Bool {
        guard (popularity[definition.id] ?? 0) > 0 else { return false }
        return sorted.prefix(3).contains { $0.id == definition.id }
    }
}

// MARK: - 사용 통계 조회

/// 서버가 집계한 원료별 사용 농가 수를 가져온다.
/// 실패하면 빈 값을 돌려주고 온보딩은 기본 순서로 동작한다.
@MainActor
struct UsageStatsService {
    private let baseURL: URL

    init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else if
            let configured = Bundle.main.object(forInfoDictionaryKey: "AIExplanationBaseURL") as? String,
            let url = URL(string: configured)
        {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "http://127.0.0.1:3001")!
        }
    }

    func popularity() async -> [String: Int] {
        struct Response: Decodable {
            struct Item: Decodable {
                let ingredientId: String
                let farmCount: Int
            }
            let items: [Item]
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/ingredient-usage/stats"))
        request.timeoutInterval = 6

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode),
            let decoded = try? JSONDecoder().decode(Response.self, from: data)
        else { return [:] }

        return Dictionary(
            decoded.items.map { ($0.ingredientId, $0.farmCount) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}


// MARK: - 첫 실행 온보딩
//
// 사육 단계 하나, 그다음 카테고리별 원료를 차례로 고른다.
// 회원가입 화면 안에 두면 로그인을 건너뛴 사용자는 한 번도 보지 못하므로
// 앱에 처음 들어온 시점에 별도 화면으로 세운다.

struct OnboardingFlowView: View {
    @EnvironmentObject private var store: PrototypeStore

    /// 0은 사육 단계, 1부터는 원료 카테고리.
    @State private var stepIndex = 0
    @State private var stage: FarmStage = .growing
    @State private var selection: Set<String> = []
    @State private var popularity: [String: Int] = [:]

    private var categories: [IngredientCategory] { IngredientCategory.allCases }
    private var totalSteps: Int { categories.count + 1 }
    private var isLastStep: Bool { stepIndex == totalSteps - 1 }
    private var category: IngredientCategory? {
        stepIndex == 0 ? nil : categories[stepIndex - 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            progressHeader
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let category {
                        Text("쓰고 있는 \(category.rawValue)")
                            .font(.title2.bold())
                            .foregroundStyle(AppPalette.ink)
                            .padding(.top, 18)
                        chipGrid(for: category)
                    } else {
                        Text("주 사육 단계")
                            .font(.title2.bold())
                            .foregroundStyle(AppPalette.ink)
                            .padding(.top, 18)
                        stageChoices
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            bottomBar
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .task {
            popularity = await UsageStatsService().popularity()
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= stepIndex ? AppPalette.primary : AppPalette.surfaceStrong)
                    .frame(height: 5)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: stepIndex)
        .accessibilityLabel("\(totalSteps)단계 중 \(stepIndex + 1)단계")
    }

    private var stageChoices: some View {
        VStack(spacing: 10) {
            ForEach(FarmStage.allCases) { item in
                Button {
                    stage = item
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: stage == item ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(stage == item ? AppPalette.primary : Color.secondary)
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(stage == item ? AppPalette.accentSoft : AppPalette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(stage == item ? AppPalette.primary : AppPalette.hairline,
                                    lineWidth: stage == item ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chipGrid(for category: IngredientCategory) -> some View {
        let definitions = sortedDefinitions(for: category)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(definitions) { definition in
                chip(definition, isPopular: isPopular(definition, in: definitions))
            }
        }
    }

    private func chip(_ definition: IngredientDefinition, isPopular: Bool) -> some View {
        let isSelected = selection.contains(definition.id)
        return Button {
            if isSelected {
                selection.remove(definition.id)
            } else {
                selection.insert(definition.id)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppPalette.primary : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                        .multilineTextAlignment(.leading)
                    if isPopular {
                        Text("인기")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppPalette.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AppPalette.accentSoft : AppPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppPalette.primary : AppPalette.hairline,
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(definition.name)\(isPopular ? ", 인기 원료" : "")\(isSelected ? ", 선택됨" : "")")
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if stepIndex > 0 {
                Button("이전") { stepIndex -= 1 }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(width: 110)
            }

            Button(isLastStep ? "시작하기" : "다음") {
                if isLastStep {
                    store.completeOnboarding(stage: stage, selectedIngredientIDs: Array(selection))
                } else {
                    stepIndex += 1
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppPalette.surface.ignoresSafeArea(edges: .bottom))
    }

    private func sortedDefinitions(for category: IngredientCategory) -> [IngredientDefinition] {
        let definitions = store.definitions(for: category)
        guard !popularity.isEmpty else { return definitions }
        return definitions.sorted {
            let a = popularity[$0.id] ?? 0
            let b = popularity[$1.id] ?? 0
            if a != b { return a > b }
            return $0.name < $1.name
        }
    }

    private func isPopular(_ definition: IngredientDefinition, in sorted: [IngredientDefinition]) -> Bool {
        guard (popularity[definition.id] ?? 0) > 0 else { return false }
        return sorted.prefix(3).contains { $0.id == definition.id }
    }
}
