/**
 * Barre de longueur de coup — Peach/FM (brief-visuels-coaching-sources §1).
 *
 * Blanc début = catch mou · Gris = immersion effective · Blanc fin = washing out.
 */

export type StrokeBarMetrics = {
  length_norm: number;
  catch_white: number;
  immersed: number;
  finish_white: number;
  catch_angle_deg?: number;
  L_slide_m?: number;
  immersion_threshold?: number;
};

export type StrokeLengthBarProps = {
  bar: StrokeBarMetrics;
  seat?: number;
  label?: string;
  maxWidth?: number | string;
  compact?: boolean;
};

export function StrokeLengthBar({
  bar,
  seat,
  label,
  maxWidth = "100%",
  compact = false,
}: StrokeLengthBarProps) {
  const len = Math.max(0.08, Math.min(1.25, bar.length_norm || 0));
  const c = Math.max(0, bar.catch_white || 0);
  const m = Math.max(0, bar.immersed || 0);
  const f = Math.max(0, bar.finish_white || 0);
  const sum = c + m + f || 1;

  return (
    <div
      className={`stroke-bar${compact ? " compact" : ""}`}
      style={{ maxWidth }}
      title={
        `catch ${(100 * c).toFixed(0)}% · immergé ${(100 * m).toFixed(0)}% · ` +
        `sortie ${(100 * f).toFixed(0)}% · ×${len.toFixed(2)}`
      }
    >
      {(seat != null || label) && (
        <div className="stroke-bar-label">{label ?? `Poste ${seat}`}</div>
      )}
      <div className="stroke-bar-track-wrap">
        <div
          className="stroke-bar-track"
          style={{ width: `${Math.min(100, len * 100)}%` }}
        >
          <span className="stroke-bar-seg white" style={{ flex: c / sum }} />
          <span className="stroke-bar-seg immersed" style={{ flex: m / sum }} />
          <span className="stroke-bar-seg white" style={{ flex: f / sum }} />
        </div>
      </div>
    </div>
  );
}

export function StrokeLengthBarStack({
  bars,
}: {
  bars: Array<{ seat: number; bar: StrokeBarMetrics | null | undefined }>;
}) {
  return (
    <div className="stroke-bar-stack">
      <p className="muted stroke-bar-legend">
        Blanc début = catch mou · Gris = immersion effective · Blanc fin =
        washing out
      </p>
      {bars.map(({ seat, bar }) =>
        bar ? (
          <StrokeLengthBar key={seat} seat={seat} bar={bar} />
        ) : (
          <div key={seat} className="stroke-bar">
            <div className="stroke-bar-label">Poste {seat}</div>
            <p className="muted">barre indisponible</p>
          </div>
        ),
      )}
    </div>
  );
}
