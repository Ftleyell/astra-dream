"""Shared paths, canvas metrics, bone topology, and coordinate helpers for Valentina v2."""

from __future__ import annotations

import sys
from pathlib import Path

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent.parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from process_masked_5parts import TEX_SCALE


def _canonical_rgba_path(work_dir: Path, view: str) -> Path:
    return work_dir / "02_poses_canonical_1560x1680" / f"{view}_rgba_1560x1680.png"


DEFAULT_SOURCE_DIR = Path("sandbox/pilot_rig_lab/source_refs/valentina_v2_8dir")
DEFAULT_OUT_DIR = Path("sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar")
DEFAULT_V1_DIR = Path("sandbox/pilot_rig_lab/combat_assets/valentina_planar")

CANONICAL_W = 520
CANONICAL_H = 560
PX_W = CANONICAL_W * TEX_SCALE
PX_H = CANONICAL_H * TEX_SCALE
HEAD_SCALE_FACTOR = 0.885
HEAD_TARGET_DENSITY_PX_H = 240.0
HEAD_SDF_MAX_DIST_PX = 32.0
HEAD_OUTLINE_DEFAULT_PX = 4.0
PART_PAD_PX = 4 * TEX_SCALE
REAR_DEPTH_DARKEN_FACTOR = 0.85
INK_BGR = np.array([20, 10, 10], dtype=np.uint8)

DIRECTIONS: tuple[str, ...] = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
PART_NAMES: tuple[str, ...] = ("body_core", "arm_r", "arm_l", "leg_r", "leg_l")
LIMB_PARTS: tuple[str, ...] = ("arm_r", "arm_l", "leg_r", "leg_l")

VIEW_TO_HEAD_KEY: dict[str, str] = {
    "s": "head_front",
    "se": "head_front_r",
    "sw": "head_front_l",
    "w": "head_side_l",
    "e": "head_side_r",
    "ne": "head_back_r",
    "nw": "head_back_l",
    "n": "head_back",
}

VIEW_Z_ORDERS: dict[str, dict[str, int]] = {
    "s": {"leg_l": 0, "leg_r": 1, "body_core": 2, "arm_l": 3, "arm_r": 4, "pauldron_l": 5, "pauldron_r": 5},
    "se": {"arm_l": 0, "leg_l": 1, "leg_r": 2, "body_core": 3, "arm_r": 4, "pauldron_l": 5, "pauldron_r": 5},
    "e": {"leg_l": 0, "arm_l": 1, "pauldron_l": 2, "leg_r": 3, "body_core": 4, "arm_r": 5, "pauldron_r": 6},
    "ne": {"arm_l": 0, "leg_l": 1, "leg_r": 2, "body_core": 3, "arm_r": 4, "pauldron_l": 5, "pauldron_r": 5},
    "n": {"arm_r": 0, "leg_r": 1, "leg_l": 2, "arm_l": 3, "body_core": 4, "pauldron_r": 5, "pauldron_l": 5},
    "nw": {"arm_r": 0, "leg_r": 1, "leg_l": 2, "body_core": 3, "arm_l": 4, "pauldron_r": 5, "pauldron_l": 5},
    "w": {"leg_r": 0, "arm_r": 1, "pauldron_r": 2, "leg_l": 3, "body_core": 4, "arm_l": 5, "pauldron_l": 6},
    "sw": {"arm_r": 0, "leg_r": 1, "leg_l": 2, "body_core": 3, "arm_l": 4, "pauldron_r": 5, "pauldron_l": 5},
}

BONE_PARENTS: tuple[tuple[str, str], ...] = (
    ("Pelvis", ""),
    ("Waist", "Pelvis"),
    ("Chest", "Waist"),
    ("Neck", "Chest"),
    ("Shoulder_R", "Chest"),
    ("Elbow_R", "Shoulder_R"),
    ("Wrist_R", "Elbow_R"),
    ("Shoulder_L", "Chest"),
    ("Elbow_L", "Shoulder_L"),
    ("Wrist_L", "Elbow_L"),
    ("Thigh_R", "Pelvis"),
    ("Knee_R", "Thigh_R"),
    ("Ankle_R", "Knee_R"),
    ("Thigh_L", "Pelvis"),
    ("Knee_L", "Thigh_L"),
    ("Ankle_L", "Knee_L"),
    ("Pauldron_R", "Chest"),
    ("Pauldron_L", "Chest"),
)

# Armhole-aligned offsets (in canonical display units) to seat arms into hd_torsos arm sockets
# and snugly seat pauldrons over shoulders to conceal joint rotation smoothly.
ARM_ARMHOLE_SHIFT_DU: dict[str, dict[str, tuple[float, float]]] = {
    "s": {"arm_r": (2.8, 2.5), "arm_l": (-2.8, 2.5)},
    "se": {"arm_r": (4.5, 3.0), "arm_l": (-3.0, 2.0)},
    "sw": {"arm_r": (3.0, 2.0), "arm_l": (-4.5, 3.0)},
    "e": {"arm_r": (-2.0, 6.5), "arm_l": (-2.5, 5.5)},
    "w": {"arm_r": (2.5, 5.5), "arm_l": (2.0, 6.5)},
    "ne": {"arm_r": (-3.0, 4.0), "arm_l": (3.0, 2.5)},
    "nw": {"arm_r": (-3.0, 2.5), "arm_l": (3.0, 4.0)},
    "n": {"arm_r": (-3.5, 2.5), "arm_l": (3.5, 2.5)},
}

PAULDRON_SOCKET_SHIFT_DU: dict[str, dict[str, tuple[float, float]]] = {
    "s": {"pauldron_r": (3.0, 2.0), "pauldron_l": (-3.0, 2.0)},
    "se": {"pauldron_r": (3.0, 2.0), "pauldron_l": (-5.5, 2.5)},
    "sw": {"pauldron_r": (5.5, 2.5), "pauldron_l": (-3.0, 2.0)},
    "e": {"pauldron_r": (0.0, 0.0)},
    "w": {"pauldron_l": (0.0, 0.0)},
    "ne": {"pauldron_r": (-3.5, 4.0), "pauldron_l": (3.7, 2.8)},
    "nw": {"pauldron_r": (-3.7, 2.8), "pauldron_l": (3.5, 4.0)},
    "n": {"pauldron_r": (-3.5, 2.0), "pauldron_l": (3.5, 2.0)},
}


def _warp_shift_px(arr: np.ndarray, dx_px: float, dy_px: float, nearest: bool = False) -> np.ndarray:
    if abs(dx_px) < 1e-4 and abs(dy_px) < 1e-4:
        return arr
    m = np.float32([[1.0, 0.0, float(dx_px)], [0.0, 1.0, float(dy_px)]])
    flags = cv2.INTER_NEAREST if nearest else cv2.INTER_LINEAR
    if arr.dtype == bool:
        out_u8 = cv2.warpAffine(arr.astype(np.uint8) * 255, m, (PX_W, PX_H), flags=cv2.INTER_NEAREST, borderValue=0)
        return out_u8 >= 128
    bval = 0 if arr.ndim == 2 else tuple([0] * arr.shape[2])
    return cv2.warpAffine(arr, m, (PX_W, PX_H), flags=flags, borderValue=bval)
