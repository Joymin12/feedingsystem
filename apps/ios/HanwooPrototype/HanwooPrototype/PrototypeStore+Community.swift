import SwiftUI

// MARK: - PrototypeStore 커뮤니티 책임
// 게시글 생성/삭제, 권한, 시드/영속화.

extension PrototypeStore {
    func performCreatePost(
        title: String,
        excerpt: String,
        label: String,
        attachedFormula: CommunityPost.AttachedFormula? = nil
    ) async -> String? {
        if usesSupabase {
            do {
                posts = try await supabaseService.createPost(title: title, excerpt: excerpt, label: label)
                return nil
            } catch {
                return error.localizedDescription
            }
        }

        createPost(title: title, excerpt: excerpt, label: label, attachedFormula: attachedFormula)
        return nil
    }

    func performDeletePost(id: UUID) async -> String? {
        if usesSupabase {
            do {
                posts = try await supabaseService.deletePost(id: id)
                return nil
            } catch {
                return error.localizedDescription
            }
        }

        deletePost(id: id)
        return nil
    }

    func createPost(
        title: String,
        excerpt: String,
        label: String,
        attachedFormula: CommunityPost.AttachedFormula? = nil
    ) {
        guard let currentUser else { return }
        let post = CommunityPost(
            title: title,
            excerpt: excerpt,
            label: label,
            authorLoginID: currentUser.loginID,
            authorDisplayName: currentUser.displayName,
            attachedFormula: attachedFormula
        )
        posts.insert(post, at: 0)
        savePosts()
    }

    func canDelete(post: CommunityPost) -> Bool {
        guard let currentUser else { return false }
        return currentUser.isAdmin || currentUser.loginID == post.authorLoginID
    }

    func deletePost(id: UUID) {
        guard let post = posts.first(where: { $0.id == id }), canDelete(post: post) else { return }
        posts.removeAll(where: { $0.id == id })
        savePosts()
    }

    static func seedPosts() -> [CommunityPost] {
        [
            CommunityPost(
                title: "비육전기 배합에서 수분이 높을 때",
                excerpt: "습식 원료를 바로 늘리기보다 먼저 현재 조사료 구조를 점검한 경험을 공유합니다.",
                label: "현장 팁",
                authorLoginID: "qwer123",
                authorDisplayName: "관리자"
            ),
            CommunityPost(
                title: "육성기 조사료 비율 조정 후기",
                excerpt: "반추위 발달을 위해 조사료를 유지했을 때 섭취 반응이 어떻게 달라졌는지 정리했습니다.",
                label: "후기",
                authorLoginID: "qwer123",
                authorDisplayName: "관리자"
            ),
            CommunityPost(
                title: "사육일지를 어떻게 쓰고 있는지",
                excerpt: "배합 기준과 실제 급여 차이를 기록하는 방법을 예시로 적었습니다.",
                label: "기록법",
                authorLoginID: "qwer123",
                authorDisplayName: "관리자"
            )
        ]
    }

    func savePosts() {
        postRepository.savePosts(posts)
    }

    // MARK: - 배합 첨부

    /// 배합을 게시글에 붙일 스냅샷으로 바꾼다.
    /// 성분값은 지금 계산해서 함께 담는다. 나중에 원료 DB가 갱신되어도
    /// 글에 적힌 값이 흔들리지 않게 하기 위해서다.
    func attachmentSnapshot(for formula: FeedFormula) -> CommunityPost.AttachedFormula {
        let metrics = calculateMetrics(for: formula).metrics
        return CommunityPost.AttachedFormula(
            name: formula.name,
            stageTitle: formula.stage.title,
            totalAsFedKg: metrics.totalAsFedKg,
            items: formula.items.map {
                .init(name: $0.name, amountKg: asFedKg(for: $0))
            },
            cpPctDm: metrics.cpPctDm,
            tdnPctDm: metrics.tdnPctDm,
            moisturePct: metrics.moisturePct
        )
    }

    // MARK: - 커뮤니티 공유 자격

    /// 커뮤니티에 첨부할 수 있는 배합인지.
    ///
    /// 기준을 벗어난 항목(부족, 과잉)이 하나라도 있으면 올릴 수 없다.
    /// 커뮤니티 글은 다른 농가가 보고 따라 하는 자료이므로,
    /// 아직 손봐야 할 배합이 참고 자료로 퍼지면 오히려 해가 된다.
    /// 주의 구간은 허용한다. 완전히 손댈 곳이 없는 배합은 현실에서 드물기 때문이다.
    func canShareToCommunity(_ formula: FeedFormula) -> Bool {
        shareBlockingNutrients(formula).isEmpty
    }

    /// 공유를 막고 있는 항목 이름들. 사용자에게 이유를 보여주기 위해 쓴다.
    func shareBlockingNutrients(_ formula: FeedFormula) -> [String] {
        let metrics = calculateMetrics(for: formula).metrics
        let statuses = buildStatuses(
            stage: formula.stage,
            criteria: formula.stage.criteria,
            metrics: metrics
        )
        return statuses
            .filter { $0.tone == .deficient || $0.tone == .excess }
            .map(\.nutrient)
    }
}
