import SwiftUI

// MARK: - 사육일지 화면

struct DiaryListView: View {
    @EnvironmentObject private var store: PrototypeStore

    var body: some View {
        List {
            Section {
                NavigationLink {
                    DiaryEditorView(mode: .create)
                } label: {
                    Text("오늘 기록 추가")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Section("전체 사육일지") {
                ForEach(store.diaryEntries) { entry in
                    NavigationLink {
                        DiaryDetailView(entryID: entry.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dateString(entry.date))
                                .font(.headline)
                            HStack(spacing: 8) {
                                Text(store.formula(for: entry.formulaId)?.name ?? "분석 기준 배합")
                                    .font(.subheadline)
                                if store.formula(for: entry.formulaId)?.isTestFormula == true {
                                    StatusPill(title: "테스트 배합", tone: .caution)
                                }
                            }
                            Text("변 \(entry.stoolStatus) · 성장 \(entry.growthStatus)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(entry.nextFeedback)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .navigationTitle("사육일지")
    }
}

struct DiaryDetailView: View {
    @EnvironmentObject private var store: PrototypeStore
    let entryID: UUID

    var body: some View {
        ScrollView {
            if let entry = store.diaryEntries.first(where: { $0.id == entryID }),
               let formula = store.formula(for: entry.formulaId) {
                VStack(alignment: .leading, spacing: 20) {
                    SectionCard(title: "분석 기준 배합", subtitle: formula.name) {
                        VStack(alignment: .leading, spacing: 8) {
                            if formula.isTestFormula {
                                StatusPill(title: "테스트 배합", tone: .caution)
                            }
                            Text(formula.items.map { "\($0.name) \(formattedAmount($0))" }.joined(separator: " · "))
                                .font(.headline)
                        }
                        Text("이 배합을 기준으로 실제 급여와 경과를 수기로 기록하는 구조입니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    SectionCard(title: dateString(entry.date), subtitle: "기록 상세") {
                        DetailRow(title: "변 상태", value: entry.stoolStatus)
                        DetailRow(title: "성장 속도", value: entry.growthStatus)
                        DetailRow(title: "다음 피드백", value: entry.nextFeedback)
                        DetailRow(title: "자유 기록", value: entry.note)
                    }

                    NavigationLink {
                        DiaryEditorView(mode: .edit(entryID))
                    } label: {
                        Text("기록 수정")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("기록 상세")
    }
}

struct DiaryEditorView: View {
    enum Mode {
        case create
        case edit(UUID)
    }

    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var selectedFormulaID: UUID?
    @State private var date = Date.now
    @State private var stoolStatus = ""
    @State private var growthStatus = ""
    @State private var nextFeedback = ""
    @State private var note = ""
    @State private var editingID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(modeTitle)
                    .font(.largeTitle.bold())

                SectionCard(title: "배합비 선택", subtitle: "분석 기준 배합 1개를 연결합니다") {
                    VStack(spacing: 12) {
                        ForEach(store.userFacingFormulas) { formula in
                            Button {
                                selectedFormulaID = formula.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text(formula.name)
                                                .font(.headline)
                                            if formula.isTestFormula {
                                                StatusPill(title: "테스트 배합", tone: .caution)
                                            }
                                        }
                                        Text(formula.items.map { "\($0.name) \(formattedAmount($0))" }.joined(separator: " · "))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: selectedFormulaID == formula.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedFormulaID == formula.id ? Color.green : .secondary)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(AppPalette.surfaceMuted)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SectionCard(title: "글쓰기", subtitle: "경과를 직접 기록합니다") {
                    VStack(spacing: 16) {
                        DatePicker("기록 날짜", selection: $date, displayedComponents: .date)

                        LabeledTextField(title: "변 상태", text: $stoolStatus, placeholder: "예: 약간 무름")
                        LabeledTextField(title: "성장 속도", text: $growthStatus, placeholder: "예: 무난")
                        LabeledTextField(title: "다음 피드백", text: $nextFeedback, placeholder: "예: 옥수수 1kg 낮춰보기")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("자유 기록")
                                .font(.headline)
                            TextEditor(text: $note)
                                .frame(height: 140)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 14).fill(AppPalette.surfaceMuted))
                        }
                    }
                }

                Button(modeButtonTitle) {
                    save()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: loadIfNeeded)
    }

    private var modeTitle: String {
        switch mode {
        case .create: "기록 추가"
        case .edit: "기록 수정"
        }
    }

    private var modeButtonTitle: String {
        switch mode {
        case .create: "기록 저장"
        case .edit: "수정 저장"
        }
    }

    private func loadIfNeeded() {
        switch mode {
        case .create:
            if selectedFormulaID == nil {
                selectedFormulaID = store.preferredSelectedFormulaID()
            }
        case let .edit(entryID):
            guard let entry = store.diaryEntries.first(where: { $0.id == entryID }) else { return }
            editingID = entry.id
            selectedFormulaID = entry.formulaId
            date = entry.date
            stoolStatus = entry.stoolStatus
            growthStatus = entry.growthStatus
            nextFeedback = entry.nextFeedback
            note = entry.note
        }
    }

    private func save() {
        guard let formulaID = selectedFormulaID else { return }
        let entry = DiaryEntry(
            id: editingID ?? UUID(),
            date: date,
            formulaId: formulaID,
            stoolStatus: stoolStatus.isEmpty ? "미입력" : stoolStatus,
            growthStatus: growthStatus.isEmpty ? "미입력" : growthStatus,
            nextFeedback: nextFeedback.isEmpty ? "다음 기록 때 보완" : nextFeedback,
            note: note.isEmpty ? "현장 기록이 아직 없습니다." : note,
            lastUpdatedAt: .now
        )
        store.saveDiary(entry)
        dismiss()
    }
}
