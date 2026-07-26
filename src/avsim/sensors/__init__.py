"""Capteurs virtuels — vérité terrain → signaux bruités (brief §7)."""

from .angle_dame import AngleDameSensor
from .base import VirtualSensor
from .bus import BusModel, SyncConfig, bus_occupancy
from .coulisse import CoulisseSensor
from .force_dame import ForceDameSensor
from .force_pieds import ForcePiedsSensor
from .gnss import GnssRtkSensor, GnssStandardSensor
from .imu_coque import ImuCoqueSensor
from .impeller import ImpellerSensor
from .meteo import AnemoEmbarqueSensor, AnemoRiveSensor, TemperatureEauSensor
from .pod_dorsal import PodDorsalSensor

__all__ = [
    "VirtualSensor",
    "ForceDameSensor",
    "AngleDameSensor",
    "CoulisseSensor",
    "ForcePiedsSensor",
    "PodDorsalSensor",
    "ImuCoqueSensor",
    "GnssStandardSensor",
    "GnssRtkSensor",
    "ImpellerSensor",
    "AnemoRiveSensor",
    "AnemoEmbarqueSensor",
    "TemperatureEauSensor",
    "BusModel",
    "SyncConfig",
    "bus_occupancy",
]
