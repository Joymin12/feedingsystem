import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import { AppChrome, Topbar } from "@/components/chrome";

export const metadata: Metadata = {
  title: "한우 TMR Ops",
  description: "한우 TMR 운영용 모노레포 웹 대시보드"
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ko">
      <body>
        <AppChrome>
          <Topbar />
          {children}
        </AppChrome>
      </body>
    </html>
  );
}