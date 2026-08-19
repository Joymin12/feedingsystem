import SwiftUI

// MARK: - 엔진 회귀 검증 화면 (관리자 전용)

struct RegressionSuiteView: View {
    @EnvironmentObject private var store: PrototypeStore

    var body: some View {
        let results = store.regressionSuiteResults()

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionCard(
                    title: "엔진 검증",
                    subtitle: "\(results.count)개 테스트 배합"
                ) {
                    let passedCount = results.filter(\.overallPassed).count
                    Text("통과 \(passedCount) / \(results.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(passedCount == results.count ? Color.green : Color.orange)
                }

                ForEach(results) { result in
                    SectionCard(title: result.formula.name, subtitle: result.formula.stage.title) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                StatusPill(title: "테스트 배합", tone: .caution)
                                StatusPill(title: result.overallPassed ? "통과" : "점검 필요", tone: result.overallPassed ? .adequate : .excess)
                            }

                            Text(result.expectationSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if !result.currentIssues.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("현재 주요 이탈")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(result.currentIssues.joined(separator: ", "))
                                        .font(.subheadline)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("기본 추천안")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                if let recommendation = result.primaryRecommendation {
                                    Text(recommendation.title)
                                        .font(.subheadline.weight(.semibold))
                                    if !recommendation.correctionActions.isEmpty {
                                        ForEach(recommendation.correctionActions) { action in
                                            Text(correctionActionLabel(action))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } else {
                                    Text("추천안 생성 실패")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.red)
                                }
                            }

                            if !result.projectedIssues.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("적용 후 예상 이탈")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(result.projectedIssues.joined(separator: ", "))
                                        .font(.subheadline)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("검증 체크")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(result.checks) { check in
                                    HStack(alignment: .top, spacing: 8) {
                                        StatusPill(title: check.passed ? "통과" : "실패", tone: check.tone)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(check.title)
                                                .font(.subheadline.weight(.semibold))
                                            Text(check.detail)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }

                            NavigationLink {
                                AIRecommendationView(formulaID: result.formula.id)
                            } label: {
                                Text("추천안 상세 보기")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("엔진 검증")
    }
}


