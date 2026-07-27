/**
 * Régression : Badge shadcn + statut indice (bordure pointillée).
 */
import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { StatusBadge } from "./StatusBadge";

const here = dirname(fileURLToPath(import.meta.url));
const indexCss = readFileSync(resolve(here, "../index.css"), "utf8");
const badgeSrc = readFileSync(resolve(here, "./StatusBadge.tsx"), "utf8");

describe("shadcn foundation + badge indice", () => {
  it("index.css : primary AvSim + radius shadcn 0.625rem", () => {
    expect(indexCss).toMatch(/--radius:\s*0\.625rem/);
    expect(indexCss).toMatch(/--primary:\s*oklch\(0\.642 0\.094 214\.8\)/);
    expect(indexCss).toMatch(/\.dark\s*\{/);
  });

  it("StatusBadge s'appuie sur @/components/ui/badge (pas CSS maison .badge)", () => {
    expect(badgeSrc).toMatch(/from "@\/components\/ui\/badge"/);
    expect(badgeSrc).toMatch(/border-dashed/);
  });

  it("StatusBadge kind=indice rend le libellé et data-slot badge", () => {
    const html = renderToStaticMarkup(<StatusBadge kind="indice" />);
    expect(html).toContain("indice");
    expect(html).toContain('data-slot="badge"');
    expect(html).toContain("border-dashed");
  });
});
