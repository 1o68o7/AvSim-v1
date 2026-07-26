/** Schéma de bateau adaptatif — 1..8 postes, couple / pointe (brief UI §4.1).
 *
 * Convention θ = `geometry.py` / `pose.py` :
 *   blade (x_along, y_lat) = (L·sin θ, L·cos θ)
 *   θ = 0 → palette perpendiculaire (portée latérale max)
 *   θ > 0 (attaque) → palette vers la proue ; θ < 0 (dégagé) → poupe
 *
 * SVG vue de dessus : +X vers la poupe (cox à droite), +Y vers le bas.
 * Donc tipX = pinX − L·sin(θ)  (signe SVG pour coller à +x physique = proue).
 */

export type BoatSchematicProps = {
  nRowers: number;
  sculling: boolean;
  coxed?: boolean;
  /** Angle aviron (deg), convention modèle : catch positif. */
  thetaDeg?: number;
  highlightSeat?: number | null;
  width?: number;
  height?: number;
};

/** Position palette relative au portant — même formule que `blade_position`. */
export function oarTipOffset(
  thetaDeg: number,
  side: 1 | -1,
  oarLen: number,
): { dx: number; dy: number } {
  const th = (thetaDeg * Math.PI) / 180;
  return {
    dx: -Math.sin(th) * oarLen,
    dy: side * Math.cos(th) * oarLen,
  };
}

export function BoatSchematic({
  nRowers,
  sculling,
  coxed = false,
  thetaDeg = 0,
  highlightSeat = null,
  width = 520,
  height = 160,
}: BoatSchematicProps) {
  const n = Math.max(0, Math.min(8, Math.floor(nRowers)));
  const margin = 36;
  const hullW = width - margin * 2;
  const hullH = 36;
  const cy = height * 0.55;
  const seats = Array.from({ length: n }, (_, i) => {
    const x =
      margin +
      (n === 1 ? hullW * 0.5 : (hullW * (i + 0.5)) / n);
    // pointe : côté alterné (bâbord / tribord) ; couple : deux avirons
    const side = i % 2 === 0 ? 1 : -1;
    return { i: i + 1, x, side: side as 1 | -1 };
  });

  const oarLen = sculling ? 52 : 70;

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      width="100%"
      role="img"
      aria-label={`Bateau ${n} postes ${sculling ? "couple" : "pointe"}`}
    >
      <defs>
        <linearGradient id="hullGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#3a9bb0" stopOpacity="0.55" />
          <stop offset="100%" stopColor="#0a3a4a" stopOpacity="0.9" />
        </linearGradient>
      </defs>
      {/* eau */}
      <rect x="0" y={cy + 8} width={width} height={height - cy} fill="rgba(18,96,122,0.25)" />
      {/* coque */}
      <path
        d={`M ${margin + 10} ${cy}
            Q ${margin} ${cy - hullH / 2} ${margin + 28} ${cy - hullH / 2}
            L ${width - margin - 28} ${cy - hullH / 2}
            Q ${width - margin} ${cy - hullH / 2} ${width - margin - 8} ${cy}
            Q ${width - margin} ${cy + hullH / 2} ${width - margin - 28} ${cy + hullH / 2}
            L ${margin + 28} ${cy + hullH / 2}
            Q ${margin} ${cy + hullH / 2} ${margin + 10} ${cy} Z`}
        fill="url(#hullGrad)"
        stroke="rgba(232,241,244,0.45)"
        strokeWidth="1.2"
      />
      {n === 0 && (
        <text x={width / 2} y={cy + 4} textAnchor="middle" fill="#b7c9d1" fontSize="14">
          Aucune classe choisie
        </text>
      )}
      {seats.map(({ i, x, side }) => {
        const hi = highlightSeat === i;
        const oars = sculling ? [1, -1] : [side];
        return (
          <g key={i}>
            <circle
              cx={x}
              cy={cy}
              r={hi ? 7 : 5.5}
              fill={hi ? "#d4c4a8" : "#e8f1f4"}
              opacity={0.9}
            />
            <text
              x={x}
              y={cy - 18}
              textAnchor="middle"
              fill="#b7c9d1"
              fontSize="11"
            >
              {i}
            </text>
            {oars.map((s) => {
              const { dx, dy } = oarTipOffset(thetaDeg ?? 0, s as 1 | -1, oarLen);
              const tipX = x + dx;
              const tipY = cy + dy;
              const bladeRot =
                (Math.atan2(dy, dx) * 180) / Math.PI;
              return (
                <g key={`${i}-${s}`}>
                  <line
                    x1={x}
                    y1={cy}
                    x2={tipX}
                    y2={tipY}
                    stroke="#d4c4a8"
                    strokeWidth="2"
                    strokeLinecap="round"
                  />
                  <ellipse
                    cx={tipX}
                    cy={tipY}
                    rx="7"
                    ry="3.5"
                    fill="#3a9bb0"
                    opacity="0.85"
                    transform={`rotate(${bladeRot} ${tipX} ${tipY})`}
                  />
                </g>
              );
            })}
          </g>
        );
      })}
      {coxed && n > 0 && (
        <g>
          <rect
            x={width - margin - 22}
            y={cy - 7}
            width="14"
            height="14"
            rx="2"
            fill="#9bd3df"
            opacity="0.7"
          />
          <text
            x={width - margin - 15}
            y={cy - 12}
            textAnchor="middle"
            fill="#b7c9d1"
            fontSize="9"
          >
            cox
          </text>
        </g>
      )}
    </svg>
  );
}
