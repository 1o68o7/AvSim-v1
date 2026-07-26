type Kind = "sim" | "measured" | "validated" | "beta";

const LABELS: Record<Kind, string> = {
  sim: "Simulé",
  measured: "Mesuré",
  validated: "Validée",
  beta: "Bêta — non calibrée",
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
