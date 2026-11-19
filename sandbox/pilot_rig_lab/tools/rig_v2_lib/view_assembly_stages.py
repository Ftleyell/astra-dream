"""Re-export facade for modular per-view assembly stages."""

from .limb_cap_stages import apply_armhole_shifts, inject_capped_limbs, inject_hd_legs, inject_profile_rear_limbs
from .limb_seal_stages import prune_tiny_specks
from .torso_pauldron_stages import compute_and_write_body_metrics, inject_hd_torso_and_pauldrons

__all__ = [
    "apply_armhole_shifts",
    "compute_and_write_body_metrics",
    "inject_capped_limbs",
    "inject_hd_legs",
    "inject_hd_torso_and_pauldrons",
    "inject_profile_rear_limbs",
    "prune_tiny_specks",
]
