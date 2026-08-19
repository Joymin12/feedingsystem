import SwiftUI

// MARK: - 영양소 게이지
//
// 판정을 글자로만 적으면 "부족"이라는 사실은 알아도 얼마나 모자란지는 알 수 없다.
// 기준 구간을 막대로 그리고 현재 값을 그 위에 찍으면, 얼마나 벗어났는지가 한눈에 보인다.
//
// 막대는 다섯 구간이다. 부족 · 주의 · 적정 · 주의 · 과잉.
// 상한만 있는 항목(지방)은 앞쪽 두 구간 없이 적정에서 시작한다.

struct NutrientBand {
    /// 적정 하한, 적정 상한
    var minimum: Double?
    var maximum: Double?
    /// 주의 하한, 주의 상한
    var cautionMinimum: Double?
    var cautionMaximum: Double?

    init(_ range: RangeThreshold) {
        minimum = range.minimum
        maximum = range.maximum
        cautionMinimum = range.cautionMinimum
        cautionMaximum = range.cautionMaximum
    }

    /// 상한만 있는 항목(지방 등). 아래쪽으로는 제한이 없다.
    init(upper: UpperThreshold) {
        minimum = nil
        maximum = upper.recommendedMaximum
        cautionMinimum = nil
        cautionMaximum = upper.cautionMaximum
    }
}

struct NutrientGaugeRow: View {
    let name: String
    let value: Double
    let unit: String
    let band: NutrientBand
    let tone: StatusTone

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 46, alignment: .leading)

                // 값은 이 줄에서 가장 큰 글자로 둔다. 훑을 때 숫자가 먼저 들어와야 한다.
                Text(numberString(value) + unit)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tone == .adequate ? AppPalette.ink : tone.color)

                Spacer()

                Text(tone.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tone.color)
            }

            gauge

            Text(rangeLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) \(numberString(value))\(unit), \(tone.title), 기준 \(rangeLabel)")
    }

    // MARK: 막대

    /// 값을 막대 위 x 좌표로 옮긴다.
    private func offsetX(_ v: Double, width: CGFloat) -> CGFloat {
        let bounds = scaleBounds
        let span = max(bounds.upper - bounds.lower, 0.0001)
        return CGFloat((min(max(v, bounds.lower), bounds.upper) - bounds.lower) / span) * width
    }

    private var gauge: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let x: (Double) -> CGFloat = { offsetX($0, width: width) }

            ZStack(alignment: .leading) {
                // 바탕 = 벗어난 구간
                Capsule()
                    .fill(StatusTone.deficient.color.opacity(0.16))

                // 주의 구간
                if let cMin = band.cautionMinimum ?? band.minimum,
                   let cMax = band.cautionMaximum ?? band.maximum {
                    Capsule()
                        .fill(StatusTone.caution.color.opacity(0.28))
                        .frame(width: max(x(cMax) - x(cMin), 2))
                        .offset(x: x(cMin))
                }

                // 적정 구간 — 가장 진하게 칠해 목표 지점이 먼저 보이게 한다
                if let hi = band.maximum {
                    let lo = band.minimum ?? band.cautionMinimum ?? scaleBounds.lower
                    Capsule()
                        .fill(StatusTone.adequate.color.opacity(0.45))
                        .frame(width: max(x(hi) - x(lo), 2))
                        .offset(x: x(lo))
                }

                // 현재 값 표시
                Capsule()
                    .fill(tone.color)
                    .frame(width: 4, height: 22)
                    .overlay(
                        Circle()
                            .fill(tone.color)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(AppPalette.surface, lineWidth: 2))
                            .offset(y: -13)
                    )
                    .offset(x: x(value) - 2)
            }
        }
        .frame(height: 22)
    }

    // MARK: 눈금 범위
    //
    // 주의 구간 바깥으로 여유를 둬서, 값이 크게 벗어나도 막대 끝에 붙어 보이지 않게 한다.
    private var scaleBounds: (lower: Double, upper: Double) {
        let lows = [band.cautionMinimum, band.minimum].compactMap { $0 }
        let highs = [band.cautionMaximum, band.maximum].compactMap { $0 }
        let low = lows.min() ?? 0
        let high = highs.max() ?? max(value, 1)
        let pad = max((high - low) * 0.45, high * 0.12)

        let lower = min(low - pad, value - pad * 0.3)
        let upper = max(high + pad, value + pad * 0.3)
        return (max(0, lower), upper)
    }

    private var rangeLabel: String {
        if let lo = band.minimum, let hi = band.maximum {
            return "적정 \(numberString(lo)) ~ \(numberString(hi))\(unit)"
        }
        if let hi = band.maximum {
            return "적정 \(numberString(hi))\(unit) 이하"
        }
        return ""
    }
}

// MARK: - 배합의 영양소 게이지 목록

extension StageCriteria {
    /// 화면에 그릴 순서대로 (이름, 값, 단위, 구간)을 돌려준다.
    func gaugeItems(metrics: AnalysisSummaryMetrics) -> [(name: String, value: Double, unit: String, band: NutrientBand)] {
        [
            ("CP", metrics.cpPctDm, "%", NutrientBand(cpBand)),
            ("TDN", metrics.tdnPctDm, "%", NutrientBand(tdnBand)),
            ("EE", metrics.eePctDm, "%", NutrientBand(upper: eeBand)),
            ("NDF", metrics.ndfPctDm, "%", NutrientBand(ndfBand)),
            ("ADF", metrics.adfPctDm, "%", NutrientBand(adfBand)),
            ("Ca", metrics.caPctDm, "%", NutrientBand(caBand)),
            ("P", metrics.pPctDm, "%", NutrientBand(pBand)),
            ("Ca:P", metrics.caPRatio, "", NutrientBand(caPRatioBand)),
            ("수분", metrics.moisturePct, "%", NutrientBand(moistureBand)),
        ]
    }
}
