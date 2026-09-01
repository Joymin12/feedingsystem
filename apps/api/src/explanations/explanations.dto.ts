import { Type } from "class-transformer";
import {
  IsArray,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from "class-validator";

/** 엔진이 확정한 영양소 판정 한 건. */
export class NutrientJudgementDto {
  /** 영양소 키. 예: CP, TDN, EE, NDF, ADF, Ca, P, CaP, moisture */
  @IsString()
  @MinLength(1)
  @MaxLength(20)
  key!: string;

  /** 화면에 표시되는 이름. 예: 단백질(CP) */
  @IsString()
  @MaxLength(40)
  label!: string;

  @IsNumber()
  value!: number;

  @IsOptional()
  @IsNumber()
  bandMin?: number;

  @IsOptional()
  @IsNumber()
  bandMax?: number;

  @IsIn(["deficient", "caution", "adequate", "excess"])
  status!: "deficient" | "caution" | "adequate" | "excess";
}

/** 엔진이 산출한 원료별 증감. */
export class CorrectionActionDto {
  @IsString()
  @MaxLength(60)
  name!: string;

  @IsNumber()
  fromKg!: number;

  @IsNumber()
  toKg!: number;

  @IsNumber()
  deltaKg!: number;

  /**
   * 이 원료의 사양학적 참고사항. 농사로 사용수준 원문을 그대로 넘긴다.
   * AI가 "왜 이 원료를 늘렸는가"를 설명할 때 근거로 인용하게 하려는 것이지,
   * AI에게 한도를 판단시키려는 것이 아니다. 한도 준수는 엔진이 이미 끝냈다.
   */
  @IsOptional()
  @IsString()
  @MaxLength(400)
  note?: string;
}

export class CreateExplanationDto {
  /** 성장 단계 표시명. 예: 육성기 */
  @IsString()
  @MaxLength(20)
  stage!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  formulaName?: string;

  @IsNumber()
  totalAsFedKg!: number;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => NutrientJudgementDto)
  judgements!: NutrientJudgementDto[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CorrectionActionDto)
  actions!: CorrectionActionDto[];

  /**
   * 조정안을 적용했을 때의 판정. 교정안 설명에서만 온다.
   * 조정 결과 판정이 바뀌는 항목(예: 적정 → 과잉)을 AI가 정확히 말할 수 있게 하고,
   * 가드레일도 이 값을 알아야 결과 설명을 판정 번복으로 오판하지 않는다.
   */
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => NutrientJudgementDto)
  afterJudgements?: NutrientJudgementDto[];

  /** 완전 적정에 도달하지 못한 경우 엔진이 남긴 한계 설명. */
  @IsOptional()
  @IsString()
  @MaxLength(600)
  limitationNote?: string;

  /** 엔진이 만든 요약 문장. AI가 참고만 한다. */
  @IsOptional()
  @IsString()
  @MaxLength(400)
  engineSummary?: string;
}
