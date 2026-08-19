import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  IsArray,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from "class-validator";

export class UsageIngredientDto {
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  id!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(60)
  name!: string;
}

export class RecordUsageDto {
  /**
   * 농가 식별 키. 계정 ID가 아니라 앱이 만든 익명 키를 받는다.
   * 누가 썼는지가 아니라 몇 농가가 쓰는지를 알면 되는 용도이기 때문이다.
   */
  @IsString()
  @MinLength(8)
  @MaxLength(64)
  farmKey!: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  stage?: string;

  /** 사용 중인 원료 목록. 투입량은 받지 않는다. */
  @IsArray()
  @ArrayMaxSize(60)
  @ValidateNested({ each: true })
  @Type(() => UsageIngredientDto)
  ingredients!: UsageIngredientDto[];
}
