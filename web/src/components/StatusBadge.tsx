/**
 * Badge de statut DataR0w — fondation shadcn/ui (remplace l'ancien StatusBadge CSS).
 * Variantes métier via className sur Badge Radix, pas de styles maison.
 */
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

type Kind = "sim" | "measured" | "validated" | "beta" | "indice";

const LABELS: Record<Kind, string> = {
  sim: "Simulé",
  measured: "Mesuré",
  validated: "Validée",
  beta: "Bêta — non calibrée",
  // Distinct de Simulé/Mesuré : fiabilité de calibration (D3), pas la source.
  indice: "indice",
};

/** Couleurs sémantiques métier (pas chrome DA) — indice = bordure pointillée. */
const KIND_CLASS: Record<Kind, string> = {
  sim: "border-transparent bg-primary/25 text-primary",
  measured: "border-transparent bg-emerald-500/20 text-emerald-300",
  validated: "border-transparent bg-emerald-500/20 text-emerald-300",
  beta: "border-transparent bg-amber-500/20 text-amber-200",
  indice:
    "border-dashed border-amber-400/80 bg-amber-500/15 text-amber-200",
};

export function StatusBadge({
  kind,
  label,
}: {
  kind: Kind;
  label?: string;
}) {
  return (
    <Badge variant="outline" className={cn(KIND_CLASS[kind])}>
      {label ?? LABELS[kind]}
    </Badge>
  );
}

export function classBadgeKind(
  status: string,
): "validated" | "beta" {
  return status === "validated" ? "validated" : "beta";
}
