import Foundation

// MARK: - 표시용 포맷 유틸리티
// 날짜/숫자/문자열 포맷 헬퍼. 순수 함수 — 상태 비의존.

func dateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter.string(from: date)
}

func dateTimeString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 HH:mm"
    return formatter.string(from: date)
}

func filteredDecimal(_ value: String) -> String {
    var result = ""
    var hasDecimalPoint = false

    for character in value {
        if character.isNumber {
            result.append(character)
        } else if character == ".", !hasDecimalPoint {
            hasDecimalPoint = true
            result.append(character)
        }
    }

    return result
}

func formattedAmount(_ item: IngredientLine) -> String {
    let amountText: String
    if item.amount.rounded() == item.amount {
        amountText = String(Int(item.amount))
    } else {
        amountText = String(format: "%.1f", item.amount)
    }
    return "\(amountText)\(item.unit.rawValue)"
}

func numberString(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }
    return String(format: "%.1f", value)
}

func percentString(_ value: Double) -> String {
    "\(numberString(value))%"
}

func ratioString(_ value: Double) -> String {
    "\(numberString(value)) : 1"
}

func maximumString(_ value: Double) -> String {
    "\(numberString(value))% 이하"
}

func rangeString(_ minimum: Double, _ maximum: Double) -> String {
    "\(numberString(minimum)) ~ \(numberString(maximum))%"
}

func ratioRangeString(_ minimum: Double, _ maximum: Double) -> String {
    "\(numberString(minimum)) ~ \(numberString(maximum)) : 1"
}

func krwString(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "ko_KR")
    return (formatter.string(from: NSNumber(value: value)) ?? "\(value)") + "원"
}

func correctionActionLabel(_ action: CorrectionAction) -> String {
    let prefix: String
    switch action.type {
    case .decrease:
        prefix = "-"
    case .increase, .add:
        prefix = "+"
    }
    return "\(action.ingredientName) \(prefix)\(action.displayAmount)"
}
