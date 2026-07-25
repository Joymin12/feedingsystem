import SwiftUI

// MARK: - 계산 엔진
// 배합 영양소 계산 및 시뮬레이션 전용 순수 타입.
// 모든 계산은 결정론적 — 같은 입력 → 같은 결과.

@MainActor
protocol IngredientProviding {
    func ingredientDefinition(id: String) -> IngredientDefinition?
}

// MARK: - 계산 엔진 (순수 타입)
// IngredientProviding만 의존. SwiftUI/스토어/UserDefaults 비의존.
@MainActor
struct CalculationEngine {
    let provider: IngredientProviding

    func calculateMetrics(for formula: FeedFormula) -> (metrics: AnalysisSummaryMetrics, missingIngredients: [String]) {
        let totalAsFedKg = formula.items.reduce(0.0) { $0 + asFedKg(for: $1) }
        var totalDmKg = 0.0
        var totalCpKg = 0.0
        var totalTdnKg = 0.0
        var totalNdfKg = 0.0
        var totalAdfKg = 0.0
        var totalNfcKg = 0.0
        var totalEeKg = 0.0
        var totalCaKg = 0.0
        var totalPKg = 0.0
        var missingIngredients: [String] = []

        for item in formula.items {
            guard let defID = item.definitionID,
                  let definition = provider.ingredientDefinition(id: defID) else {
                missingIngredients.append(item.name)
                continue
            }

            let profile = definition.nutrition
            let asFed = asFedKg(for: item)
            let dmKg = asFed * (profile.dmPct / 100)
            totalDmKg += dmKg
            totalCpKg += nutrientKg(dmKg: dmKg, pctDm: profile.cpPctDm)
            totalTdnKg += nutrientKg(dmKg: dmKg, pctDm: profile.tdnPctDm)
            totalNdfKg += nutrientKg(dmKg: dmKg, pctDm: profile.ndfPctDm)
            totalAdfKg += nutrientKg(dmKg: dmKg, pctDm: profile.adfPctDm)
            totalNfcKg += nutrientKg(dmKg: dmKg, pctDm: profile.nfcPctDm)
            totalEeKg += nutrientKg(dmKg: dmKg, pctDm: profile.eePctDm)
            totalCaKg += nutrientKg(dmKg: dmKg, pctDm: profile.caPctDm)
            totalPKg += nutrientKg(dmKg: dmKg, pctDm: profile.pPctDm)
        }

        guard totalAsFedKg > 0, totalDmKg > 0 else {
            return (
                AnalysisSummaryMetrics(
                    totalAsFedKg: totalAsFedKg,
                    totalDmKg: 0,
                    moisturePct: 0,
                    cpPctDm: 0,
                    tdnPctDm: 0,
                    ndfPctDm: 0,
                    adfPctDm: 0,
                    nfcPctDm: 0,
                    eePctDm: 0,
                    caPctDm: 0,
                    pPctDm: 0,
                    caPRatio: 0
                ),
                missingIngredients
            )
        }

        let metrics = AnalysisSummaryMetrics(
            totalAsFedKg: totalAsFedKg,
            totalDmKg: totalDmKg,
            moisturePct: max(0, 100 - (totalDmKg / totalAsFedKg * 100)),
            cpPctDm: pctDm(totalCpKg, totalDmKg),
            tdnPctDm: pctDm(totalTdnKg, totalDmKg),
            ndfPctDm: pctDm(totalNdfKg, totalDmKg),
            adfPctDm: pctDm(totalAdfKg, totalDmKg),
            nfcPctDm: pctDm(totalNfcKg, totalDmKg),
            eePctDm: pctDm(totalEeKg, totalDmKg),
            caPctDm: pctDm(totalCaKg, totalDmKg),
            pPctDm: pctDm(totalPKg, totalDmKg),
            caPRatio: totalPKg > 0 ? totalCaKg / totalPKg : 0
        )
        return (metrics, missingIngredients)
    }

    func simulateApplying(
        actions: [CorrectionAction],
        to formula: FeedFormula
    ) -> (formula: FeedFormula, metrics: AnalysisSummaryMetrics)? {
        var simulated = formula

        for action in actions {
            switch action.type {
            case .decrease:
                guard let ingredientID = action.ingredientID,
                      let index = simulated.items.firstIndex(where: { $0.definitionID == ingredientID }) else {
                    return nil
                }
                let currentAmountKg = asFedKg(for: simulated.items[index])
                let nextAmountKg = max(0, currentAmountKg - action.amountKg)
                simulated.items[index].amount = nextAmountKg
                simulated.items[index].unit = .kg
            case .increase, .add:
                guard let ingredientID = action.ingredientID else { return nil }
                if let index = simulated.items.firstIndex(where: { $0.definitionID == ingredientID }) {
                    simulated.items[index].amount = asFedKg(for: simulated.items[index]) + action.amountKg
                    simulated.items[index].unit = .kg
                } else if let definition = provider.ingredientDefinition(id: ingredientID) {
                    simulated.items.append(
                        IngredientLine(
                            name: definition.name,
                            definitionID: definition.id,
                            amount: action.amountKg,
                            unit: .kg
                        )
                    )
                } else {
                    return nil
                }
            }
        }

        simulated.items.removeAll { asFedKg(for: $0) <= 0.0001 }
        let calculation = calculateMetrics(for: simulated)
        guard calculation.metrics.totalDmKg > 0 else { return nil }
        return (simulated, calculation.metrics)
    }

    func buildSummary(stage: FarmStage, metrics: AnalysisSummaryMetrics, missingIngredients: [String], totalIngredients: Int) -> String {
        guard metrics.totalDmKg > 0 else {
            if missingIngredients.count == totalIngredients, !missingIngredients.isEmpty {
                return "등록된 원료 성분이 없어 분석할 수 없습니다."
            }
            return "건물량이 0이라 분석할 수 없습니다."
        }

        let mainFocus: String
        switch stage {
        case .growing:
            mainFocus = thresholdTone(
                metrics.cpPctDm,
                minimum: stage.criteria.cpMinimumPctDm,
                maximum: stage.criteria.cpMaximumPctDm,
                cautionMinimum: stage.criteria.cpCautionMinimumPctDm,
                cautionMaximum: stage.criteria.cpCautionMaximumPctDm
            ) == .adequate ? "반추위 발달을 해치지 않는 균형 상태입니다." : "단백질 수준과 조사료 구조 점검이 필요합니다."
        case .fatteningEarly:
            mainFocus = thresholdTone(
                metrics.tdnPctDm,
                minimum: stage.criteria.tdnMinimumPctDm,
                maximum: stage.criteria.tdnMaximumPctDm,
                cautionMinimum: stage.criteria.tdnCautionMinimumPctDm,
                cautionMaximum: stage.criteria.tdnCautionMaximumPctDm
            ) == .adequate ? "증체에 맞는 에너지 구조가 유지되고 있습니다." : "에너지 수준과 조사료-농후사료 균형 점검이 필요합니다."
        case .fatteningLate:
            mainFocus = thresholdTone(
                metrics.caPRatio,
                minimum: stage.criteria.caPRatioMin,
                maximum: stage.criteria.caPRatioMax,
                cautionMinimum: stage.criteria.caPRatioCautionMin,
                cautionMaximum: stage.criteria.caPRatioCautionMax
            ) == .adequate ? "마무리 비육용 에너지와 광물질 균형이 유지되고 있습니다." : "광물질 균형 점검이 먼저 필요합니다."
        }

        guard !missingIngredients.isEmpty else { return mainFocus }
        return "\(mainFocus) 다만 \(missingIngredients.joined(separator: ", ")) 성분표가 없어 해당 원료는 계산에서 제외했습니다."
    }

    func buildStatuses(stage: FarmStage, criteria: StageCriteria, metrics: AnalysisSummaryMetrics) -> [NutrientStatus] {
        guard metrics.totalDmKg > 0 else {
            return [
                NutrientStatus(nutrient: "분석 상태", currentValue: "분석 불가", targetValue: "원료 성분 필요", tone: .caution, message: "등록된 원료 성분이 없거나 건물량이 0이라 계산할 수 없습니다.")
            ]
        }

        return [
            NutrientStatus(
                nutrient: "CP",
                currentValue: percentString(metrics.cpPctDm),
                targetValue: rangeString(criteria.cpMinimumPctDm, criteria.cpMaximumPctDm),
                tone: thresholdTone(metrics.cpPctDm, minimum: criteria.cpMinimumPctDm, maximum: criteria.cpMaximumPctDm, cautionMinimum: criteria.cpCautionMinimumPctDm, cautionMaximum: criteria.cpCautionMaximumPctDm),
                message: cpStatusMessage(stage: stage, value: metrics.cpPctDm, criteria: criteria)
            ),
            NutrientStatus(
                nutrient: "TDN",
                currentValue: percentString(metrics.tdnPctDm),
                targetValue: rangeString(criteria.tdnMinimumPctDm, criteria.tdnMaximumPctDm),
                tone: thresholdTone(metrics.tdnPctDm, minimum: criteria.tdnMinimumPctDm, maximum: criteria.tdnMaximumPctDm, cautionMinimum: criteria.tdnCautionMinimumPctDm, cautionMaximum: criteria.tdnCautionMaximumPctDm),
                message: tdnStatusMessage(stage: stage, value: metrics.tdnPctDm, criteria: criteria)
            ),
            NutrientStatus(
                nutrient: "EE",
                currentValue: percentString(metrics.eePctDm),
                targetValue: maximumString(criteria.eeMaxPctDm),
                tone: upperThresholdTone(metrics.eePctDm, recommendedMaximum: criteria.eeMaxPctDm, cautionMaximum: criteria.eeCautionMaxPctDm),
                message: eeStatusMessage(value: metrics.eePctDm, criteria: criteria)
            ),
            NutrientStatus(
                nutrient: "NDF",
                currentValue: percentString(metrics.ndfPctDm),
                targetValue: rangeString(criteria.ndfMinPctDm, criteria.ndfMaxPctDm),
                tone: thresholdTone(metrics.ndfPctDm, minimum: criteria.ndfMinPctDm, maximum: criteria.ndfMaxPctDm, cautionMinimum: criteria.ndfCautionMinPctDm, cautionMaximum: criteria.ndfCautionMaxPctDm),
                message: ndfStatusMessage(stage: stage, value: metrics.ndfPctDm, criteria: criteria)
            ),
            NutrientStatus(
                nutrient: "ADF",
                currentValue: percentString(metrics.adfPctDm),
                targetValue: rangeString(criteria.adfMinPctDm, criteria.adfMaxPctDm),
                tone: thresholdTone(metrics.adfPctDm, minimum: criteria.adfMinPctDm, maximum: criteria.adfMaxPctDm, cautionMinimum: criteria.adfCautionMinPctDm, cautionMaximum: criteria.adfCautionMaxPctDm),
                message: adfStatusMessage(stage: stage, value: metrics.adfPctDm, criteria: criteria)
            ),
            NutrientStatus(
                nutrient: "Ca",
                currentValue: percentString(metrics.caPctDm),
                targetValue: rangeString(criteria.caMinPctDm, criteria.caMaxPctDm),
                tone: thresholdTone(metrics.caPctDm, minimum: criteria.caMinPctDm, maximum: criteria.caMaxPctDm, cautionMinimum: criteria.caCautionMinPctDm, cautionMaximum: criteria.caCautionMaxPctDm),
                message: caStatusMessage(value: metrics.caPctDm, criteria: criteria)
            ),
            NutrientStatus(
                nutrient: "P",
                currentValue: percentString(metrics.pPctDm),
                targetValue: rangeString(criteria.pMinPctDm, criteria.pMaxPctDm),
                tone: thresholdTone(metrics.pPctDm, minimum: criteria.pMinPctDm, maximum: criteria.pMaxPctDm, cautionMinimum: criteria.pCautionMinPctDm, cautionMaximum: criteria.pCautionMaxPctDm),
                message: pStatusMessage(value: metrics.pPctDm, criteria: criteria)
            ),
            NutrientStatus(
                nutrient: "Ca:P",
                currentValue: ratioString(metrics.caPRatio),
                targetValue: ratioRangeString(criteria.caPRatioMin, criteria.caPRatioMax),
                tone: thresholdTone(metrics.caPRatio, minimum: criteria.caPRatioMin, maximum: criteria.caPRatioMax, cautionMinimum: criteria.caPRatioCautionMin, cautionMaximum: criteria.caPRatioCautionMax),
                message: caPRatioStatusMessage(value: metrics.caPRatio, criteria: criteria)
            ),
            NutrientStatus(
                nutrient: "수분",
                currentValue: percentString(metrics.moisturePct),
                targetValue: "\(numberString(criteria.moistureMinimumPct)) ~ \(numberString(criteria.moistureMaximumPct))%",
                tone: moistureTone(metrics.moisturePct, criteria: criteria),
                message: moistureMessage(metrics.moisturePct, criteria: criteria)
            )
        ]
    }
}

private func cpStatusMessage(stage: FarmStage, value: Double, criteria: StageCriteria) -> String {
    let target = rangeString(criteria.cpMinimumPctDm, criteria.cpMaximumPctDm)
    let stageLabel = stage.title
    let tone = thresholdTone(value, minimum: criteria.cpMinimumPctDm, maximum: criteria.cpMaximumPctDm, cautionMinimum: criteria.cpCautionMinimumPctDm, cautionMaximum: criteria.cpCautionMaximumPctDm)
    switch tone {
    case .adequate:
        return "단백질 수준이 적정합니다. (\(numberString(value))% vs 기준 \(target))"
    case .caution:
        if value < criteria.cpMinimumPctDm {
            return "단백질이 살짝 낮습니다. (\(numberString(value))% vs 기준 \(target)) \(stageLabel) 기준에 맞게 단백질 공급원 보강을 고려해보세요."
        }
        return "단백질이 살짝 높습니다. (\(numberString(value))% vs 기준 \(target)) 불필요한 단백질 원료 비중 조정 검토를 권장합니다."
    case .deficient:
        return "단백질이 부족합니다. (\(numberString(value))% vs 기준 \(target)) 대두박, 루핀 같은 단백질 공급원 점검이 필요합니다."
    case .excess:
        return "단백질이 과잉입니다. (\(numberString(value))% vs 기준 \(target)) \(stageLabel)에는 단백질 요구량이 더 낮을 수 있어 단백질 원료 비중 점검이 필요합니다."
    }
}

private func tdnStatusMessage(stage: FarmStage, value: Double, criteria: StageCriteria) -> String {
    let target = rangeString(criteria.tdnMinimumPctDm, criteria.tdnMaximumPctDm)
    let tone = thresholdTone(value, minimum: criteria.tdnMinimumPctDm, maximum: criteria.tdnMaximumPctDm, cautionMinimum: criteria.tdnCautionMinimumPctDm, cautionMaximum: criteria.tdnCautionMaximumPctDm)
    switch tone {
    case .adequate:
        return "에너지 수준이 적정합니다. (\(numberString(value))% vs 기준 \(target))"
    case .caution:
        if value < criteria.tdnMinimumPctDm {
            return "에너지가 살짝 낮습니다. (\(numberString(value))% vs 기준 \(target)) 옥수수나 곡류 비중 조정을 고려해보세요."
        }
        return "에너지가 살짝 높습니다. (\(numberString(value))% vs 기준 \(target)) 농후사료 비율 점검을 권장합니다."
    case .deficient:
        return "에너지가 부족합니다. (\(numberString(value))% vs 기준 \(target)) 옥수수나 고에너지 원료 비중 점검이 필요합니다."
    case .excess:
        return "에너지가 과잉입니다. (\(numberString(value))% vs 기준 \(target)) 농후사료 비중과 조사료 균형 점검이 필요합니다."
    }
}

private func ndfStatusMessage(stage: FarmStage, value: Double, criteria: StageCriteria) -> String {
    let target = rangeString(criteria.ndfMinPctDm, criteria.ndfMaxPctDm)
    let tone = thresholdTone(value, minimum: criteria.ndfMinPctDm, maximum: criteria.ndfMaxPctDm, cautionMinimum: criteria.ndfCautionMinPctDm, cautionMaximum: criteria.ndfCautionMaxPctDm)
    switch tone {
    case .adequate:
        return "NDF 수준이 적정합니다. (\(numberString(value))% vs 기준 \(target))"
    case .caution:
        if value < criteria.ndfMinPctDm {
            return "NDF가 살짝 낮습니다. (\(numberString(value))% vs 기준 \(target)) \(stage.title) 조사료 구조 점검을 권장합니다."
        }
        return "NDF가 살짝 높습니다. (\(numberString(value))% vs 기준 \(target)) 조사료 비중 조정 검토를 권장합니다."
    case .deficient:
        return "NDF가 부족합니다. (\(numberString(value))% vs 기준 \(target)) 반추위 안정성과 섭취 행동을 위해 조사료 구조 점검이 필요합니다."
    case .excess:
        return "NDF가 과잉입니다. (\(numberString(value))% vs 기준 \(target)) 조사료 비중이 높아 에너지 밀도가 떨어질 수 있어 조사료 구성 점검이 필요합니다."
    }
}

private func adfStatusMessage(stage: FarmStage, value: Double, criteria: StageCriteria) -> String {
    let target = rangeString(criteria.adfMinPctDm, criteria.adfMaxPctDm)
    let tone = thresholdTone(value, minimum: criteria.adfMinPctDm, maximum: criteria.adfMaxPctDm, cautionMinimum: criteria.adfCautionMinPctDm, cautionMaximum: criteria.adfCautionMaxPctDm)
    switch tone {
    case .adequate:
        return "ADF 수준이 적정합니다. (\(numberString(value))% vs 기준 \(target))"
    case .caution:
        if value < criteria.adfMinPctDm {
            return "ADF가 살짝 낮습니다. (\(numberString(value))% vs 기준 \(target)) 유효 섬유 수준 점검을 권장합니다."
        }
        return "ADF가 살짝 높습니다. (\(numberString(value))% vs 기준 \(target)) 거친 섬유 비중 조정 검토를 권장합니다."
    case .deficient:
        return "ADF가 부족합니다. (\(numberString(value))% vs 기준 \(target)) 유효 섬유 부족 가능성이 있어 조사료 구조 점검이 필요합니다."
    case .excess:
        return "ADF가 과잉입니다. (\(numberString(value))% vs 기준 \(target)) 섬유가 너무 거칠어 에너지 이용 효율이 떨어질 수 있어 섬유질 구성 점검이 필요합니다."
    }
}

private func caStatusMessage(value: Double, criteria: StageCriteria) -> String {
    let target = rangeString(criteria.caMinPctDm, criteria.caMaxPctDm)
    let tone = thresholdTone(value, minimum: criteria.caMinPctDm, maximum: criteria.caMaxPctDm, cautionMinimum: criteria.caCautionMinPctDm, cautionMaximum: criteria.caCautionMaxPctDm)
    switch tone {
    case .adequate:
        return "칼슘 수준이 적정합니다. (\(numberString(value))% vs 기준 \(target))"
    case .caution:
        if value < criteria.caMinPctDm {
            return "칼슘이 살짝 낮습니다. (\(numberString(value))% vs 기준 \(target)) 석회석이나 칼슘 공급원 점검을 권장합니다."
        }
        return "칼슘이 살짝 높습니다. (\(numberString(value))% vs 기준 \(target)) 석회석 비중 조정 검토를 권장합니다."
    case .deficient:
        return "칼슘이 부족합니다. (\(numberString(value))% vs 기준 \(target)) 칼슘 공급원 보강과 Ca:P 비율 점검이 필요합니다."
    case .excess:
        return "칼슘이 과잉입니다. (\(numberString(value))% vs 기준 \(target)) 과도한 칼슘은 인 이용을 방해할 수 있어 칼슘 공급원 점검이 필요합니다."
    }
}

private func pStatusMessage(value: Double, criteria: StageCriteria) -> String {
    let target = rangeString(criteria.pMinPctDm, criteria.pMaxPctDm)
    let tone = thresholdTone(value, minimum: criteria.pMinPctDm, maximum: criteria.pMaxPctDm, cautionMinimum: criteria.pCautionMinPctDm, cautionMaximum: criteria.pCautionMaxPctDm)
    switch tone {
    case .adequate:
        return "인 수준이 적정합니다. (\(numberString(value))% vs 기준 \(target))"
    case .caution:
        if value < criteria.pMinPctDm {
            return "인이 살짝 낮습니다. (\(numberString(value))% vs 기준 \(target)) 인 공급원과 Ca:P 비율 점검을 함께 권장합니다."
        }
        return "인이 살짝 높습니다. (\(numberString(value))% vs 기준 \(target)) 인 과잉 원료 비중 점검을 권장합니다."
    case .deficient:
        return "인이 부족합니다. (\(numberString(value))% vs 기준 \(target)) 인 절대량과 칼슘 비율 점검이 필요합니다."
    case .excess:
        return "인이 과잉입니다. (\(numberString(value))% vs 기준 \(target)) 인이 높으면 Ca:P 균형이 무너지기 쉬워 인 공급원 점검이 필요합니다."
    }
}

private func caPRatioStatusMessage(value: Double, criteria: StageCriteria) -> String {
    let target = ratioRangeString(criteria.caPRatioMin, criteria.caPRatioMax)
    let tone = thresholdTone(value, minimum: criteria.caPRatioMin, maximum: criteria.caPRatioMax, cautionMinimum: criteria.caPRatioCautionMin, cautionMaximum: criteria.caPRatioCautionMax)
    switch tone {
    case .adequate:
        return "Ca:P 비율이 적정합니다. (\(numberString(value)) vs 기준 \(target))"
    case .caution:
        if value < criteria.caPRatioMin {
            return "Ca:P 비율이 살짝 낮습니다. (\(numberString(value)) vs 기준 \(target)) 칼슘 공급원 보강 여부를 고려해보세요."
        }
        return "Ca:P 비율이 살짝 높습니다. (\(numberString(value)) vs 기준 \(target)) 칼슘 비중 조정 검토를 권장합니다."
    case .deficient:
        return "Ca:P 비율이 낮습니다. (\(numberString(value)) vs 기준 \(target)) 칼슘 부족 또는 인 과잉 상태일 수 있어 광물질 균형 점검이 필요합니다."
    case .excess:
        return "Ca:P 비율이 높습니다. (\(numberString(value)) vs 기준 \(target)) 칼슘 과잉으로 인 이용이 방해될 수 있어 광물질 균형 점검이 필요합니다."
    }
}

private func eeStatusMessage(value: Double, criteria: StageCriteria) -> String {
    let target = maximumString(criteria.eeMaxPctDm)
    let tone = upperThresholdTone(value, recommendedMaximum: criteria.eeMaxPctDm, cautionMaximum: criteria.eeCautionMaxPctDm)
    switch tone {
    case .adequate:
        return "조지방 수준이 적정합니다. (\(numberString(value))% vs 기준 \(target))"
    case .caution:
        return "조지방이 살짝 높습니다. (\(numberString(value))% vs 기준 \(target)) 미강·깻묵 같은 고지방 원료 비중 조정을 고려해보세요."
    case .excess:
        return "조지방이 과잉입니다. (\(numberString(value))% vs 기준 \(target)) 묽은 변이나 섭취량 저하 가능성이 있어 고지방 원료 구성 점검이 필요합니다."
    case .deficient:
        return "조지방 수준이 낮습니다. (\(numberString(value))% vs 기준 \(target))"
    }
}
