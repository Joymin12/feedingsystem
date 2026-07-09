import { Injectable } from "@nestjs/common";
import type {
  CurrentUser,
  InviteFarmMemberRequest,
  UpdateFarmProfileRequest,
} from "@feedingsystem/contracts";

import { MockDatabaseService } from "../data/mock-database.service.js";

@Injectable()
export class FarmsService {
  constructor(private readonly db: MockDatabaseService) {}

  getFarmProfile(user: CurrentUser) {
    return this.db.getFarmProfile(user);
  }

  updateFarmProfile(user: CurrentUser, payload: UpdateFarmProfileRequest) {
    return this.db.updateFarmProfile(user, payload);
  }

  listMembers(user: CurrentUser) {
    return { items: this.db.listFarmMembers(user) };
  }

  inviteMember(user: CurrentUser, payload: InviteFarmMemberRequest) {
    return this.db.inviteFarmMember(user, payload);
  }
}
