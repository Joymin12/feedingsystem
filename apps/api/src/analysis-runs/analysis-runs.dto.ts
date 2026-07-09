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
import { ANALYSIS_MODES, OBJECTIVES, PRICE_SOURCES, STAGES } from "@feedingsystem/contracts";

class AnalysisItemDto {
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

class InventoryItemDto {
  @IsString()
  ingredient_id!: string;

  @IsNumber()
  @Min(0)
  available_kg!: number;
}

export class CreateAnalysisRunDto {
  @IsEnum(ANALYSIS_MODES)
  mode!: (typeof ANALYSIS_MODES)[number];

  @IsOptional()
  @IsString()
  formula_id?: string;

  @IsOptional()
  @IsEnum(STAGES)
  stage?: (typeof STAGES)[number];

  @IsOptional()
  @IsNumber()
  @Min(0)
  avg_weight_kg?: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  head_count?: number;

  @IsOptional()
  @IsEnum(OBJECTIVES)
  objective?: (typeof OBJECTIVES)[number];

  @IsOptional()
  @IsNumber()
  @Min(0)
  target_adg?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  measured_moisture_pct?: number;

  @IsOptional()
  @IsArray()
  banned_ingredient_ids?: string[];

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => InventoryItemDto)
  inventory_items?: InventoryItemDto[];

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => AnalysisItemDto)
  items?: AnalysisItemDto[];
}
