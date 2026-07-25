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
                Text("첫 설치형 프로토타입에서는 읽기 중심 화면으로 둡니다.")
                    .foregroundStyle(.secondary)

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
}

struct CommunityPostComposerView: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var excerpt = ""
    @State private var label = "현장 팁"
    @State private var submitError = ""
    @State private var isSubmitting = false

    private let labels = ["현장 팁", "후기", "기록법", "질문"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionCard(title: "커뮤니티 글쓰기", subtitle: "제목, 본문 요약, 분류를 입력합니다") {
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
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                            }
                        }
                    }

                    Button("등록") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedExcerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedTitle.isEmpty, !trimmedExcerpt.isEmpty else { return }
                        isSubmitting = true
                        submitError = ""
                        Task {
                            let error = await store.performCreatePost(title: trimmedTitle, excerpt: trimmedExcerpt, label: label)
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
}
