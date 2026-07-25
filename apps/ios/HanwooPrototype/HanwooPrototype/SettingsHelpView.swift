import SwiftUI

// MARK: - 설정·도움말
// 성장단계 변경, 용어 도움말, 데이터 관리, 앱 정보.

struct SettingsHelpView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var showClearHistoryConfirm = false

    var body: some View {
        List {
            Section("농장 설정") {
                Picker("성장단계", selection: stageBinding) {
                    ForEach(FarmStage.allCases) { stage in
                        Text(stage.title).tag(stage)
                    }
                }
                LabeledContent("농장 이름", value: store.farmName)
            }

            Section {
                ForEach(NutrientGlossary.entries) { entry in
                    DisclosureGroup {
                        Text(entry.explanation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(entry.term)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            } header: {
                Text("용어 도움말")
            } footer: {
                Text("영양소 값은 모두 건물(DM) 기준 %입니다. 성장단계별 기준 범위는 분석 화면의 판정 카드에서 확인할 수 있습니다.")
            }

            Section {
                LabeledContent("저장된 분석", value: "\(store.savedAnalyses.count)건")
                Button("분석 이력 전체 삭제", role: .destructive) {
                    showClearHistoryConfirm = true
                }
                .disabled(store.savedAnalyses.isEmpty)
            } header: {
                Text("데이터 관리")
            } footer: {
                Text("모든 데이터는 이 기기에만 저장되며 외부로 전송되지 않습니다.")
            }

            Section {
                LabeledContent("앱 버전", value: appVersion)
                LabeledContent("교정 엔진", value: "v\(CorrectionAlgorithm.version)")
            } header: {
                Text("정보")
            } footer: {
                Text("증감 시뮬레이션과 추천은 기기 안에서 동작하는 결정론적 최적화 엔진이 계산합니다. 같은 입력에는 항상 같은 결과가 나오며, 외부 AI 서비스를 사용하지 않습니다.\n\n추천은 의사결정 보조 정보입니다. 실제 급여 변경 전에 사양 전문가와 상의하세요.")
            }
        }
        .navigationTitle("설정·도움말")
        .confirmationDialog("분석 이력을 모두 삭제할까요?", isPresented: $showClearHistoryConfirm, titleVisibility: .visible) {
            Button("모두 삭제", role: .destructive) {
                store.savedAnalyses.removeAll()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("저장된 분석 \(store.savedAnalyses.count)건이 삭제됩니다. 되돌릴 수 없습니다.")
        }
    }

    private var stageBinding: Binding<FarmStage> {
        Binding(
            get: { store.selectedStage ?? .fatteningEarly },
            set: { store.completeOnboarding(stage: $0) }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// 용어 사전 (전문 용어 안내)
struct GlossaryEntry: Identifiable {
    let id = UUID()
    let term: String
    let explanation: String
}

enum NutrientGlossary {
    static let entries: [GlossaryEntry] = [
        GlossaryEntry(term: "CP (조단백질)", explanation: "성장과 근육 발달, 반추위 미생물 단백질 합성에 쓰이는 단백질 총량입니다."),
        GlossaryEntry(term: "TDN (가소화영양소총량)", explanation: "에너지 수준 지표입니다. 증체 속도와 비육 효율에 직접 영향을 줍니다."),
        GlossaryEntry(term: "EE (조지방)", explanation: "고밀도 에너지원입니다. 과잉이면 섭취량 저하와 반추위 불안정을 부를 수 있습니다."),
        GlossaryEntry(term: "NDF (중성세제불용섬유)", explanation: "되새김 시간·침 분비·반추위 pH 안정과 관련된 섬유 지표입니다."),
        GlossaryEntry(term: "ADF (산성세제불용섬유)", explanation: "소화가 어려운 섬유 지표입니다. 높을수록 전체 소화율과 에너지 이용률이 낮아집니다."),
        GlossaryEntry(term: "Ca (칼슘)", explanation: "골격 형성과 대사 건강, 광물질 균형에 필요합니다."),
        GlossaryEntry(term: "P (인)", explanation: "에너지 대사와 골격 발달에 쓰입니다."),
        GlossaryEntry(term: "Ca:P 비율", explanation: "칼슘과 인의 절대량만큼 두 값의 비율(1.5~2:1)이 중요합니다."),
        GlossaryEntry(term: "수분", explanation: "혼합 균일성, 저장성, 기호성에 영향을 줍니다. TMR 기준 40~45%가 적정입니다."),
        GlossaryEntry(term: "원물 / 건물(DM)", explanation: "원물은 물을 포함한 실제 무게, 건물은 수분을 뺀 무게입니다. 입력은 원물 kg, 영양소 계산은 건물 기준으로 합니다."),
    ]
}
