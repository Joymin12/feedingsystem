"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import {
  stageLabelMap,
  stageValues,
  type CreateFormulaRequest,
  type Formula,
  type FormulaItem
} from "@hanwoo-tmr/contracts";
import { AccentButton, NeutralButton } from "@/components/chrome";
import { api } from "@/lib/api-client";

type EditableItem = FormulaItem & { id: string };

function makeId(prefix: string) {
  return `${prefix}_${Math.random().toString(36).slice(2, 8)}`;
}

function toEditableFormula(formula: Formula): CreateFormulaRequest {
  return {
    farm_id: formula.farm_id,
    formula_name: formula.formula_name,
    stage: formula.stage,
    average_weight_kg: formula.average_weight_kg,
    animal_count: formula.animal_count,
    target_adg: formula.target_adg,
    items: formula.items,
    notes: formula.notes
  };
}

function toEditableItems(items: FormulaItem[]): EditableItem[] {
  return items.map((item) => ({ ...item, id: makeId(item.ingredient_id) }));
}

function createEmptyItem(): EditableItem {
  return {
    id: makeId("item"),
    ingredient_id: "new_ingredient",
    ingredient_name: "신규 원료",
    inclusion_percent: 0,
    moisture_percent: 12,
    cp_percent: 0,
    tdn_percent: 0,
    ndf_percent: 0,
    adf_percent: 0,
    ca_percent: 0,
    p_percent: 0
  };
}

/**
 * formula 편집 화면은 내부 모델 이름을 그대로 사용한다.
 * 사용자는 기본 TMR을 수정한다고 느끼지만,
 * 실제 저장은 기존 formula/formula.items 계약에 맞춰 보낸다.
 * 보유 원료 여부와 재고량은 별도 farm_ingredient_settings / inventory 레이어에서 다룬다.
 */
export function FormulaForm({ initialValue }: { initialValue: Formula }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [form, setForm] = useState<CreateFormulaRequest>(() => toEditableFormula(initialValue));
  const [items, setItems] = useState<EditableItem[]>(() => toEditableItems(initialValue.items));
  const itemTotal = items.reduce((sum, item) => sum + (Number(item.inclusion_percent) || 0), 0);

  function updateField<K extends keyof CreateFormulaRequest>(
    key: K,
    value: CreateFormulaRequest[K]
  ) {
    setForm((current) => ({ ...current, [key]: value }));
  }

  function updateItem(id: string, patch: Partial<EditableItem>) {
    setItems((current) => current.map((item) => (item.id === id ? { ...item, ...patch } : item)));
  }

  function addItem() {
    setItems((current) => [...current, createEmptyItem()]);
  }

  function removeItem(id: string) {
    setItems((current) => current.filter((item) => item.id !== id));
  }

  function persist(nextAction: "save" | "analyze") {
    startTransition(async () => {
      const payload: CreateFormulaRequest = {
        ...form,
        items: items.map(({ id: _id, ...item }) => item)
      };
      const saved = await api.saveFormula(initialValue.formula_id === "new" ? undefined : initialValue.formula_id, payload);

      if (nextAction === "analyze") {
        const workflow = await api.createAnalysisRun(saved.formula_id);
        router.push(`/results/${workflow.analysis_run.run_id}`);
        router.refresh();
        return;
      }

      router.replace(`/formulas/${saved.formula_id}`);
      router.refresh();
    });
  }

  return (
    <div className="editor-shell">
      <div className="form-grid">
        <label className="field full">
          <span>배합명</span>
          <input value={form.formula_name} onChange={(event) => updateField("formula_name", event.target.value)} />
        </label>
        <label className="field">
          <span>단계</span>
          <select value={form.stage} onChange={(event) => updateField("stage", event.target.value as CreateFormulaRequest["stage"])}>
            {stageValues.map((stage) => (
              <option key={stage} value={stage}>
                {stageLabelMap[stage]}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span>평균 체중(kg)</span>
          <input type="number" value={form.average_weight_kg} onChange={(event) => updateField("average_weight_kg", Number(event.target.value))} />
        </label>
        <label className="field">
          <span>두수</span>
          <input type="number" value={form.animal_count} onChange={(event) => updateField("animal_count", Number(event.target.value))} />
        </label>
        <label className="field">
          <span>목표 ADG(kg)</span>
          <input type="number" step="0.01" value={form.target_adg} onChange={(event) => updateField("target_adg", Number(event.target.value))} />
        </label>
        <label className="field full">
          <span>메모</span>
          <textarea value={form.notes ?? ""} onChange={(event) => updateField("notes", event.target.value)} />
        </label>
      </div>

      <div className="table-shell" style={{ marginTop: 16 }}>
        <table>
          <thead>
            <tr>
              <th>원료 ID</th>
              <th>원료명</th>
              <th>배합 %</th>
              <th>수분</th>
              <th>CP</th>
              <th>TDN</th>
              <th>NDF</th>
              <th>ADF</th>
              <th>Ca</th>
              <th>P</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr key={item.id}>
                <td><input value={item.ingredient_id} onChange={(event) => updateItem(item.id, { ingredient_id: event.target.value })} /></td>
                <td><input value={item.ingredient_name} onChange={(event) => updateItem(item.id, { ingredient_name: event.target.value })} /></td>
                <td><input type="number" step="0.1" value={item.inclusion_percent} onChange={(event) => updateItem(item.id, { inclusion_percent: Number(event.target.value) })} /></td>
                <td><input type="number" step="0.1" value={item.moisture_percent} onChange={(event) => updateItem(item.id, { moisture_percent: Number(event.target.value) })} /></td>
                <td><input type="number" step="0.1" value={item.cp_percent} onChange={(event) => updateItem(item.id, { cp_percent: Number(event.target.value) })} /></td>
                <td><input type="number" step="0.1" value={item.tdn_percent} onChange={(event) => updateItem(item.id, { tdn_percent: Number(event.target.value) })} /></td>
                <td><input type="number" step="0.1" value={item.ndf_percent} onChange={(event) => updateItem(item.id, { ndf_percent: Number(event.target.value) })} /></td>
                <td><input type="number" step="0.1" value={item.adf_percent} onChange={(event) => updateItem(item.id, { adf_percent: Number(event.target.value) })} /></td>
                <td><input type="number" step="0.01" value={item.ca_percent} onChange={(event) => updateItem(item.id, { ca_percent: Number(event.target.value) })} /></td>
                <td><input type="number" step="0.01" value={item.p_percent} onChange={(event) => updateItem(item.id, { p_percent: Number(event.target.value) })} /></td>
                <td>
                  <button className="button" type="button" onClick={() => removeItem(item.id)}>삭제</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="helper" style={{ marginTop: 10 }}>
        현재 합계 비율은 {itemTotal.toFixed(1)}%입니다. 저장 시 `formula.items`를 그대로 API에 전달하고, 보유 원료 판단은 서버의 farm_ingredient_settings / inventory 레이어가 담당합니다.
      </div>

      <div className="form-actions">
        <AccentButton type="button" onClick={() => persist("save")}>{isPending ? "저장 중..." : "기본 TMR 저장"}</AccentButton>
        <NeutralButton type="button" onClick={() => persist("analyze")}>저장 후 분석</NeutralButton>
        <NeutralButton type="button" onClick={addItem}>원료 추가</NeutralButton>
      </div>
    </div>
  );
}