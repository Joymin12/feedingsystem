import SwiftUI

// MARK: - 커뮤니티 화면

struct CommunityView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var isShowingComposer = false
    @State private var communityError = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("커뮤니티")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                ForEach(store.posts) { post in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                StatusPill(title: post.label, tone: .adequate)
                                Text(post.title)
                                    .font(.headline)
                                Text(post.excerpt)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("\(post.authorDisplayName) · \(dateString(post.createdAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                // 글에 배합이 붙어 있으면 원료 구성까지 함께 보여준다.
                                if let attached = post.attachedFormula {
                                    postAttachment(attached)
                                }
                            }
                            Spacer()
                            if store.canDelete(post: post) {
                                Button(role: .destructive) {
                                    Task {
                                        if let error = await store.performDeletePost(id: post.id) {
                                            await MainActor.run {
                                                communityError = error
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(AppPalette.surface)
                    )
                }

                if !communityError.isEmpty {
                    Text(communityError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("커뮤니티")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("글쓰기") {
                    isShowingComposer = true
                }
            }
        }
        .sheet(isPresented: $isShowingComposer) {
            CommunityPostComposerView()
                .environmentObject(store)
        }
    }

    // MARK: 첨부된 배합

    private func postAttachment(_ attached: CommunityPost.AttachedFormula) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "paperclip")
                    .font(.caption2)
                Text(attached.name)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(attached.stageTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(AppPalette.ink)

            Text("총 \(numberString(attached.totalAsFedKg))kg · CP \(percentString(attached.cpPctDm)) · TDN \(percentString(attached.tdnPctDm)) · 수분 \(percentString(attached.moisturePct))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(attached.items.map { "\($0.name) \(numberString($0.amountKg))kg" }.joined(separator: ", "))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppPalette.surfaceMuted))
        .padding(.top, 4)
    }

}

struct CommunityPostComposerView: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var excerpt = ""
    @State private var label = "현장 팁"
    @State private var submitError = ""
    @State private var isSubmitting = false
    /// 글에 붙일 배합. 선택하지 않으면 글만 올라간다.
    @State private var attachedFormulaID: UUID?
    @State private var isPickingFormula = false

    private let labels = ["현장 팁", "후기", "기록법", "질문"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionCard(title: "커뮤니티 글쓰기", subtitle: "") {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledTextField(title: "제목", text: $title, placeholder: "예: 비지 비중을 낮췄을 때 반응")
                            VStack(alignment: .leading, spacing: 8) {
                                Text("분류")
                                    .font(.headline)
                                Picker("분류", selection: $label) {
                                    ForEach(labels, id: \.self) { item in
                                        Text(item).tag(item)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("요약")
                                    .font(.headline)
                                TextEditor(text: $excerpt)
                                    .frame(height: 180)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(AppPalette.surfaceMuted))
                            }
                        }
                    }

                    // 배합을 붙이면 "무엇을 먹였는지"가 글과 함께 남는다.
                    // 글만 있는 경험담보다 다른 농가가 참고하기 쉬워진다.
                    attachmentCard

                    Button("등록") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedExcerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedTitle.isEmpty, !trimmedExcerpt.isEmpty else { return }
                        isSubmitting = true
                        submitError = ""
                        Task {
                            let attachment = attachedFormulaID
                                .flatMap { store.formula(for: $0) }
                                .map { store.attachmentSnapshot(for: $0) }
                            let error = await store.performCreatePost(
                                title: trimmedTitle,
                                excerpt: trimmedExcerpt,
                                label: label,
                                attachedFormula: attachment
                            )
                            await MainActor.run {
                                isSubmitting = false
                                if let error {
                                    submitError = error
                                } else {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSubmitting)

                    if !submitError.isEmpty {
                        Text(submitError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(AppScreenBackground())
            .navigationTitle("글쓰기")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    // MARK: 배합 첨부

    private var attachmentCard: some View {
        SectionCard(title: "배합 첨부 (선택)", subtitle: "") {
            if let id = attachedFormulaID, let formula = store.formula(for: id) {
                let snapshot = store.attachmentSnapshot(for: formula)
                VStack(alignment: .leading, spacing: 10) {
                    attachmentPreview(snapshot)
                    HStack(spacing: 12) {
                        Button("다른 배합 선택") { isPickingFormula = true }
                            .font(.footnote)
                        Button("첨부 취소", role: .destructive) { attachedFormulaID = nil }
                            .font(.footnote)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        isPickingFormula = true
                    } label: {
                        Label("내 배합 선택", systemImage: "paperclip")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .sheet(isPresented: $isPickingFormula) {
            FormulaAttachPicker { id in
                attachedFormulaID = id
                isPickingFormula = false
            }
            .environmentObject(store)
        }
    }

    private func attachmentPreview(_ snapshot: CommunityPost.AttachedFormula) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(snapshot.stageTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("총 \(numberString(snapshot.totalAsFedKg))kg · CP \(percentString(snapshot.cpPctDm)) · TDN \(percentString(snapshot.tdnPctDm))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(snapshot.items.map { "\($0.name) \(numberString($0.amountKg))kg" }.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppPalette.surfaceMuted))
    }

}

// MARK: - 글에 붙일 배합 선택

struct FormulaAttachPicker: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss
    let onSelect: (UUID) -> Void

    var body: some View {
        NavigationStack {
            List(store.formulas) { formula in
                let blocking = store.shareBlockingNutrients(formula)
                let canShare = blocking.isEmpty

                Button {
                    guard canShare else { return }
                    onSelect(formula.id)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(formula.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(canShare ? AppPalette.ink : Color.secondary)
                            Spacer()
                            StatusPill(
                                title: canShare ? "기준 만족" : "기준 미달",
                                tone: canShare ? .adequate : .deficient
                            )
                        }
                        Text("\(formula.stage.title) · 원료 \(formula.items.count)종")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !canShare {
                            // 왜 못 올리는지 항목을 그대로 알려준다.
                            Text("\(blocking.prefix(4).joined(separator: ", ")) 기준을 벗어나 올릴 수 없습니다")
                                .font(.caption2)
                                .foregroundStyle(AppPalette.warning)
                        }
                    }
                }
                .disabled(!canShare)
            }
            .navigationTitle("배합 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}
