/**
 * Garde-fou convention θ — même formule que geometry.blade_position.
 * Un prochain refactor qui ré-inverse sin/cos doit casser ce fichier.
 */
import { describe, expect, it } from "vitest";
import { oarTipOffset } from "./BoatSchematic";

const L = 70;

describe("oarTipOffset — convention geometry.py", () => {
  it("θ=0 : perpendiculaire (dx=0, dy=side·L)", () => {
    const stbd = oarTipOffset(0, 1, L);
    const port = oarTipOffset(0, -1, L);
    expect(stbd.dx).toBeCloseTo(0, 10);
    expect(stbd.dy).toBeCloseTo(L, 10);
    expect(port.dx).toBeCloseTo(0, 10);
    expect(port.dy).toBeCloseTo(-L, 10);
  });

  it("θ=+58° (attaque sourcée) : dx vers la proue (SVG−), dy réduit non nul", () => {
    const { dx, dy } = oarTipOffset(58, 1, L);
    // SVG +X = poupe → proue = dx négatif ; |sin 58°|≈0.85
    expect(dx).toBeLessThan(-0.5 * L);
    expect(dx).toBeCloseTo(-Math.sin((58 * Math.PI) / 180) * L, 10);
    // cos 58°≈0.53 → latéral réduit mais non nul
    expect(dy).toBeGreaterThan(0.4 * L);
    expect(dy).toBeLessThan(L);
    expect(dy).toBeCloseTo(Math.cos((58 * Math.PI) / 180) * L, 10);
  });

  it("θ=−34° (dégagé) : dx vers la poupe (SVG+)", () => {
    const { dx, dy } = oarTipOffset(-34, 1, L);
    expect(dx).toBeGreaterThan(0.4 * L);
    expect(dx).toBeCloseTo(-Math.sin((-34 * Math.PI) / 180) * L, 10);
    expect(dy).toBeGreaterThan(0.7 * L); // cos 34°≈0.83
  });

  it("side=±1 : dy de signes opposés, dx identique (balayage longitudinal)", () => {
    for (const th of [0, 58, -34]) {
      const a = oarTipOffset(th, 1, L);
      const b = oarTipOffset(th, -1, L);
      expect(a.dx).toBeCloseTo(b.dx, 10);
      expect(a.dy).toBeCloseTo(-b.dy, 10);
      expect(Math.sign(a.dy)).not.toBe(Math.sign(b.dy) || 0);
    }
  });
});
