import type { Route } from "next";
import Link from "next/link";
import type { ReactNode } from "react";

export function AppChrome({ children }: { children: ReactNode }) {
  return <div className="app-shell">{children}</div>;
}

export function Topbar() {
  return (
    <header className="topbar">
      <Link className="brand-mark" href="/">
        한우 TMR Ops
      </Link>
      <nav className="topbar-nav" aria-label="Primary">
        <NavItem href="/">홈</NavItem>
        <NavItem href="/farm">농장 설정</NavItem>
        <NavItem href="/formulas">기본 TMR</NavItem>
      </nav>
    </header>
  );
}

export function NavItem({ href, children }: { href: string; children: ReactNode }) {
  return (
    <Link className="nav-link" href={href as Route} aria-current={undefined}>
      {children}
    </Link>
  );
}

export function HeroCard({
  eyebrow,
  title,
  description,
  actions,
  children
}: {
  eyebrow: string;
  title: string;
  description: string;
  actions?: ReactNode;
  children?: ReactNode;
}) {
  return (
    <section className="hero-panel fade-in">
      <span className="eyebrow">{eyebrow}</span>
      <h1 className="hero-title">{title}</h1>
      <p className="hero-copy">{description}</p>
      {actions ? <div className="hero-actions">{actions}</div> : null}
      {children}
    </section>
  );
}

export function MiniStat({ label, value, note }: { label: string; value: string; note?: string }) {
  return (
    <article className="mini-stat">
      <div className="label">{label}</div>
      <strong className="value">{value}</strong>
      {note ? <div className="row-meta">{note}</div> : null}
    </article>
  );
}

export function SectionCard({
  title,
  note,
  children,
  wide = false,
  action
}: {
  title: string;
  note?: string;
  children: ReactNode;
  wide?: boolean;
  action?: ReactNode;
}) {
  return (
    <section className={`section-card${wide ? " wide" : ""} fade-in`}>
      <div className="section-title">
        <div>
          <h2>{title}</h2>
          {note ? <p className="section-note">{note}</p> : null}
        </div>
        {action ? <div>{action}</div> : null}
      </div>
      {children}
    </section>
  );
}

export function StatusPill({ tone, children }: { tone: "good" | "warn" | "bad"; children: ReactNode }) {
  return <span className={`status-pill ${tone}`}>{children}</span>;
}

export function Pill({ children }: { children: ReactNode }) {
  return <span className="pill">{children}</span>;
}

export function ButtonLink({ href, children, primary = false }: { href: string; children: ReactNode; primary?: boolean }) {
  return (
    <Link className={`button${primary ? " primary" : ""}`} href={href as Route}>
      {children}
    </Link>
  );
}

export function AccentButton({ children, type = "button", onClick }: { children: ReactNode; type?: "button" | "submit"; onClick?: () => void }) {
  return (
    <button className="button primary" type={type} onClick={onClick}>
      {children}
    </button>
  );
}

export function NeutralButton({ children, type = "button", onClick }: { children: ReactNode; type?: "button" | "submit"; onClick?: () => void }) {
  return (
    <button className="button" type={type} onClick={onClick}>
      {children}
    </button>
  );
}