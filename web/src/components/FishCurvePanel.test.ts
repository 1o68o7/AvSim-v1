import { describe, expect, it } from "vitest";
import { fishMarkerAtTheta } from "./fishMarker";

describe("fishMarkerAtTheta", () => {
  const fish = {
    theta_deg: [10, 20, 30, 40],
    theta_dot_deg_s: [5, 15, -10, -20],
  };

  it("repère le θ le plus proche sur la courbe poisson", () => {
    const m = fishMarkerAtTheta(fish, 29);
    expect(m).toEqual({ theta_deg: 30, theta_dot_deg_s: -10 });
  });

  it("ne lit pas series.theta_dot — source fish uniquement", () => {
    const m = fishMarkerAtTheta(fish, 10);
    expect(m?.theta_dot_deg_s).toBe(5);
  });
});
