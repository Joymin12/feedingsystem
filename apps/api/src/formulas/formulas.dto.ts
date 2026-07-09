import { Type } from "class-transformer";
import {
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from "class-validator";
import {
  FORMULA_STATUSES,
  OBJECTIVES,
  PRICE_SOURCES,
  STAGES,
} from "@feedingsystem/contracts";

export class FormulaItemDto {
  @IsString()
  ingredient_id!: string;

  @IsNumber()
  @Min(0)
  as_fed_kg_per_head_day!: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  price_override_krw_per_kg?: number;

  @IsEnum(PRICE_SOURCES)
  price_source!: (typeof PRICE_SOURCES)[number];
}

export class CreateFormulaDto {
  @IsString()
  name!: string;

  @IsEnum(STAGES)
  stage!: (typeof STAGES)[number];

  @IsNumber()
  @Min(0)
  avg_weight_kg!: number;

  @IsNumber()
  @Min(1)
  head_count!: number;

  @IsEnum(OBJECTIVES)
  objective!: (typeof OBJECTIVES)[number];

  @IsOptional()
  @IsNumber()
  @Min(0)
  target_adg?: number;

  @IsOptional()
  @IsEnum(FORMULA_STATUSES)
  status?: (typeof FORMULA_STATUSES)[number];

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => FormulaItemDto)
  items!: FormulaItemDto[];
}

export class UpdateFormulaDto extends CreateFormulaDto {}
