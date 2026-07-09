import { IsBoolean, IsString, MaxLength, MinLength } from "class-validator";

export class CreateRecommendationMemoDto {
  @IsBoolean()
  applied!: boolean;

  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  memo!: string;
}
