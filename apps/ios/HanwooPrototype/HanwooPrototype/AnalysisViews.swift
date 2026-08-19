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

                    SectionCard(title: "영양소 판정", subtitle: "건물(DM) 기준") {
                        VStack(spacing: 0) {
                            ForEach(Array(analysis.statuses.enumerated()), id: \.element.id) { index, status in
                                if index > 0 { Divider() }
                                nutrientRow(status)
                            }
                        }
                    }

                    NavigationLink {
                        AIRecommendationView(formulaID: formulaID)
                    } label: {
                        Text("추천안 보기 — 증감 시뮬레이션")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    // 엔진이 찾아주는 안과 별개로, 직접 밀고 당겨보는 경로.
                    NavigationLink {
                        AdjustmentSliderView(formulaID: formulaID)
                    } label: {
                        Text("직접 증감해보기")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

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
                .task {
                    // 사용 중인 원료 목록만 서버에 남긴다. 투입량은 보내지 않는다.
                    // 실패해도 화면 동작에는 영향이 없다.
                    await UsageReportService().report(formula: formula)
                }
            }
        }
        .background(AppScreenBackground())
        .navigationTitle("분석 결과")
    }

    // MARK: 영양소 한 줄

    private func nutrientRow(_ status: NutrientStatus) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(status.nutrient)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 58, alignment: .leading)

                Text(status.currentValue)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppPalette.ink)

                Spacer()

                StatusPill(title: status.tone.title, tone: status.tone)
            }

            // 설명 문구는 두지 않는다. 왜 그런지는 추천안 화면의 AI 설명이 맡고,
            // 이 화면은 "지금 어떤 상태인가"만 빠르게 훑도록 기준값만 남긴다.
            Text("기준 \(status.targetValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 11)
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

            // 목록에는 이름과 단계만 쓴다. 분석 결과를 미리 계산하면
            // 배합 수만큼 교정 엔진이 돌아 목록 진입이 느려진다.
            Section("현재 배합 바로 분석") {
                ForEach(store.userFacingFormulas) { formula in
                    NavigationLink {
                        AnalysisDetailView(formulaID: formula.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(formula.name)
                                .font(.headline)
                            Text(formula.stage.title)
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
