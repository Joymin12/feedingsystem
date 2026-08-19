import Foundation

// MARK: - 원료 사용 기록 전송
//
// 서버에 남기는 것은 "이 농가가 어떤 원료를 쓰고 있는가" 뿐이다.
// 투입량(kg)과 배합 비율은 보내지 않는다. 배합비는 농가가 쌓아온 노하우이고,
// 서버가 그것까지 가져가면 앱을 쓸 이유가 사라진다.
//
// 배합 전체가 서버에 올라가는 경우는 하나뿐이다. 사용자가 커뮤니티에 직접 첨부할 때.
// 그때는 사용자가 공개를 선택한 것이라 성격이 다르다.
//
// 농가 식별도 계정 ID가 아니라 기기에서 만든 익명 키를 쓴다.
// 누가 썼는지가 아니라 몇 농가가 쓰는지를 알면 되는 용도이기 때문이다.

@MainActor
final class UsageReportService {

    private let baseURL: URL

    /// 기기마다 한 번 만들어 재사용하는 익명 키.
    private static let farmKeyDefaultsKey = "hanwoo.prototype.anonymousFarmKey"

    static var farmKey: String {
        if let saved = UserDefaults.standard.string(forKey: farmKeyDefaultsKey) {
            return saved
        }
        let generated = "farm-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)
        UserDefaults.standard.set(String(generated), forKey: farmKeyDefaultsKey)
        return String(generated)
    }

    init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else if
            let configured = Bundle.main.object(forInfoDictionaryKey: "AIExplanationBaseURL") as? String,
            let url = URL(string: configured)
        {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "http://127.0.0.1:3001")!
        }
    }

    private struct Payload: Encodable {
        struct Ingredient: Encodable {
            let id: String
            let name: String
        }
        let farmKey: String
        let stage: String
        let ingredients: [Ingredient]
    }

    /// 배합에서 원료 목록만 뽑아 보낸다.
    /// 실패해도 아무것도 하지 않는다. 부가 기록이라 사용자 흐름을 막아서는 안 된다.
    func report(formula: FeedFormula) async {
        let ingredients: [Payload.Ingredient] = formula.items.compactMap { item in
            guard let id = item.definitionID else { return nil }
            return Payload.Ingredient(id: id, name: item.name)
        }
        guard !ingredients.isEmpty else { return }

        let payload = Payload(
            farmKey: Self.farmKey,
            stage: formula.stage.title,
            ingredients: ingredients
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/ingredient-usage"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpBody = try? JSONEncoder().encode(payload)

        _ = try? await URLSession.shared.data(for: request)
    }
}
