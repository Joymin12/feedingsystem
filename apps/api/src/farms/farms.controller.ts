import { Body, Controller, Get, Post, Put, UseGuards } from "@nestjs/common";
import type { CurrentUser as CurrentUserType } from "@feedingsystem/contracts";

import { CurrentUser } from "../common/decorators/current-user.decorator.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { FarmsService } from "./farms.service.js";
import { InviteFarmMemberDto, UpdateFarmProfileDto } from "./farms.dto.js";

@Controller("farm")
@UseGuards(SessionAuthGuard)
export class FarmsController {
  constructor(private readonly farmsService: FarmsService) {}

  @Get("profile")
  getProfile(@CurrentUser() user: CurrentUserType) {
    return this.farmsService.getFarmProfile(user);
  }

  @Put("profile")
  updateProfile(
    @CurrentUser() user: CurrentUserType,
    @Body() body: UpdateFarmProfileDto,
  ) {
    return this.farmsService.updateFarmProfile(user, body);
  }

  @Get("members")
  listMembers(@CurrentUser() user: CurrentUserType) {
    return this.farmsService.listMembers(user);
  }

  @Post("members/invite")
  inviteMember(
    @CurrentUser() user: CurrentUserType,
    @Body() body: InviteFarmMemberDto,
  ) {
    return this.farmsService.inviteMember(user, body);
  }
}
