import SwiftUI

struct AIRecommendationView: View {
    @EnvironmentObject private var store: PrototypeStore
    let formulaID: UUID
    @State private var expandedRecommendationIDs: Set<String> = []
    @State private var showsAlternatives = false

    var body: some View {
        ScrollView {
            if let formula = store.formula(for: formulaID) {
                let analysis = store.analysis(for: formula)
                let primaryRecommendation = preferredRecommendation(from: analysis.recommendations)
                let alternativeRecommendations = alternativeRecommendations(from: analysis.recommendations, primaryID: primaryRecommendation?.id)

                VStack(alignment: .leading, spacing: 20) {
                    SectionCard(title: "추천안 기준", subtitle: formula.name) {
                        VStack(alignment: .leading, spacing: 8) {
                            if formula.isTestFormula {
                                StatusPill(title: "테스트 배합", tone: .caution)
                            }
                            Text(analysis.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("기본 추천안 1개를 먼저 보여주고, 필요하면 대안 안을 더 열어볼 수 있습니다.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let primaryRecommendation {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("기본 추천안")
                                .font(.title3.bold())
                            RecommendationCard(
                                recommendation: primaryRecommendation,
                                stage: formula.stage,
                                currentMetrics: analysis.metrics,
                                isExpanded: expandedRecommendationIDs.contains(primaryRecommendation.id),
                                onToggleExpanded: { toggleExpansion(for: primaryRecommendation.id) }
                            )
                        }
                    }

                    if !alternativeRecommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            DisclosureGroup(isExpanded: $showsAlternatives) {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(alternativeRecommendations) { recommendation in
                                        RecommendationCard(
                                            recommendation: recommendation,
                                            stage: formula.stage,
                                            currentMetrics: analysis.metrics,
                                            isExpanded: expandedRecommendationIDs.contains(recommendation.id),
                                            onToggleExpanded: { toggleExpansion(for: recommendation.id) }
                                        )
                                    }
                                }
                                .padding(.top, 12)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("대안 보기")
                                        .font(.headline)
                                    Text("가성비 우선안을 비교할 수 있습니다.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(AppScreenBackground())
        .navigationTitle("추천안")
    }

    private func preferredRecommendation(from recommendations: [Recommendation]) -> Recommendation? {
        defaultRecommendation(from: recommendations)
    }

    private func alternativeRecommendations(from recommendations: [Recommendation], primaryID: String?) -> [Recommendation] {
        recommendations.filter { recommendation in
            recommendation.id != primaryID &&
            recommendation.strategy != .maintenance &&
            recommendation.strategy != .noSolution
        }
    }

    private func toggleExpansion(for id: String) {
        if expandedRecommendationIDs.contains(id) {
            expandedRecommendationIDs.remove(id)
        } else {
            expandedRecommendationIDs.insert(id)
        }
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    let stage: FarmStage
    let currentMetrics: AnalysisSummaryMetrics
    let isExpanded: Bool
    let onToggleExpanded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.headline)
                    if recommendation.isReferenceOnly {
                        Text("참고 교정안")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppPalette.warning.opacity(0.12)))
                    } else if !recommendation.isFullyResolved && recommendation.strategy != .maintenance && recommendation.strategy != .noSolution {
                        Text("완전 해결 아님")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppPalette.warning.opacity(0.12)))
                    }
                }
                Spacer()
                if recommendation.strategy != .maintenance && recommendation.strategy != .noSolution {
                    Text(recommendation.isAlreadyInFormula ? "현재 보유" : "신규")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(recommendation.isAlreadyInFormula ? AppPalette.primary : .secondary)
                }
            }

            if recommendation.strategy == .maintenance || recommendation.strategy == .noSolution {
                Text(recommendation.action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.primary)
            } else if !recommendation.correctionActions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("교정배합안")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(recommendation.correctionActions) { action in
                        Text(correctionActionLabel(action))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.primary)
                    }
                }
            }

            Text(recommendation.reason)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if recommendation.strategy != .maintenance && recommendation.strategy != .noSolution {
                HStack {
                    Text("예상 비용 변화")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(recommendation.costDeltaKrw == 0 ? "변화 없음" : "+\(krwString(recommendation.costDeltaKrw))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.primary)
                }

                if let suggestedAmount = recommendation.suggestedAmount {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("권장 보강량")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(suggestedAmount)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.primary)
                        if let amountNote = recommendation.amountNote {
                            Text(amountNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let amountNote = recommendation.amountNote {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("권장 보강량")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(amountNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: onToggleExpanded) {
                    HStack(spacing: 8) {
                        Text(isExpanded ? "적용 후 예상 접기" : "적용 후 예상 보기")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppPalette.primary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppPalette.primary.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("현재 → 적용 후 예상")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ComparisonRow(title: "CP", current: percentString(currentMetrics.cpPctDm), projected: percentString(recommendation.simulatedMetrics.cpPctDm), projectedTone: projectedCpTone)
                        ComparisonRow(title: "TDN", current: percentString(currentMetrics.tdnPctDm), projected: percentString(recommendation.simulatedMetrics.tdnPctDm), projectedTone: projectedTdnTone)
                        ComparisonRow(title: "NDF", current: percentString(currentMetrics.ndfPctDm), projected: percentString(recommendation.simulatedMetrics.ndfPctDm), projectedTone: projectedNdfTone)
                        ComparisonRow(title: "ADF", current: percentString(currentMetrics.adfPctDm), projected: percentString(recommendation.simulatedMetrics.adfPctDm), projectedTone: projectedAdfTone)
                        ComparisonRow(title: "Ca", current: percentString(currentMetrics.caPctDm), projected: percentString(recommendation.simulatedMetrics.caPctDm), projectedTone: projectedCaTone)
                        ComparisonRow(title: "P", current: percentString(currentMetrics.pPctDm), projected: percentString(recommendation.simulatedMetrics.pPctDm), projectedTone: projectedPTone)
                        ComparisonRow(title: "Ca:P", current: ratioString(currentMetrics.caPRatio), projected: ratioString(recommendation.simulatedMetrics.caPRatio), projectedTone: projectedCaPRatioTone)
                        ComparisonRow(title: "수분", current: percentString(currentMetrics.moisturePct), projected: percentString(recommendation.simulatedMetrics.moisturePct), projectedTone: projectedMoistureTone)
                    }
                    .padding(.top, 4)
                }

                if !recommendation.pros.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("장점")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(recommendation.pros, id: \.self) { item in
                            BulletLine(text: item)
                        }
                    }
                    .padding(.top, 4)
                }

                if !recommendation.cons.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("주의점")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(recommendation.cons, id: \.self) { item in
                            BulletLine(text: item)
                        }
                    }
                    .padding(.top, 4)
                }
            }
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

    private var criteria: StageCriteria { stage.criteria }

    private var projectedCpTone: StatusTone {
        thresholdTone(
            recommendation.simulatedMetrics.cpPctDm,
            minimum: criteria.cpMinimumPctDm,
            maximum: criteria.cpMaximumPctDm,
            cautionMinimum: criteria.cpCautionMinimumPctDm,
            cautionMaximum: criteria.cpCautionMaximumPctDm
        )
    }

    private var projectedTdnTone: StatusTone {
        thresholdTone(
            recommendation.simulatedMetrics.tdnPctDm,
            minimum: criteria.tdnMinimumPctDm,
            maximum: criteria.tdnMaximumPctDm,
            cautionMinimum: criteria.tdnCautionMinimumPctDm,
            cautionMaximum: criteria.tdnCautionMaximumPctDm
        )
    }

    private var projectedNdfTone: StatusTone {
        thresholdTone(
            recommendation.simulatedMetrics.ndfPctDm,
            minimum: criteria.ndfMinPctDm,
            maximum: criteria.ndfMaxPctDm,
            cautionMinimum: criteria.ndfCautionMinPctDm,
            cautionMaximum: criteria.ndfCautionMaxPctDm
        )
    }

    private var projectedAdfTone: StatusTone {
        thresholdTone(
            recommendation.simulatedMetrics.adfPctDm,
            minimum: criteria.adfMinPctDm,
            maximum: criteria.adfMaxPctDm,
            cautionMinimum: criteria.adfCautionMinPctDm,
            cautionMaximum: criteria.adfCautionMaxPctDm
        )
    }

    private var projectedCaTone: StatusTone {
        thresholdTone(
            recommendation.simulatedMetrics.caPctDm,
            minimum: criteria.caMinPctDm,
            maximum: criteria.caMaxPctDm,
            cautionMinimum: criteria.caCautionMinPctDm,
            cautionMaximum: criteria.caCautionMaxPctDm
        )
    }

    private var projectedPTone: StatusTone {
        thresholdTone(
            recommendation.simulatedMetrics.pPctDm,
            minimum: criteria.pMinPctDm,
            maximum: criteria.pMaxPctDm,
            cautionMinimum: criteria.pCautionMinPctDm,
            cautionMaximum: criteria.pCautionMaxPctDm
        )
    }

    private var projectedCaPRatioTone: StatusTone {
        thresholdTone(
            recommendation.simulatedMetrics.caPRatio,
            minimum: criteria.caPRatioMin,
            maximum: criteria.caPRatioMax,
            cautionMinimum: criteria.caPRatioCautionMin,
            cautionMaximum: criteria.caPRatioCautionMax
        )
    }

    private var projectedMoistureTone: StatusTone {
        moistureTone(recommendation.simulatedMetrics.moisturePct, criteria: criteria)
    }
}
