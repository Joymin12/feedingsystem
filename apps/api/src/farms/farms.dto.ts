import {
  ArrayUnique,
  IsArray,
  IsEmail,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
} from "class-validator";
import {
  STORAGE_LEVELS,
  USER_ROLES,
  WET_FEED_POLICIES,
} from "@feedingsystem/contracts";

export class UpdateFarmProfileDto {
  @IsOptional()
  @IsString()
  farm_name?: string;

  @IsEnum(STORAGE_LEVELS)
  storage_level!: (typeof STORAGE_LEVELS)[number];

  @IsEnum(WET_FEED_POLICIES)
  wet_feed_policy!: (typeof WET_FEED_POLICIES)[number];

  @IsInt()
  @Min(1)
  @Max(5)
  cost_priority!: number;

  @IsInt()
  @Min(1)
  @Max(5)
  stability_priority!: number;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsArray()
  @ArrayUnique()
  preferred_ingredient_ids?: string[];

  @IsOptional()
  @IsArray()
  @ArrayUnique()
  avoided_ingredient_ids?: string[];
}

export class InviteFarmMemberDto {
  @IsEmail()
  email!: string;

  @IsString()
  name!: string;

  @IsEnum(USER_ROLES)
  role!: (typeof USER_ROLES)[number];
}
