import SwiftUI
import UIKit
import OSLog

// MARK: - 내보내기 서비스
// 저장된 분석 스냅샷을 CSV/PDF 파일로 만들어 공유 시트로 전달한다.
// (공유 시트에는 저장·인쇄·메일 등 시스템 동작이 포함된다)

@MainActor
enum ExportService {

    private static let logger = Logger(subsystem: "com.jowm.HanwooPrototype", category: "Export")

    private static func exportDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func fileBaseName(for record: SavedAnalysis) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let safeName = record.formula.name.replacingOccurrences(of: "/", with: "-")
        return "\(safeName)-\(formatter.string(from: record.savedAt))"
    }

    // MARK: CSV

    static func csvURL(for record: SavedAnalysis) -> URL? {
        var lines: [String] = []
        lines.append("Hanufit 분석 내보내기")
        lines.append("배합,\(quoted(record.formula.name))")
        lines.append("성장단계,\(record.formula.stage.title)")
        lines.append("저장 시각,\(dateTimeString(record.savedAt))")
        lines.append("엔진 버전,\(record.algorithmVersion)")
        lines.append("")

        lines.append("원료,투입량(원물 kg)")
        for item in record.formula.items {
            lines.append("\(quoted(item.name)),\(numberString(asFedKg(for: item)))")
        }
        lines.append("합계,\(numberString(record.metrics.totalAsFedKg))")
        lines.append("")

        lines.append("항목,현재값,기준,판정")
        for status in record.statuses {
            lines.append("\(quoted(status.nutrient)),\(quoted(status.currentValue)),\(quoted(status.targetValue)),\(status.tone.title)")
        }
        lines.append("")

        if let primary = defaultRecommendation(from: record.recommendations) {
            lines.append("추천안,\(quoted(primary.title))")
            if primary.correctionActions.isEmpty {
                lines.append("내용,\(quoted(primary.reason))")
            } else {
                lines.append("원료,증감(원물 kg)")
                for action in primary.correctionActions {
                    let sign = action.type == .decrease ? "-" : "+"
                    lines.append("\(quoted(action.ingredientName)),\(sign)\(numberString(action.amountKg))")
                }
                lines.append("근거,\(quoted(primary.reason))")
            }
        }

        // 한글 Excel 호환을 위해 BOM을 붙인다.
        let content = "\u{FEFF}" + lines.joined(separator: "\n")
        let url = exportDirectory().appendingPathComponent("\(fileBaseName(for: record)).csv")
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            logger.error("CSV 내보내기 실패: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: PDF

    static func pdfURL(for record: SavedAnalysis) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 포인트
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = exportDirectory().appendingPathComponent("\(fileBaseName(for: record)).pdf")

        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let headingFont = UIFont.boldSystemFont(ofSize: 13)
        let bodyFont = UIFont.systemFont(ofSize: 11)

        var blocks: [(String, UIFont)] = []
        blocks.append((record.formula.name, titleFont))
        blocks.append(("\(record.formula.stage.title) · \(dateTimeString(record.savedAt)) 저장 · 엔진 v\(record.algorithmVersion)", bodyFont))
        blocks.append((record.summary, bodyFont))
        blocks.append(("배합 구성 (원물 기준)", headingFont))
        for item in record.formula.items {
            blocks.append(("  \(item.name)  —  \(numberString(asFedKg(for: item)))kg", bodyFont))
        }
        blocks.append(("  합계  —  \(numberString(record.metrics.totalAsFedKg))kg", bodyFont))
        blocks.append(("판정 결과", headingFont))
        for status in record.statuses {
            blocks.append(("  \(status.nutrient): \(status.currentValue) (기준 \(status.targetValue)) — \(status.tone.title)", bodyFont))
        }
        if let primary = defaultRecommendation(from: record.recommendations) {
            blocks.append(("추천안 — \(primary.title)", headingFont))
            if primary.correctionActions.isEmpty {
                blocks.append(("  \(primary.reason)", bodyFont))
            } else {
                for action in primary.correctionActions {
                    let sign = action.type == .decrease ? "−" : "+"
                    blocks.append(("  \(action.ingredientName): \(sign)\(numberString(action.amountKg))kg", bodyFont))
                }
                blocks.append(("  근거: \(primary.reason)", bodyFont))
            }
        }
        blocks.append(("이 문서는 의사결정 보조 정보입니다. 실제 급여 변경 전에 사양 전문가와 상의하세요.", bodyFont))

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y = margin
                let contentWidth = pageRect.width - margin * 2
                for (text, font) in blocks {
                    let attributes: [NSAttributedString.Key: Any] = [.font: font]
                    let bounding = (text as NSString).boundingRect(
                        with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attributes,
                        context: nil
                    )
                    if y + bounding.height > pageRect.height - margin {
                        context.beginPage()
                        y = margin
                    }
                    (text as NSString).draw(
                        with: CGRect(x: margin, y: y, width: contentWidth, height: bounding.height),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attributes,
                        context: nil
                    )
                    y += bounding.height + 6
                }
            }
            return url
        } catch {
            logger.error("PDF 내보내기 실패: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

// 공유 시트 (저장·인쇄·메일 포함)
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
