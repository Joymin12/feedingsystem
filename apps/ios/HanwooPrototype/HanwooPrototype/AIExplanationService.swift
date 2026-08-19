import Foundation

// MARK: - AI 설명 연동
//
// 계산·판정·교정은 앱 안에서 이미 끝나 있다. 이 서비스는 그 결과를 서버에 보내
// 농가가 읽기 쉬운 문장으로 받아오는 역할만 한다.
//
// 서버(NestJS)가 Gemini를 호출하고 응답을 검증한다. 앱이 구글을 직접 부르지 않는
// 이유는 API 키 때문이다. 앱 번들에 들어간 키는 추출될 수 있다.
//
// 실패는 정상 경로로 취급한다. 서버가 없거나, 키가 없거나, AI 응답이 검증을
// 통과하지 못하면 화면은 기존 내장 설명(RecommendationExplanationBuilder)을 그대로 쓴다.

struct AIExplanationRequest: Encodable {
    struct Judgement: Encodable {
        let key: String
        let label: String
        let value: Double
        let bandMin: Double?
        let bandMax: Double?
        let status: String
    }

    struct Action: Encodable {
        let name: String
        let fromKg: Double
        let toKg: Double
        let deltaKg: Double
        /// 농사로 사용수준 원문. AI가 설명의 근거로 인용하도록 함께 보낸다.
        let note: String?
    }

    let stage: String
    let formulaName: String?
    let totalAsFedKg: Double
    let judgements: [Judgement]
    let actions: [Action]
    let limitationNote: String?
    let engineSummary: String?
}

struct AIExplanationResponse: Decodable {
    let text: String
    let model: String
}

enum AIExplanationError: Error {
    /// 서버·네트워크·검증 실패를 모두 하나로 본다. 화면 동작이 동일하기 때문이다.
    case unavailable
}

@MainActor
final class AIExplanationService {

    /// 기본값은 시뮬레이터에서 로컬 서버를 가리킨다.
    /// 실기기 시연 때는 Info.plist의 AIExplanationBaseURL로 덮어쓴다.
    private let baseURL: URL

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

    func explain(_ request: AIExplanationRequest) async throws -> AIExplanationResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("v1/explanations"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 서버가 Gemini 응답을 최대 40초까지 기다리므로 그보다 여유를 둔다.
        urlRequest.timeoutInterval = 50
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw AIExplanationError.unavailable
        }

        guard
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode),
            let decoded = try? JSONDecoder().decode(AIExplanationResponse.self, from: data)
        else {
            throw AIExplanationError.unavailable
        }
        return decoded
    }
}

// MARK: - 엔진 결과 → 요청 페이로드

extension AIExplanationRequest {

    /// 화면이 이미 들고 있는 엔진 결과만으로 요청을 만든다.
    /// 사용자 계정 정보나 앱 내부 식별자는 넣지 않는다.
    init(
        recommendation: Recommendation,
        analysis: AnalysisRun,
        formula: FeedFormula,
        asFedKg: (IngredientLine) -> Double,
        limitationOverride: String? = nil
    ) {
        let stage = formula.stage
        let criteria = stage.criteria
        let metrics = analysis.metrics

        // 판정은 화면에 표시된 것과 같은 값을 쓴다. 여기서 다시 계산하지 않는다.
        let statusByNutrient = Dictionary(
            analysis.statuses.map { ($0.nutrient, $0.tone) },
            uniquingKeysWith: { first, _ in first }
        )

        func judgement(
            key: String,
            label: String,
            value: Double,
            min: Double?,
            max: Double?
        ) -> Judgement? {
            guard let tone = statusByNutrient[key] ?? statusByNutrient[label] else { return nil }
            return Judgement(
                key: key,
                label: label,
                value: (value * 10).rounded() / 10,
                bandMin: min,
                bandMax: max,
                status: tone.rawValue
            )
        }

        let candidates: [Judgement?] = [
            judgement(key: "CP", label: "CP", value: metrics.cpPctDm,
                      min: criteria.cpMinimumPctDm, max: criteria.cpMaximumPctDm),
            judgement(key: "TDN", label: "TDN", value: metrics.tdnPctDm,
                      min: criteria.tdnMinimumPctDm, max: criteria.tdnMaximumPctDm),
            judgement(key: "EE", label: "EE", value: metrics.eePctDm,
                      min: nil, max: criteria.eeMaxPctDm),
            judgement(key: "NDF", label: "NDF", value: metrics.ndfPctDm,
                      min: criteria.ndfBand.minimum, max: criteria.ndfBand.maximum),
            judgement(key: "ADF", label: "ADF", value: metrics.adfPctDm,
                      min: criteria.adfBand.minimum, max: criteria.adfBand.maximum),
            judgement(key: "Ca", label: "Ca", value: metrics.caPctDm,
                      min: criteria.caMinPctDm, max: criteria.caMaxPctDm),
            judgement(key: "P", label: "P", value: metrics.pPctDm,
                      min: criteria.pMinPctDm, max: criteria.pMaxPctDm),
            judgement(key: "Ca:P", label: "Ca:P", value: metrics.caPRatio,
                      min: criteria.caPRatioMin, max: criteria.caPRatioMax),
            judgement(key: "수분", label: "수분", value: metrics.moisturePct,
                      min: criteria.moistureBand.minimum, max: criteria.moistureBand.maximum),
        ]

        // 화면의 "기존 kg → 적용 후 kg" 표시와 같은 방식으로 계산한다.
        let actions: [Action] = recommendation.correctionActions.map { action in
            let before = formula.items
                .filter { $0.definitionID != nil && $0.definitionID == action.ingredientID }
                .reduce(0.0) { $0 + asFedKg($1) }
            let isIncrease = action.type != .decrease
            let after = isIncrease ? before + action.amountKg : max(0, before - action.amountKg)
            // 농사로 사용수준 원문을 함께 보낸다. AI가 이 원료를 왜 늘리고 줄였는지
            // 설명할 때 국가 기준을 근거로 인용하게 하려는 것이다.
            // 한도 준수 자체는 교정 엔진이 이미 끝냈으므로 AI가 판단할 일은 없다.
            let note = action.ingredientID
                .flatMap { IngredientUsageLimits.limit(for: $0) }
                .map { $0.useLevel(for: stage) }

            return Action(
                name: action.ingredientName,
                fromKg: (before * 10).rounded() / 10,
                toKg: (after * 10).rounded() / 10,
                deltaKg: ((after - before) * 10).rounded() / 10,
                note: note
            )
        }

        self.init(
            stage: stage.title,
            formulaName: formula.name,
            totalAsFedKg: (metrics.totalAsFedKg * 10).rounded() / 10,
            judgements: candidates.compactMap { $0 },
            actions: actions,
            limitationNote: limitationOverride ?? (recommendation.isFullyResolved ? nil : recommendation.reason),
            engineSummary: analysis.summary
        )
    }
}
