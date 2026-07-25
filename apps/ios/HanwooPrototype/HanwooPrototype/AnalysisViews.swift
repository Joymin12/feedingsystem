import SwiftUI

// MARK: - 분석 결과 / 최근 분석 화면

struct AnalysisDetailView: View {
    @EnvironmentObject private var store: PrototypeStore
    let formulaID: UUID
    @State private var didSaveSnapshot = false

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
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppPalette.surface)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppPalette.hairline, lineWidth: 1))
                        }
                    }

                    NavigationLink {
                        AIRecommendationView(formulaID: formulaID)
                    } label: {
                        Text("추천안 보기 — 증감 시뮬레이션")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        store.saveAnalysisSnapshot(for: formula)
                        didSaveSnapshot = true
                    } label: {
                        Text(didSaveSnapshot ? "저장됨 ✓" : "이 분석 저장")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(didSaveSnapshot)
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
    @State private var pendingDeletion: SavedAnalysis?

    var body: some View {
        List {
            Section {
                if store.savedAnalyses.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "저장된 분석이 없습니다",
                        message: "분석 결과 화면에서 '이 분석 저장'을 누르면 배합과 결과가 함께 보관되어 언제든 다시 볼 수 있습니다."
                    )
                } else {
                    ForEach(store.savedAnalyses) { record in
                        NavigationLink {
                            SavedAnalysisDetailView(record: record)
                                .environmentObject(store)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(record.formula.name)
                                        .font(.headline)
                                    Spacer()
                                    if let primary = defaultRecommendation(from: record.recommendations) {
                                        StatusPill(
                                            title: primary.isFullyResolved ? "적정 도달" : "교정 필요",
                                            tone: primary.isFullyResolved ? .adequate : .caution
                                        )
                                    }
                                }
                                Text("\(record.formula.stage.title) · \(dateTimeString(record.savedAt)) 저장")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(record.summary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDeletion = record
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                            Button {
                                store.duplicateSavedAnalysis(id: record.id)
                            } label: {
                                Label("복제", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            } header: {
                Text("저장된 분석")
            } footer: {
                Text("저장 당시 배합과 엔진 버전이 함께 기록되어, 이후 앱이 갱신되어도 같은 값이 표시됩니다.")
            }

            Section("현재 배합 바로 분석") {
                ForEach(store.userFacingAnalyses) { analysis in
                    NavigationLink {
                        AnalysisDetailView(formulaID: analysis.formulaId)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(analysis.formulaName)
                                .font(.headline)
                            Text(analysis.stage.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("최근 분석")
        .alert("저장된 분석을 삭제할까요?", isPresented: deletionBinding) {
            Button("취소", role: .cancel) { pendingDeletion = nil }
            Button("삭제", role: .destructive) {
                if let pendingDeletion {
                    store.deleteSavedAnalysis(id: pendingDeletion.id)
                }
                pendingDeletion = nil
            }
        } message: {
            if let pendingDeletion {
                Text("'\(pendingDeletion.formula.name)' 분석 기록이 삭제됩니다. 되돌릴 수 없습니다.")
            }
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }
}

// 저장된 분석 스냅샷 상세. 다시 계산하지 않고 저장 당시 값을 그대로 보여준다.
struct SavedAnalysisDetailView: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss
    let record: SavedAnalysis
    @State private var shareItems: [Any]?
    @State private var exportFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.formula.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("\(record.formula.stage.title) · \(dateTimeString(record.savedAt)) 저장 · 엔진 v\(record.algorithmVersion)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(record.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                SectionCard(title: "배합 구성", subtitle: "저장 당시 원료와 투입량 (원물 기준)") {
                    VStack(spacing: 8) {
                        ForEach(record.formula.items) { item in
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(numberString(asFedKg(for: item)))kg")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        HStack {
                            Text("합계").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(numberString(record.metrics.totalAsFedKg))kg")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                    }
                }

                SectionCard(title: "판정 결과", subtitle: "저장 당시 기준") {
                    VStack(spacing: 10) {
                        ForEach(record.statuses) { status in
                            HStack {
                                Text(status.nutrient)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(status.currentValue)
                                    .font(.subheadline.monospacedDigit())
                                StatusPill(title: status.tone.title, tone: status.tone)
                            }
                        }
                    }
                }

                if let primary = defaultRecommendation(from: record.recommendations) {
                    SectionCard(title: "저장된 추천안", subtitle: primary.title) {
                        VStack(alignment: .leading, spacing: 8) {
                            if primary.correctionActions.isEmpty {
                                Text(primary.reason)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(primary.correctionActions) { action in
                                    HStack {
                                        Image(systemName: action.type == .decrease ? "arrow.down.circle" : "arrow.up.circle")
                                            .foregroundStyle(action.type == .decrease ? .orange : AppPalette.primary)
                                        Text(action.ingredientName)
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(action.type == .decrease ? "−" : "+")\(numberString(action.amountKg))kg")
                                            .font(.subheadline.monospacedDigit())
                                    }
                                }
                                Text(primary.reason)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button {
                    store.restoreFormula(from: record)
                    dismiss()
                } label: {
                    Text("이 배합을 현재 배합으로 복원")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("저장된 분석")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        share(url: ExportService.csvURL(for: record))
                    } label: {
                        Label("CSV로 내보내기", systemImage: "tablecells")
                    }
                    Button {
                        share(url: ExportService.pdfURL(for: record))
                    } label: {
                        Label("PDF로 내보내기·인쇄", systemImage: "doc.richtext")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("내보내기")
            }
        }
        .sheet(isPresented: shareBinding) {
            if let shareItems {
                ActivityShareSheet(items: shareItems)
            }
        }
        .alert("내보내기에 실패했습니다", isPresented: $exportFailed) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("파일을 만들지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해주세요.")
        }
    }

    private func share(url: URL?) {
        guard let url else {
            exportFailed = true
            return
        }
        shareItems = [url]
    }

    private var shareBinding: Binding<Bool> {
        Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )
    }
}
