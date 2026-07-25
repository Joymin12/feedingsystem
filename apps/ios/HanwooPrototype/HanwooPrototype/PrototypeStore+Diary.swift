import SwiftUI

// MARK: - PrototypeStore 사육일지 책임
// 일지 저장/갱신.

extension PrototypeStore {
    func saveDiary(_ entry: DiaryEntry) {
        if let index = diaryEntries.firstIndex(where: { $0.id == entry.id }) {
            diaryEntries[index] = entry
        } else {
            diaryEntries.insert(entry, at: 0)
        }
        diaryEntries.sort(by: { $0.date > $1.date })
    }
}
