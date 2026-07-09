import { Body, Controller, Get, HttpCode, Post, Req, Res, UseGuards } from "@nestjs/common";
import type { Response } from "express";

import { CurrentUser } from "../common/decorators/current-user.decorator.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import type { CurrentUser as CurrentUserType, LoginResponse } from "@feedingsystem/contracts";
import { LoginDto } from "./auth.dto.js";
import { AuthService } from "./auth.service.js";

@Controller()
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post("auth/login")
  @HttpCode(200)
  login(@Body() body: LoginDto, @Res({ passthrough: true }) response: Response): LoginResponse {
    const result = this.authService.login(body.email, body.password);
    response.cookie("session", result.sessionToken, {
      httpOnly: true,
      sameSite: "lax",
      secure: false,
      path: "/",
    });

    return {
      user: result.user,
      ...(process.env.NODE_ENV !== "production"
        ? { session_token: result.sessionToken }
        : {}),
    };
  }

  @Post("auth/logout")
  @HttpCode(204)
  logout(@Req() request: { cookies?: Record<string, string> }, @Res({ passthrough: true }) response: Response) {
    this.authService.logout(request.cookies?.session);
    response.clearCookie("session");
  }

  @Get("me")
  @UseGuards(SessionAuthGuard)
  me(@CurrentUser() user: CurrentUserType) {
    return user;
  }
}
