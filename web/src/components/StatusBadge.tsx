type Kind = "sim" | "measured" | "validated" | "beta" | "indice";

const LABELS: Record<Kind, string> = {
  sim: "Simulé",
  measured: "Mesuré",
  validated: "Validée",
  beta: "Bêta — non calibrée",
  // Distinct de Simulé/Mesuré : fiabilité de calibration (D3), pas la source.
  indice: "indice",
};

export function StatusBadge({
  kind,
  label,
}: {
  kind: Kind;
  label?: string;
}) {
  return <span className={`badge ${kind}`}>{label ?? LABELS[kind]}</span>;
}

export function classBadgeKind(
  status: string,
): "validated" | "beta" {
  return status === "validated" ? "validated" : "beta";
}
