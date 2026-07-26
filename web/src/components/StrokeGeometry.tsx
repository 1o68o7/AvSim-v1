/** Vue latérale animée — géométrie 100 % serveur (/api/pose), pas d'IK TS. */

import { StatusBadge } from "./StatusBadge";

export type PosePoint = { x: number; z: number };

export type PoseFrame = {
  u: number;
  theta_deg: number;
  joints: {
    ankle: PosePoint;
    knee: PosePoint;
    hip: PosePoint;
    shoulder: PosePoint;
    hand: PosePoint;
    head: PosePoint;
    seat: PosePoint;
  };
  oar: {
    pin: PosePoint;
    handle: PosePoint & { y?: number };
    blade: PosePoint & { y?: number };
  };
  hull: {
    bow_x: number;
    stern_x: number;
    deck_z: number;
    keel_z: number;
    loa_m: number;
  };
  flags?: {
    knee_behind_ankle?: boolean;
    show_catch_unvalidated_badge?: boolean;
  };
};

type Props = {
  frame: PoseFrame | null;
  width?: number;
  height?: number;
  loading?: boolean;
};

function project(
  x: number,
  z: number,
  bounds: { xMin: number; xMax: number; zMin: number; zMax: number },
  width: number,
  height: number,
  pad = 28,
) {
  const sx = (width - 2 * pad) / Math.max(bounds.xMax - bounds.xMin, 1e-6);
  const sz = (height - 2 * pad) / Math.max(bounds.zMax - bounds.zMin, 1e-6);
  const s = Math.min(sx, sz);
  // x proue → droite ; z haut → haut SVG (y diminue)
  const px = pad + (x - bounds.xMin) * s;
  const py = height - pad - (z - bounds.zMin) * s;
  return { px, py, s };
}

export function StrokeGeometry({
  frame,
  width = 520,
  height = 280,
  loading = false,
}: Props) {
  if (loading || !frame) {
    return (
      <div
        className="skeleton"
        style={{ width: "100%", height }}
        aria-label="Chargement pose"
      />
    );
  }

  const { joints: j, oar, hull } = frame;
  // Badge uniquement à l'attaque si genou géométriquement derrière la cheville
  // (point ouvert ROADMAP — pas une correction, juste de la transparence).
  const showCatchBadge =
    frame.flags?.show_catch_unvalidated_badge === true ||
    (frame.u <= 0.02 && j.knee.x < j.ankle.x);
  const catchBadgeTitle =
    "Position de catch non validée contre une mesure réelle " +
    "(x_knee < x_ankle — point ouvert géométrie, ROADMAP)";

  const xs = [
    hull.stern_x,
    hull.bow_x,
    j.ankle.x,
    j.hand.x,
    oar.blade.x,
    oar.handle.x,
  ];
  const zs = [
    hull.keel_z,
    hull.deck_z,
    j.head.z,
    j.ankle.z,
    oar.blade.z,
    oar.pin.z,
  ];
  const bounds = {
    xMin: Math.min(...xs) - 0.2,
    xMax: Math.max(...xs) + 0.2,
    zMin: Math.min(...zs) - 0.15,
    zMax: Math.max(...zs) + 0.25,
  };

  const pt = (p: PosePoint) => project(p.x, p.z, bounds, width, height);
  const ankle = pt(j.ankle);
  const knee = pt(j.knee);
  const hip = pt(j.hip);
  const shoulder = pt(j.shoulder);
  const hand = pt(j.hand);
  const head = pt(j.head);
  const pin = pt(oar.pin);
  const handle = pt(oar.handle);
  const blade = pt(oar.blade);
  const bow = project(hull.bow_x, hull.deck_z, bounds, width, height);
  const stern = project(hull.stern_x, hull.deck_z, bounds, width, height);
  const keelB = project(hull.bow_x * 0.85, hull.keel_z, bounds, width, height);
  const keelS = project(hull.stern_x * 0.85, hull.keel_z, bounds, width, height);
  const waterL = project(bounds.xMin, 0, bounds, width, height);
  const waterR = project(bounds.xMax, 0, bounds, width, height);

  const limb = (a: { px: number; py: number }, b: { px: number; py: number }) => (
    <line
      x1={a.px}
      y1={a.py}
      x2={b.px}
      y2={b.py}
      stroke="#e8f1f4"
      strokeWidth="3.2"
      strokeLinecap="round"
    />
  );
  const joint = (p: { px: number; py: number }, r = 4.5) => (
    <circle cx={p.px} cy={p.py} r={r} fill="#d4c4a8" />
  );

  return (
    <div style={{ position: "relative", width: "100%" }}>
      {showCatchBadge && (
        <div
          style={{ position: "absolute", top: 8, left: 8, zIndex: 2 }}
          title={catchBadgeTitle}
        >
          <StatusBadge
            kind="beta"
            label="Catch non validé (mesure)"
          />
        </div>
      )}
    <svg
      viewBox={`0 0 ${width} ${height}`}
      width="100%"
      role="img"
      aria-label={`Pose sagittale u=${frame.u.toFixed(2)} θ=${frame.theta_deg.toFixed(1)}°`}
    >
      {/* eau */}
      <rect
        x={0}
        y={waterL.py}
        width={width}
        height={Math.max(0, height - waterL.py)}
        fill="rgba(18,96,122,0.35)"
      />
      <line
        x1={waterL.px}
        y1={waterL.py}
        x2={waterR.px}
        y2={waterR.py}
        stroke="rgba(155,211,223,0.55)"
        strokeWidth="1"
      />
      {/* coque */}
      <path
        d={`M ${stern.px} ${stern.py}
            L ${bow.px} ${bow.py}
            L ${keelB.px} ${keelB.py}
            L ${keelS.px} ${keelS.py} Z`}
        fill="rgba(58,155,176,0.35)"
        stroke="rgba(232,241,244,0.5)"
        strokeWidth="1.2"
      />
      {/* aviron : pin → poignée → palette (x du noyau) */}
      <line
        x1={blade.px}
        y1={blade.py}
        x2={pin.px}
        y2={pin.py}
        stroke="#3a9bb0"
        strokeWidth="2.4"
        strokeLinecap="round"
      />
      <line
        x1={pin.px}
        y1={pin.py}
        x2={handle.px}
        y2={handle.py}
        stroke="#d4c4a8"
        strokeWidth="2.4"
        strokeLinecap="round"
      />
      <ellipse
        cx={blade.px}
        cy={blade.py}
        rx="10"
        ry="4"
        fill="#3a9bb0"
        opacity="0.9"
      />
      {joint(pin, 3.5)}
      {/* corps */}
      {limb(ankle, knee)}
      {limb(knee, hip)}
      {limb(hip, shoulder)}
      {limb(shoulder, hand)}
      {limb(shoulder, head)}
      {joint(ankle)}
      {joint(knee)}
      {joint(hip)}
      {joint(shoulder)}
      {joint(hand)}
      {joint(head, 6)}
      <text
        x={12}
        y={18}
        fill="#b7c9d1"
        fontSize="11"
        fontFamily="Source Sans 3, sans-serif"
      >
        u={frame.u.toFixed(2)} · θ={frame.theta_deg.toFixed(1)}° · Simulé
      </text>
      <text
        x={width - 12}
        y={18}
        textAnchor="end"
        fill="#b7c9d1"
        fontSize="11"
      >
        proue →
      </text>
    </svg>
    </div>
  );
}
