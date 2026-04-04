package com.feedingsystem.tmr.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.feedingsystem.tmr.data.AnalysisWorkflowResponseDto
import com.feedingsystem.tmr.data.FarmProfileDto
import com.feedingsystem.tmr.data.FormulaDto
import com.feedingsystem.tmr.data.Stage
import com.feedingsystem.tmr.data.StageComparisonResponseDto

private val AppBackground = Color(0xFFF9F7F3)
private val HeaderTint = Color(0xFFF3E8D9)
private val SurfaceColor = Color(0xFFFFFDFC)
private val PrimaryGreen = Color(0xFF48714F)
private val SoftGreen = Color(0xFFE8F1E9)
private val SoftOrange = Color(0xFFF7E7D7)
private val SoftRed = Color(0xFFF8E2DE)
private val TextPrimary = Color(0xFF342B22)
private val TextSecondary = Color(0xFF8E7F6C)

private val storageLevelOptions = listOf("low" to "낮음", "medium" to "보통", "high" to "높음")
private val wetFeedPolicyOptions = listOf("limited" to "제한 허용", "balanced" to "균형 사용", "open" to "유연 사용")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HanwooTmrApp(viewModel: TmrViewModel = viewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { CenterAlignedTopAppBar(title = { Text("하누핏", color = TextPrimary, fontWeight = FontWeight.Bold) }) },
        bottomBar = {
            NavigationBar(containerColor = SurfaceColor) {
                TmrTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = state.currentTab == tab,
                        onClick = { viewModel.changeTab(tab) },
                        icon = { Text(tabIcon(tab)) },
                        label = { Text(tab.title) }
                    )
                }
            }
        },
        containerColor = AppBackground
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .background(AppBackground)
        ) {
            if (state.isLoading) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth(), color = PrimaryGreen, trackColor = HeaderTint)
            }

            state.errorMessage?.let { message ->
                BannerCard("오류", message, Modifier.padding(horizontal = 20.dp, vertical = 8.dp), SoftRed)
            }

            when (state.currentTab) {
                TmrTab.HOME -> HomeScreen(state.farmProfile, state.selectedFormula, state.stageComparison, state.workflow, viewModel::changeTab)
                TmrTab.FORMULA -> FormulaScreen(state.formulaDraft, viewModel::updateFormulaDraft, viewModel::updateFormulaItem, viewModel::addFormulaItem, viewModel::removeFormulaItem, viewModel::saveFormulaAndAnalyze)
                TmrTab.RECOMMEND -> RecommendScreen(state.workflow)
                TmrTab.COMMUNITY -> CommunityScreen(state.communityPosts)
                TmrTab.FARM -> FarmScreen(state.farmDraft, viewModel::updateFarmDraft, viewModel::saveFarmProfile)
            }
        }
    }
}

@Composable
private fun HomeScreen(
    farmProfile: FarmProfileDto?,
    selectedFormula: FormulaDto?,
    stageComparison: StageComparisonResponseDto?,
    workflow: AnalysisWorkflowResponseDto?,
    onChangeTab: (TmrTab) -> Unit
) {
    val animalCount = selectedFormula?.animalCount ?: 0
    val formulaName = selectedFormula?.formulaName ?: "기본 TMR 없음"
    val ownedCount = workflow?.recommendation?.ownedIngredientAdjustments?.size ?: 0
    val comparisonCount = stageComparison?.comparisons?.size ?: 0

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HeaderTint)
                    .padding(horizontal = 20.dp, vertical = 22.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("농장 운영 대시보드", color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                    Text(farmProfile?.farmName ?: "농장 정보를 불러오는 중", color = TextPrimary, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Text("대표 분석은 ${farmProfile?.preferredStage?.label ?: "비육 중기"} 기준으로 보여주고, 같은 배합을 다른 단계와 함께 비교합니다.", color = TextSecondary)
                }
            }
        }

        item {
            ElevatedCard(modifier = Modifier.padding(horizontal = 20.dp), shape = RoundedCornerShape(24.dp), colors = CardDefaults.elevatedCardColors(containerColor = SurfaceColor)) {
                Row(modifier = Modifier.fillMaxWidth().padding(20.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    HomeStat(animalCount.toString(), "사육 두수")
                    HomeStat(comparisonCount.toString(), "비교 단계")
                    HomeStat(ownedCount.toString(), "보유 원료 조정")
                }
            }
        }

        item { SectionLabel("빠른 시작", modifier = Modifier.padding(horizontal = 20.dp)) }
        item { QuickStartGrid(onChangeTab) }

        item {
            ElevatedCard(modifier = Modifier.padding(horizontal = 20.dp), shape = RoundedCornerShape(20.dp), colors = CardDefaults.elevatedCardColors(containerColor = SurfaceColor)) {
                Column(modifier = Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("대표 분석", color = TextPrimary, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                    Text(formulaName, color = TextSecondary)
                    workflow?.analysisRun?.nutrients?.take(4)?.forEach { nutrient ->
                        NutrientRow(
                            label = nutrient.label,
                            status = nutrient.status,
                            currentValue = nutrient.currentValue,
                            targetText = nutrient.minTargetValue?.let { min ->
                                val max = nutrient.maxTargetValue ?: nutrient.targetValue ?: min
                                "목표 ${formatDecimal(min)} - ${formatDecimal(max)}"
                            } ?: nutrient.targetValue?.let { "목표 ${formatDecimal(it)}" } ?: "목표값 없음"
                        )
                    } ?: Text("분석 결과가 아직 없습니다.", color = TextSecondary)
                }
            }
        }

        item {
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                SectionLabel("단계 비교")
                Text("${farmProfile?.preferredStage?.label ?: "대표 단계"} 기준", color = PrimaryGreen, style = MaterialTheme.typography.bodySmall)
            }
        }

        items(stageComparison?.comparisons ?: emptyList()) { row ->
            val tone = when {
                row.excessCount > 0 -> SoftOrange
                row.deficientCount > 0 -> SoftRed
                else -> SoftGreen
            }
            ElevatedCard(modifier = Modifier.padding(horizontal = 20.dp), shape = RoundedCornerShape(18.dp), colors = CardDefaults.elevatedCardColors(containerColor = SurfaceColor)) {
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 16.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(row.stage.label, fontWeight = FontWeight.Bold, color = TextPrimary)
                        Text("부족 ${row.deficientCount} / 적정 ${row.adequateCount} / 과잉 ${row.excessCount}", color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                    }
                    StatusBadge(if (row.stage == stageComparison?.preferredStage) "대표" else "비교", tone, badgeTextColor(tone))
                }
            }
        }
    }
}

@Composable
private fun QuickStartGrid(onChangeTab: (TmrTab) -> Unit) {
    Column(modifier = Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            QuickActionCard("배합 입력", "기본 TMR 수정", Modifier.weight(1f)) { onChangeTab(TmrTab.FORMULA) }
            QuickActionCard("농장 설정", "preferred_stage 관리", Modifier.weight(1f)) { onChangeTab(TmrTab.FARM) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            QuickActionCard("AI 추천", "보유/외부 추천 보기", Modifier.weight(1f)) { onChangeTab(TmrTab.RECOMMEND) }
            QuickActionCard("커뮤니티", "운영 노하우 보기", Modifier.weight(1f)) { onChangeTab(TmrTab.COMMUNITY) }
        }
    }
}

@Composable
private fun QuickActionCard(title: String, subtitle: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    ElevatedCard(modifier = modifier, shape = RoundedCornerShape(22.dp), colors = CardDefaults.elevatedCardColors(containerColor = SurfaceColor), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, fontWeight = FontWeight.Bold, color = TextPrimary)
            Text(subtitle, color = TextSecondary, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun HomeStat(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(value, color = TextPrimary, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleLarge)
        Text(label, color = TextSecondary, style = MaterialTheme.typography.bodySmall)
    }
}
@Composable
private fun RecommendScreen(workflow: AnalysisWorkflowResponseDto?) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 20.dp, top = 18.dp, end = 20.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item { SectionLabel("AI 추천") }
        item { SummaryCard(workflow) }

        if (workflow == null) {
            item { BannerCard("추천 결과 없음", "기본 TMR 저장 후 분석을 실행하면 추천 결과가 채워집니다.") }
        } else {
            item { SubsectionLabel("이슈 요약") }
            items(workflow.recommendation.issues) { issue ->
                BannerCard(
                    title = "${issue.nutrientKey.uppercase()} ${statusLabel(issue.status)}",
                    body = issue.explanation,
                    background = when (issue.status) {
                        "deficient" -> SoftOrange
                        "excess" -> SoftRed
                        else -> SoftGreen
                    }
                )
            }

            item { SubsectionLabel("보유 원료 조정안") }
            if (workflow.recommendation.ownedIngredientAdjustments.isEmpty()) {
                item { BannerCard("보유 원료 조정안 없음", "현재 보유 원료만으로는 우선 조정안을 만들지 못했습니다.") }
            } else {
                itemsIndexed(workflow.recommendation.ownedIngredientAdjustments) { index, item ->
                    RecommendCard(
                        rank = index + 1,
                        accent = if (item.action == "decrease") PrimaryGreen else Color(0xFFEC8735),
                        action = actionLabel(item.action),
                        title = item.ingredientName,
                        body = item.reason,
                        detail = item.deltaPercent?.let { "권장 변화 ${formatDecimal(it)}%p" }
                    )
                }
            }

            item { SubsectionLabel("추가 추천 원료") }
            if (workflow.recommendation.supplementalSuggestions.isEmpty()) {
                item { BannerCard("외부 추천 없음", "보유 원료 조정만으로 현재 이슈를 우선 대응할 수 있습니다.") }
            } else {
                itemsIndexed(workflow.recommendation.supplementalSuggestions) { index, item ->
                    RecommendCard(
                        rank = index + 1,
                        accent = Color(0xFF5E81D6),
                        action = "추가",
                        title = item.ingredientName,
                        body = item.reason,
                        detail = item.caution
                    )
                }
            }
        }
    }
}
@Composable
private fun SummaryCard(workflow: AnalysisWorkflowResponseDto?) {
    ElevatedCard(shape = RoundedCornerShape(18.dp), colors = CardDefaults.elevatedCardColors(containerColor = SurfaceColor)) {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("대표 단계 분석 요약", color = TextPrimary, fontWeight = FontWeight.Bold)
            Text(
                workflow?.analysisRun?.let { "${it.stage.label} 기준, 적정 ${it.adequateCount} / 부족 ${it.deficientCount} / 과잉 ${it.excessCount}" } ?: "대표 분석 결과가 없습니다.",
                color = TextSecondary
            )
            workflow?.analysisRun?.summary?.let { Text(it, color = TextPrimary) }
        }
    }
}

@Composable
private fun RecommendCard(rank: Int, accent: Color, action: String, title: String, body: String, detail: String?) {
    ElevatedCard(shape = RoundedCornerShape(16.dp), colors = CardDefaults.elevatedCardColors(containerColor = SurfaceColor)) {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(modifier = Modifier.background(accent.copy(alpha = 0.12f), CircleShape).padding(horizontal = 10.dp, vertical = 8.dp)) {
                    Text(rank.toString(), color = accent, fontWeight = FontWeight.Bold)
                }
                StatusBadge(action, accent.copy(alpha = 0.12f), accent)
                Text(title, color = TextPrimary, fontWeight = FontWeight.Bold)
            }
            Text(body, color = TextSecondary)
            detail?.takeIf { it.isNotBlank() }?.let { Text(it, color = TextPrimary, style = MaterialTheme.typography.bodySmall) }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FarmScreen(
    draft: FarmProfileDraft,
    onDraftChange: (FarmProfileDraft.() -> FarmProfileDraft) -> Unit,
    onSave: () -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 20.dp, top = 18.dp, end = 20.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item { SectionLabel("농장 설정") }
        item {
            OutlinedTextField(
                value = draft.farmName,
                onValueChange = { onDraftChange { copy(farmName = it) } },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("농장명") },
                singleLine = true
            )
        }
        item { SubsectionLabel("대표 분석 단계") }
        item {
            StageSelector(
                selected = draft.preferredStage,
                onSelect = { stage -> onDraftChange { copy(preferredStage = stage) } }
            )
        }
        item { SubsectionLabel("운영 정책") }
        item {
            ChoiceRow(storageLevelOptions, draft.storageLevel) { value -> onDraftChange { copy(storageLevel = value) } }
        }
        item {
            ChoiceRow(wetFeedPolicyOptions, draft.wetFeedPolicy) { value -> onDraftChange { copy(wetFeedPolicy = value) } }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                SmallField("비용 우선도", draft.costPriority, Modifier.weight(1f)) { onDraftChange { copy(costPriority = it) } }
                SmallField("안정성 우선도", draft.stabilityPriority, Modifier.weight(1f)) { onDraftChange { copy(stabilityPriority = it) } }
            }
        }
        item {
            OutlinedTextField(value = draft.preferredIngredientsText, onValueChange = { onDraftChange { copy(preferredIngredientsText = it) } }, modifier = Modifier.fillMaxWidth(), label = { Text("선호 원료") })
        }
        item {
            OutlinedTextField(value = draft.avoidedIngredientsText, onValueChange = { onDraftChange { copy(avoidedIngredientsText = it) } }, modifier = Modifier.fillMaxWidth(), label = { Text("회피 원료") })
        }
        item {
            OutlinedTextField(value = draft.notes, onValueChange = { onDraftChange { copy(notes = it) } }, modifier = Modifier.fillMaxWidth(), label = { Text("메모") }, minLines = 3)
        }
        item {
            Button(onClick = onSave, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = PrimaryGreen)) {
                Text("농장 설정 저장")
            }
        }
    }
}
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FormulaScreen(
    draft: FormulaDraft,
    onDraftChange: (FormulaDraft.() -> FormulaDraft) -> Unit,
    onItemChange: (Int, FormulaItemDraft.() -> FormulaItemDraft) -> Unit,
    onAddItem: () -> Unit,
    onRemoveItem: (Int) -> Unit,
    onSaveAndAnalyze: () -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Box(modifier = Modifier.fillMaxWidth().background(HeaderTint).padding(horizontal = 20.dp, vertical = 20.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("기본 TMR", color = TextSecondary)
                    Text("배합 입력", color = TextPrimary, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                }
            }
        }
        item {
            OutlinedTextField(value = draft.formulaName, onValueChange = { onDraftChange { copy(formulaName = it) } }, modifier = Modifier.padding(horizontal = 20.dp).fillMaxWidth(), label = { Text("배합명") }, singleLine = true)
        }
        item { SubsectionLabel("적용 단계", modifier = Modifier.padding(horizontal = 20.dp)) }
        item {
            StageSelector(selected = draft.stage, onSelect = { stage -> onDraftChange { copy(stage = stage) } }, modifier = Modifier.padding(horizontal = 20.dp))
        }
        item {
            Column(modifier = Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    SmallField("평균 체중(kg)", draft.averageWeightKg, Modifier.weight(1f)) { onDraftChange { copy(averageWeightKg = it) } }
                    SmallField("두수", draft.animalCount, Modifier.weight(1f)) { onDraftChange { copy(animalCount = it) } }
                }
                SmallField("목표 ADG", draft.targetAdg, Modifier.fillMaxWidth()) { onDraftChange { copy(targetAdg = it) } }
                OutlinedTextField(value = draft.notes, onValueChange = { onDraftChange { copy(notes = it) } }, modifier = Modifier.fillMaxWidth(), label = { Text("메모") }, minLines = 2)
            }
        }
        item {
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                SectionLabel("원료 구성")
                OutlinedButton(onClick = onAddItem) { Text("원료 추가") }
            }
        }
        itemsIndexed(draft.items) { index, item ->
            ElevatedCard(modifier = Modifier.padding(horizontal = 20.dp), shape = RoundedCornerShape(14.dp), colors = CardDefaults.elevatedCardColors(containerColor = SurfaceColor)) {
                Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        StatusBadge(categoryTone(index), SoftGreen, PrimaryGreen)
                        OutlinedButton(onClick = { onRemoveItem(index) }) { Text("삭제") }
                    }
                    OutlinedTextField(value = item.ingredientName, onValueChange = { onItemChange(index) { copy(ingredientName = it) } }, modifier = Modifier.fillMaxWidth(), label = { Text("원료명") })
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        SmallField("투입량", item.inclusionPercent, Modifier.width(110.dp)) { onItemChange(index) { copy(inclusionPercent = it) } }
                        SmallField("수분", item.moisturePercent, Modifier.width(110.dp)) { onItemChange(index) { copy(moisturePercent = it) } }
                        SmallField("CP", item.cpPercent, Modifier.width(110.dp)) { onItemChange(index) { copy(cpPercent = it) } }
                        SmallField("TDN", item.tdnPercent, Modifier.width(110.dp)) { onItemChange(index) { copy(tdnPercent = it) } }
                        SmallField("NDF", item.ndfPercent, Modifier.width(110.dp)) { onItemChange(index) { copy(ndfPercent = it) } }
                        SmallField("ADF", item.adfPercent, Modifier.width(110.dp)) { onItemChange(index) { copy(adfPercent = it) } }
                        SmallField("Ca", item.caPercent, Modifier.width(110.dp)) { onItemChange(index) { copy(caPercent = it) } }
                        SmallField("P", item.pPercent, Modifier.width(110.dp)) { onItemChange(index) { copy(pPercent = it) } }
                    }
                }
            }
        }
        item {
            ElevatedCard(modifier = Modifier.padding(horizontal = 20.dp), shape = RoundedCornerShape(14.dp), colors = CardDefaults.elevatedCardColors(containerColor = SoftGreen)) {
                Row(modifier = Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("총 투입량", color = PrimaryGreen, fontWeight = FontWeight.Bold)
                    Text("${formatDecimal(draft.items.sumOf { it.inclusionPercent.toDoubleOrNull() ?: 0.0 })} kg / 두", color = PrimaryGreen, fontWeight = FontWeight.Bold)
                }
            }
        }
        item {
            Button(onClick = onSaveAndAnalyze, modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp).fillMaxWidth().height(54.dp), colors = ButtonDefaults.buttonColors(containerColor = PrimaryGreen), shape = RoundedCornerShape(16.dp)) {
                Text("분석 실행하기")
            }
        }
    }
}

@Composable
private fun SmallField(label: String, value: String, modifier: Modifier = Modifier, onValueChange: (String) -> Unit) {
    OutlinedTextField(value = value, onValueChange = onValueChange, modifier = modifier, label = { Text(label) }, singleLine = true)
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun StageSelector(selected: Stage, onSelect: (Stage) -> Unit, modifier: Modifier = Modifier) {
    FlowRow(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Stage.entries.forEach { stage ->
            val active = stage == selected
            OutlinedButton(
                onClick = { onSelect(stage) },
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = if (active) PrimaryGreen else SurfaceColor,
                    contentColor = if (active) Color.White else TextSecondary
                )
            ) {
                Text(stage.label)
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChoiceRow(options: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { (value, label) ->
            val active = value == selected
            Button(
                onClick = { onSelect(value) },
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (active) PrimaryGreen else SurfaceColor,
                    contentColor = if (active) Color.White else TextSecondary
                )
            ) {
                Text(label)
            }
        }
    }
}
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CommunityScreen(posts: List<CommunityPost>) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Box(modifier = Modifier.fillMaxWidth().background(HeaderTint).padding(horizontal = 20.dp, vertical = 20.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("HanuFit Community", color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                    Text("커뮤니티", color = TextPrimary, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                }
            }
        }
        item {
            FlowRow(modifier = Modifier.padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("전체", "배합 노하우", "질병·건강", "시세·거래", "자유").forEachIndexed { index, label ->
                    StatusBadge(label, if (index == 0) PrimaryGreen else SurfaceColor, if (index == 0) Color.White else TextSecondary)
                }
            }
        }
        items(posts) { post ->
            ElevatedCard(modifier = Modifier.padding(horizontal = 20.dp), shape = RoundedCornerShape(16.dp), colors = CardDefaults.elevatedCardColors(containerColor = SurfaceColor)) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        StatusBadge(post.category, Color(post.accent).copy(alpha = 0.12f), Color(post.accent))
                        Text(post.timeLabel, color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                    }
                    Text(post.title, color = TextPrimary, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                    Text(post.body, color = TextSecondary)
                    Text(post.author, color = PrimaryGreen, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun BannerCard(title: String, body: String, modifier: Modifier = Modifier, background: Color = SurfaceColor) {
    ElevatedCard(modifier = modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp), colors = CardDefaults.elevatedCardColors(containerColor = background)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(title, color = TextPrimary, fontWeight = FontWeight.Bold)
            Text(body, color = TextSecondary)
        }
    }
}

@Composable
private fun SectionLabel(text: String, modifier: Modifier = Modifier) {
    Text(text, modifier = modifier, color = TextPrimary, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
}

@Composable
private fun SubsectionLabel(text: String, modifier: Modifier = Modifier) {
    Text(text, modifier = modifier, color = TextPrimary, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
}

@Composable
private fun StatusBadge(text: String, background: Color, color: Color) {
    Box(modifier = Modifier.background(background, RoundedCornerShape(8.dp)).padding(horizontal = 10.dp, vertical = 6.dp)) {
        Text(text, color = color, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun NutrientRow(label: String, status: String, currentValue: Double, targetText: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(label, color = TextPrimary, fontWeight = FontWeight.SemiBold)
            Text(targetText, color = TextSecondary, style = MaterialTheme.typography.bodySmall)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(formatDecimal(currentValue), color = TextPrimary, fontWeight = FontWeight.Bold)
            Text(statusLabel(status), color = statusColor(status), style = MaterialTheme.typography.bodySmall)
        }
    }
}

private fun statusLabel(status: String): String = when (status) {
    "deficient" -> "부족"
    "adequate" -> "적정"
    "excess" -> "과잉"
    else -> status
}

private fun statusColor(status: String): Color = when (status) {
    "deficient" -> Color(0xFFEC8735)
    "adequate" -> PrimaryGreen
    "excess" -> Color(0xFFDA7A4D)
    else -> TextSecondary
}

private fun badgeTextColor(background: Color): Color = when (background) {
    SoftGreen -> PrimaryGreen
    SoftOrange -> Color(0xFFB26A31)
    SoftRed -> Color(0xFFB75E46)
    else -> TextPrimary
}

private fun actionLabel(action: String): String = when (action) {
    "increase" -> "증량"
    "decrease" -> "감량"
    "maintain" -> "유지"
    "replace" -> "교체"
    else -> action
}

private fun formatDecimal(value: Double): String = String.format("%.1f", value)

private fun tabIcon(tab: TmrTab): String = when (tab) {
    TmrTab.HOME -> "홈"
    TmrTab.FORMULA -> "배합"
    TmrTab.RECOMMEND -> "추천"
    TmrTab.COMMUNITY -> "커뮤니티"
    TmrTab.FARM -> "농장"
}

private fun categoryTone(index: Int): String = when (index % 4) {
    0 -> "조사료"
    1 -> "에너지원"
    2 -> "단백질원"
    else -> "광물질"
}
