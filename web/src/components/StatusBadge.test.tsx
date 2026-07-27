/**
 * Régression §5 : le CSS TeamView ne doit pas supprimer .badge.indice (D3).
 */
import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { StatusBadge } from "./StatusBadge";

const here = dirname(fileURLToPath(import.meta.url));
const themeCss = readFileSync(resolve(here, "../theme.css"), "utf8");
const tokensCss = readFileSync(resolve(here, "../tokens.css"), "utf8");

describe("badge indice — RameurView / D3", () => {
  it("theme.css contient la règle .badge.indice (bordure pointillée)", () => {
    expect(themeCss).toMatch(/\.badge\.indice\s*\{[^}]*border-style:\s*dashed/s);
    expect(themeCss).toMatch(/\.badge\.indice\s*\{[^}]*color:\s*#e0c48a/s);
  });

  it("tokens.css définit les variables sémantiques Render-like", () => {
    expect(tokensCss).toMatch(/--color-background:/);
    expect(tokensCss).toMatch(/--color-accent:/);
    expect(tokensCss).toMatch(/--global-transition:/);
    expect(tokensCss).toMatch(/Inter/);
  });

  it("StatusBadge kind=indice rend le libellé visible dans le DOM", () => {
    const html = renderToStaticMarkup(<StatusBadge kind="indice" />);
    expect(html).toBe('<span class="badge indice">indice</span>');
  });
});
