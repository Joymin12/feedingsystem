import SwiftUI

// MARK: - 분석 결과 / 최근 분석 화면

struct AnalysisDetailView: View {
    @EnvironmentObject private var store: PrototypeStore
    let formulaID: UUID

    var body: some View {
        ScrollView {
            if let formula = store.formula(for: formulaID) {
                let analysis = store.analysis(for: formula)

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            Text(formula.name)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                            if formula.isTestFormula {
                                StatusPill(title: "테스트 배합", tone: .caution)
                            }
                        }

                        Text(dateTimeString(analysis.checkedAt))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(analysis.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        MetricTile(title: "수분", value: percentString(analysis.metrics.moisturePct), accent: AppPalette.primary)
                        MetricTile(title: "CP", value: percentString(analysis.metrics.cpPctDm), accent: AppPalette.ink)
                        MetricTile(title: "TDN", value: percentString(analysis.metrics.tdnPctDm), accent: AppPalette.warning)
                    }

                    SectionCard(title: "원물 투입 현황", subtitle: "원료별 원물 투입량과 건물 환산량") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("원료")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("원물량")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .trailing)
                                Text("건물량")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.bottom, 6)
                            Divider()

                            ForEach(formula.items) { item in
                                let fedKg = asFedKg(for: item)
                                let dmKg: Double? = item.definitionID
                                    .flatMap { store.ingredientDefinition(id: $0)?.nutrition.dmPct }
                                    .map { fedKg * $0 / 100 }
                                HStack {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(numberString(fedKg))kg")
                                        .font(.subheadline.monospacedDigit())
                                        .frame(width: 72, alignment: .trailing)
                                    if let dm = dmKg {
                                        Text("\(numberString(dm))kg")
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                    } else {
                                        Text("—")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                }
                                .padding(.vertical, 6)
                                Divider()
                            }

                            HStack {
                                Text("합계")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(numberString(analysis.metrics.totalAsFedKg))kg")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .frame(width: 72, alignment: .trailing)
                                Text("\(numberString(analysis.metrics.totalDmKg))kg")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(Color.green)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.top, 6)
                        }
                    }

                    SectionCard(title: "건물 기준 영양소", subtitle: "DM 기준 영양소 함량 (총 건물량 대비 %)") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            NutrientMetricCell(title: "수분", value: percentString(analysis.metrics.moisturePct))
                            NutrientMetricCell(title: "Ca:P", value: ratioString(analysis.metrics.caPRatio))
                            NutrientMetricCell(title: "CP", value: percentString(analysis.metrics.cpPctDm))
                            NutrientMetricCell(title: "TDN", value: percentString(analysis.metrics.tdnPctDm))
                            NutrientMetricCell(title: "NDF", value: percentString(analysis.metrics.ndfPctDm))
                            NutrientMetricCell(title: "ADF", value: percentString(analysis.metrics.adfPctDm))
                            NutrientMetricCell(title: "NFC", value: percentString(analysis.metrics.nfcPctDm))
                            NutrientMetricCell(title: "EE", value: percentString(analysis.metrics.eePctDm))
                            NutrientMetricCell(title: "Ca", value: percentString(analysis.metrics.caPctDm))
                            NutrientMetricCell(title: "P", value: percentString(analysis.metrics.pPctDm))
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("판정 결과")
                            .font(.title3.bold())
                        ForEach(analysis.statuses) { status in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(status.nutrient)
                                        .font(.headline)
                                    Spacer()
                                    StatusPill(title: status.tone.title, tone: status.tone)
                                }
                                Text("현재 \(status.currentValue) · 기준 \(status.targetValue)")
                                    .font(.subheadline)
                                Text(status.message)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                        }
                    }

                    NavigationLink {
                        AIRecommendationView(formulaID: formulaID)
                    } label: {
                        Text("추천안 보기")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    NavigationLink {
                        DiaryListView()
                    } label: {
                        Text("사육일지 열기")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
            }
        }
        .background(AppScreenBackground())
        .navigationTitle("분석 결과")
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: PrototypeStore

    var body: some View {
        List(store.userFacingAnalyses) { analysis in
            NavigationLink {
                AnalysisDetailView(formulaID: analysis.formulaId)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(analysis.formulaName)
                            .font(.headline)
                        if store.formula(for: analysis.formulaId)?.isTestFormula == true {
                            StatusPill(title: "테스트 배합", tone: .caution)
                        }
                    }
                    Text(analysis.stage.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(analysis.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("최근 분석")
    }
}
