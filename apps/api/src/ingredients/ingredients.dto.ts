import {
  IsBoolean,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from "class-validator";
import { PRICE_SOURCES } from "@feedingsystem/contracts";

export class UpdateFarmIngredientSettingDto {
  @IsOptional()
  @IsBoolean()
  is_enabled?: boolean;

  @IsOptional()
  @IsBoolean()
  is_banned?: boolean;

  @IsOptional()
  @IsBoolean()
  preferred?: boolean;

  @IsOptional()
  @IsBoolean()
  avoided?: boolean;

  @IsOptional()
  @IsNumber()
  @Min(0)
  custom_price_krw_per_kg?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  inventory_kg?: number;

  @IsOptional()
  @IsEnum(PRICE_SOURCES)
  price_source?: (typeof PRICE_SOURCES)[number];

  @IsOptional()
  @IsString()
  note?: string;
}
