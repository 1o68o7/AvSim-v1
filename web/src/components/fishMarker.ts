import type { FishSeries } from "../api";

/** Point le plus proche sur ω(θ) pour le θ du curseur u. */
export function fishMarkerAtTheta(
  fish: FishSeries,
  thetaDeg: number,
): { theta_deg: number; theta_dot_deg_s: number } | null {
  const th = fish.theta_deg;
  const w = fish.theta_dot_deg_s;
  if (!th.length || !w.length) return null;
  let best = 0;
  let bestD = Math.abs(th[0] - thetaDeg);
  for (let i = 1; i < th.length; i++) {
    const d = Math.abs(th[i] - thetaDeg);
    if (d < bestD) {
      best = i;
      bestD = d;
    }
  }
  return { theta_deg: th[best], theta_dot_deg_s: w[best] };
}
