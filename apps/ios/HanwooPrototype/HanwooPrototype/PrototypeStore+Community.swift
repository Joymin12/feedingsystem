import SwiftUI

// MARK: - PrototypeStore 커뮤니티 책임
// 게시글 생성/삭제, 권한, 시드/영속화.

extension PrototypeStore {
    func performCreatePost(title: String, excerpt: String, label: String) async -> String? {
        if usesSupabase {
            do {
                posts = try await supabaseService.createPost(title: title, excerpt: excerpt, label: label)
                return nil
            } catch {
                return error.localizedDescription
            }
        }

        createPost(title: title, excerpt: excerpt, label: label)
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

    func createPost(title: String, excerpt: String, label: String) {
        guard let currentUser else { return }
        let post = CommunityPost(
            title: title,
            excerpt: excerpt,
            label: label,
            authorLoginID: currentUser.loginID,
            authorDisplayName: currentUser.displayName
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
}
