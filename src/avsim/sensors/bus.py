"""Bus CAN / sync — gigue, charge, PPS, liaison pods (brief §7.1).

Expose les grandeurs nécessaires pour que la Phase 5 tranche :
« quelle précision de sync pour détecter 30 ms @ 95 % ? »
Sans trancher elle-même (pas de sélection Pareto ici).
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np


# CAN classique 500 kbit/s — trame data 8 octets ≈ 108–130 bits avec overhead
# (SOF…CRC…ACK). On retient 125 bits utiles/trame pour l'occupation.
BITS_PER_FRAME = 125
CAN_BITRATE = 500_000  # bit/s
FRAMES_PER_NODE_PER_HZ = 2  # 2 trames de 8 octets par période d'échantillon


def bus_occupancy(
    n_nodes: int,
    fe_hz: float = 200.0,
    *,
    bitrate: int = CAN_BITRATE,
    bits_per_frame: int = BITS_PER_FRAME,
    frames_per_sample: int = FRAMES_PER_NODE_PER_HZ,
) -> dict[str, float]:
    """Occupation bus : n_nodes × frames_per_sample × fe_hz.

    Pour 8 postes @ 200 Hz : 3200 trames/s ≈ 70 % à 500 kbit/s (brief §7.1).
    """
    frames_per_s = float(n_nodes) * frames_per_sample * float(fe_hz)
    bits_per_s = frames_per_s * bits_per_frame
    occupancy = bits_per_s / float(bitrate)
    return {
        "n_nodes": float(n_nodes),
        "frames_per_s": frames_per_s,
        "occupancy": occupancy,
        "bitrate": float(bitrate),
    }


def arbitration_latency_s(
    occupancy: float,
    rng: np.random.Generator,
    *,
    base_latency_s: float = 50e-6,
) -> float:
    """Latence d'arbitrage — **non linéaire** au-delà de 60 % d'occupation.

    Sous 60 % : latence ≈ base + petite gigue.
    Au-delà : croissance rapide (file / collisions d'arbitrage).
    """
    occ = float(occupancy)
    if occ <= 0.60:
        scale = 1.0 + 0.5 * (occ / 0.60)
    else:
        # dégradation erratique : exponentielle au-delà du seuil
        over = (occ - 0.60) / 0.40
        scale = 1.5 * (1.0 + 8.0 * over ** 2) * (1.0 + float(rng.uniform(0, over)))
    jitter = float(rng.normal(0.0, 10e-6 * scale))
    return max(0.0, base_latency_s * scale + jitter)


@dataclass
class SyncConfig:
    """Deux modes distincts : avec / sans discipline PPS GNSS."""

    pps_disciplined: bool = False
    clock_ppm: float = 20.0  # sans PPS
    clock_ppm_with_pps: float = 0.1


class BusModel:
    """Modélise gigue d'horodatage CAN, charge, PPS, liaison pods."""

    def __init__(
        self,
        n_nodes: int = 8,
        fe_hz: float = 200.0,
        rng_seed: int | None = None,
        sync: SyncConfig | None = None,
        *,
        pod_loss_rate: float = 0.01,  # 0,1–2 %
        pod_jitter_s: float = 2e-3,
    ):
        self.n_nodes = int(n_nodes)
        self.fe_hz = float(fe_hz)
        self.rng = np.random.default_rng(rng_seed)
        self.sync = sync or SyncConfig()
        self.pod_loss_rate = float(pod_loss_rate)
        self.pod_jitter_s = float(pod_jitter_s)
        # Dérive d'horloge **par nœud** (ppm) — sans PPS : ~20 ppm typique ;
        # avec PPS : résidu beaucoup plus faible. Différente pour chaque nœud
        # sinon l'erreur relative s'annule.
        ppm_scale = (
            self.sync.clock_ppm_with_pps
            if self.sync.pps_disciplined
            else self.sync.clock_ppm
        )
        self._node_ppm = self.rng.normal(0.0, ppm_scale, size=self.n_nodes)

    def occupancy(self) -> dict[str, float]:
        return bus_occupancy(self.n_nodes, self.fe_hz)

    def timestamp_jitter_s(self, t_true: np.ndarray, node_id: int = 0) -> np.ndarray:
        """Horodatage reçu = t_true + dérive d'horloge + latence d'arbitrage."""
        t = np.asarray(t_true, dtype=float)
        occ = self.occupancy()["occupancy"]
        ppm = float(self._node_ppm[int(node_id) % self.n_nodes])
        drift = (ppm * 1e-6) * (t - t[0]) if t.size else t
        lat = np.array([
            arbitration_latency_s(occ, self.rng) for _ in range(t.size)
        ])
        return t + drift + lat

    def sync_error_std_s(self, duration_s: float = 60.0, n_nodes: int | None = None) -> float:
        """Écart-type d'erreur d'horodatage relative entre nœuds — grandeur Phase 5.

        Permet de répondre (plus tard) : σ_sync << 30 ms pour détecter un
        décalage rameur à 95 %. N'effectue pas le test d'hypothèse ici.
        """
        n = self.n_nodes if n_nodes is None else int(n_nodes)
        fe = min(self.fe_hz, 50.0)  # grille légère pour la stats
        t = np.arange(0.0, duration_s, 1.0 / fe)
        stamps = [self.timestamp_jitter_s(t, node_id=i) for i in range(n)]
        # erreur relative nœud i vs nœud 0
        errs = np.concatenate([stamps[i] - stamps[0] for i in range(1, n)])
        return float(errs.std(ddof=1))

    def pod_radio_delivery(self, n_packets: int) -> dict[str, np.ndarray | float]:
        """Liaison sans fil pods : pertes 0,1–2 % + gigue."""
        delivered = self.rng.random(n_packets) >= self.pod_loss_rate
        jitter = self.rng.normal(0.0, self.pod_jitter_s, size=n_packets)
        jitter = np.where(delivered, jitter, np.nan)
        return {
            "delivered": delivered,
            "jitter_s": jitter,
            "loss_rate_empirical": float(1.0 - delivered.mean()),
        }
