import Foundation

// MARK: - 영양소 계산/판정 공용 유틸리티
// 건물(DM) 환산, 범위 거리, 상태 톤 판정, 원료 분류 집합, 대표 추천 선정.
// 모두 순수 함수/상수 — SwiftUI/@Published/UserDefaults 비의존.

// MARK: 건물 환산 기초

func asFedKg(for item: IngredientLine) -> Double {
    switch item.unit {
    case .kg:
        return item.amount
    case .g:
        return item.amount / 1000
    }
}

func nutrientKg(dmKg: Double, pctDm: Double) -> Double {
    dmKg * pctDm / 100
}

func pctDm(_ nutrientKg: Double, _ totalDmKg: Double) -> Double {
    guard totalDmKg > 0 else { return 0 }
    return nutrientKg / totalDmKg * 100
}

// MARK: 범위 거리 / 클램프

func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
    min(max(value, lower), upper)
}

func rangeDistance(_ value: Double, minimum: Double, maximum: Double) -> Double {
    if value < minimum { return minimum - value }
    if value > maximum { return value - maximum }
    return 0
}

func caPRatioDistance(_ ratio: Double, criteria: StageCriteria) -> Double {
    rangeDistance(ratio, minimum: criteria.caPRatioMin, maximum: criteria.caPRatioMax)
}

// MARK: 상태 톤 판정

func thresholdTone(
    _ value: Double,
    minimum: Double,
    maximum: Double,
    cautionMinimum: Double,
    cautionMaximum: Double
) -> StatusTone {
    // Non-overlapping bands:
    // deficient: value < cautionMinimum
    // caution-low: cautionMinimum <= value < minimum
    // adequate: minimum <= value <= maximum
    // caution-high: maximum < value <= cautionMaximum
    // excess: value > cautionMaximum
    if value < cautionMinimum {
        return .deficient
    }
    if value < minimum {
        return .caution
    }
    if value <= maximum {
        return .adequate
    }
    if value <= cautionMaximum {
        return .caution
    }
    return .excess
}

func upperThresholdTone(_ value: Double, recommendedMaximum: Double, cautionMaximum: Double) -> StatusTone {
    if value <= recommendedMaximum {
        return .adequate
    }
    if value <= cautionMaximum {
        return .caution
    }
    return .excess
}

func moistureTone(_ moisturePct: Double, criteria: StageCriteria) -> StatusTone {
    thresholdTone(
        moisturePct,
        minimum: criteria.moistureMinimumPct,
        maximum: criteria.moistureMaximumPct,
        cautionMinimum: criteria.moistureCautionMinimumPct,
        cautionMaximum: criteria.moistureCautionMaximumPct
    )
}

func moistureMessage(_ moisturePct: Double, criteria: StageCriteria) -> String {
    let target = rangeString(criteria.moistureMinimumPct, criteria.moistureMaximumPct)
    let tone = moistureTone(moisturePct, criteria: criteria)
    switch tone {
    case .adequate:
        return "수분 수준이 적정합니다. (\(numberString(moisturePct))% vs 기준 \(target))"
    case .caution:
        if moisturePct < criteria.moistureMinimumPct {
            return "수분이 살짝 낮습니다. (\(numberString(moisturePct))% vs 기준 \(target)) 혼합 균일성과 기호성을 위해 수분 구성 조정을 고려해보세요."
        }
        return "수분이 살짝 높습니다. (\(numberString(moisturePct))% vs 기준 \(target)) 습식 원료 비중과 저장 안정성 점검을 권장합니다."
    case .deficient:
        return "수분이 부족합니다. (\(numberString(moisturePct))% vs 기준 \(target)) 혼합성과 섭취 균일성 점검이 필요합니다."
    case .excess:
        return "수분이 과잉입니다. (\(numberString(moisturePct))% vs 기준 \(target)) 변패와 저장 안정성 문제를 막기 위해 배합 수분 구성 점검이 필요합니다."
    }
}

// MARK: 회귀 검증용 원료 분류 집합

let proteinSourceIDs: Set<String> = [
    "CUSTOM_SOYBEAN_MEAL",
    "FEED_23",
    "FEED_24",
    "FEED_25",
    "FEED_31",
    "FEED_45",
    "FEED_201",
    "FEED_208",
    "FEED_209",
    "FEED_210",
    "FEED_217",
    "FEED_218",
    "FEED_219",
    "FEED_220",
    "FEED_222",
    "FEED_91"
]

let energySourceIDs: Set<String> = [
    "FEED_4",
    "FEED_7",
    "FEED_8",
    "FEED_33",
    "FEED_37",
    "FEED_211"
]

let fatHeavySourceIDs: Set<String> = [
    "FEED_200",
    "FEED_16",
    "FEED_29",
    "FEED_32",
    "FEED_48",
    "FEED_49",
    "FEED_207",
    "FEED_215",
    "FEED_216",
    "FEED_217",
    "FEED_218",
    "FEED_220"
]

// MARK: 대표 추천 선정

func defaultRecommendation(from recommendations: [Recommendation]) -> Recommendation? {
    recommendations.max { lhs, rhs in
        if lhs.isFullyResolved != rhs.isFullyResolved {
            return !lhs.isFullyResolved && rhs.isFullyResolved
        }

        if lhs.isReferenceOnly != rhs.isReferenceOnly {
            return lhs.isReferenceOnly && !rhs.isReferenceOnly
        }

        if abs(lhs.resolutionRate - rhs.resolutionRate) > 0.03 {
            return lhs.resolutionRate < rhs.resolutionRate
        }

        if lhs.correctionActions.count != rhs.correctionActions.count {
            return lhs.correctionActions.count > rhs.correctionActions.count
        }

        if abs(lhs.costDeltaKrw) != abs(rhs.costDeltaKrw) {
            return abs(lhs.costDeltaKrw) > abs(rhs.costDeltaKrw)
        }

        let preferredOrder: [RecommendationStrategy] = [.ownedFirst, .costEffective, .maintenance, .noSolution]
        let lhsIndex = preferredOrder.firstIndex(of: lhs.strategy) ?? preferredOrder.count
        let rhsIndex = preferredOrder.firstIndex(of: rhs.strategy) ?? preferredOrder.count
        return lhsIndex > rhsIndex
    }
}
