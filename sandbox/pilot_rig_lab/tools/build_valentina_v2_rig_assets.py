#!/usr/bin/env python3
"""Assemble complete 8-directional Valentina v2 planar rig asset pack.

Thin CLI orchestrator delegating implementation to `rig_v2_lib/` submodules:
- `rig_v2_lib/constants.py`: paths, canvas metrics, bone topology, socket offsets
- `rig_v2_lib/mask_and_matting.py`: depth darken and secondary bust mask helpers
- `rig_v2_lib/skeleton_and_normals.py`: bones, 3D relief normals, geodesic weights
- `rig_v2_lib/heads_builder.py`: decoupled 8-dir head carving & SDF outlines
- `rig_v2_lib/part_exporter.py`: border-preserving per-part texture/mask/meta export
- `rig_v2_lib/view_assembly_stages.py`: per-view canonical assembly stages
- `rig_v2_lib/audit_renderer.py`: final verification sheets
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from process_masked_5parts import TEX_SCALE  # noqa: E402
from rig_v2_lib.audit_renderer import render_final_audits  # noqa: E402
from rig_v2_lib.constants import (  # noqa: E402
    DEFAULT_OUT_DIR,
    DEFAULT_SOURCE_DIR,
    DEFAULT_V1_DIR,
    DIRECTIONS,
    HEAD_OUTLINE_DEFAULT_PX,
    LIMB_PARTS,
    PART_NAMES,
    PX_H,
    PX_W,
    REAR_DEPTH_DARKEN_FACTOR,
    VIEW_Z_ORDERS,
    _canonical_rgba_path,
)
from rig_v2_lib.heads_builder import _compute_body_neck_cut, build_heads_pack  # noqa: E402
from rig_v2_lib.mask_and_matting import _synthesize_ew_bust_secondary_mask  # noqa: E402
from rig_v2_lib.part_exporter import _export_part_patch  # noqa: E402
from rig_v2_lib.skeleton_and_normals import _derive_view_bones  # noqa: E402
from rig_v2_lib.view_assembly_stages import (  # noqa: E402
    apply_armhole_shifts,
    compute_and_write_body_metrics,
    inject_capped_limbs,
    inject_hd_torso_and_pauldrons,
    inject_profile_rear_limbs,
    prune_tiny_specks,
)


def build_all(source_dir: Path, out_dir: Path, v1_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    ws_dir = source_dir / "05_mask_ai_workspaces"

    gdignore_src = v1_dir / ".gdignore"
    if gdignore_src.exists():
        shutil.copy2(gdignore_src, out_dir / ".gdignore")

    head_outline_cfg = {"strength": 1.0, "width_px": HEAD_OUTLINE_DEFAULT_PX}
    (out_dir / "head_outline_config.json").write_text(json.dumps(head_outline_cfg, indent="\t") + "\n", encoding="utf-8")

    neck_by_view: dict[str, tuple[float, float]] = {}

    for view in DIRECTIONS:
        ref_rgba = cv2.imread(str(_canonical_rgba_path(source_dir, view)), cv2.IMREAD_UNCHANGED)
        p5_mask = cv2.imread(str(ws_dir / "01_parts_5_despiece" / "split_results" / f"{view}_parts5_mask.png"))
        id_bgra = cv2.imread(str(ws_dir / "02_id_mask_bodies" / "split_results" / f"{view}_id_mask.png"), cv2.IMREAD_UNCHANGED)
        limb_seg = cv2.imread(str(ws_dir / "04_limb_anim_masks" / "split_results" / f"{view}_limb_segments.png"))
        sec_path = ws_dir / "05_secondary_jiggle_masks" / "split_results" / f"{view}_secondary_jiggle_mask.png"
        sec_bgra = cv2.imread(str(sec_path), cv2.IMREAD_UNCHANGED) if sec_path.exists() else None

        part_masks, neck_disp = _compute_body_neck_cut(p5_mask, id_bgra, ref_rgba)
        neck_by_view[view] = neck_disp
        z_orders = VIEW_Z_ORDERS[view]

        custom_part_src: dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]] = {}
        limb_seg_overrides: dict[str, np.ndarray] = {}
        rear_darken_parts: set[str] = set()
        inject_profile_rear_limbs(view, part_masks, custom_part_src, limb_seg_overrides, rear_darken_parts, ws_dir)

        bones_list = _derive_view_bones(view, part_masks, limb_seg, neck_disp, limb_seg_overrides)
        bones_by_name = {str(b["name"]): list(b["pos"]) for b in bones_list}

        capped_parts: set[str] = set()
        exact_crop_rects_px: dict[str, tuple[int, int, int, int]] = {}
        inject_capped_limbs(
            view, part_masks, custom_part_src, limb_seg_overrides,
            capped_parts, exact_crop_rects_px, bones_list, bones_by_name,
            ref_rgba, id_bgra, limb_seg, ws_dir, out_dir,
        )
        arm_shift_du_by_part = apply_armhole_shifts(view, part_masks, bones_list, bones_by_name)
        if sec_bgra is None and view in ("e", "w"):
            sec_bgra = _synthesize_ew_bust_secondary_mask(view, part_masks["body_core"], bones_by_name)

        using_hd_torso, neck_disp, pauldron_shift_du_by_part = inject_hd_torso_and_pauldrons(
            view, part_masks, custom_part_src, limb_seg_overrides,
            capped_parts, bones_list, bones_by_name, neck_disp, neck_by_view,
            ref_rgba, id_bgra, limb_seg, ws_dir, out_dir,
        )
        prune_tiny_specks(part_masks, custom_part_src)

        rect_shifts_du: dict[str, tuple[float, float]] = {}
        rect_shifts_du.update(arm_shift_du_by_part)
        rect_shifts_du.update(pauldron_shift_du_by_part)

        parts_dir = out_dir / view / "parts_5"
        parts_dir.mkdir(parents=True, exist_ok=True)
        rects: dict[str, list[float]] = {}
        meta_stub = {
            "view": view,
            "tex_scale": TEX_SCALE,
            "has_hd_neck": using_hd_torso,
            "rig_origin": bones_by_name["Pelvis"],
            "neck_anchor": bones_by_name["Neck"],
            "z_orders": z_orders,
            "rects": rects,
            "bones": bones_list,
        }

        for pname in PART_NAMES + ("pauldron_r", "pauldron_l"):
            if (view == "e" and pname == "pauldron_l") or (view == "w" and pname == "pauldron_r"):
                sh_ref_k = "Shoulder_L" if pname == "pauldron_l" else "Shoulder_R"
                sh_ref_pos = bones_by_name.get(sh_ref_k, [260.0, 192.0])
                empty_12 = np.zeros((12, 12, 4), dtype=np.uint8)
                nd_12 = np.zeros((12, 12, 4), dtype=np.uint8)
                nd_12[:, :, 0] = 254
                nd_12[:, :, 1] = 128
                nd_12[:, :, 2] = 128
                nd_12[:, :, 3] = 80
                cv2.imwrite(str(parts_dir / f"{pname}.png"), empty_12)
                cv2.imwrite(str(parts_dir / f"{pname}_id_mask.png"), empty_12)
                cv2.imwrite(str(parts_dir / f"{pname}_normal_depth.png"), nd_12)
                rects[pname] = [round(float(sh_ref_pos[0]) - 2.0, 4), round(float(sh_ref_pos[1]) - 2.0, 4), 4.0, 4.0]
                continue
            if pname not in part_masks:
                continue
            p_rgba, p_id, _ = custom_part_src.get(pname, (ref_rgba, id_bgra, limb_seg))
            darken_f = REAR_DEPTH_DARKEN_FACTOR if pname in rear_darken_parts else 1.0
            pau_mask_export = None
            if pname == "body_core":
                pau_union_exp = np.zeros((PX_H, PX_W), dtype=bool)
                for pk_u in ("pauldron_r", "pauldron_l"):
                    if pk_u in part_masks and int(part_masks[pk_u].sum()) >= 25:
                        pau_union_exp |= part_masks[pk_u]
                if np.any(pau_union_exp):
                    pau_mask_export = pau_union_exp.astype(np.uint8) * 255

            rects[pname] = _export_part_patch(
                pname,
                part_masks[pname],
                p_rgba,
                p_id,
                sec_bgra,
                parts_dir,
                meta_stub,
                depth_darken_factor=darken_f,
                leg_masks_union=(part_masks["leg_r"] | part_masks["leg_l"]) if pname == "body_core" else None,
                body_core_mask=part_masks["body_core"] if pname in LIMB_PARTS else None,
                pauldron_mask_full=pau_mask_export,
                exact_crop_rect_px=exact_crop_rects_px.get(pname),
                rect_shift_du=rect_shifts_du.get(pname, (0.0, 0.0)),
            )

        meta_stub["rects"] = rects
        (parts_dir / "parts_5_meta.json").write_text(json.dumps(meta_stub, indent=2) + "\n", encoding="utf-8")
        print(f"[BUILD BODY {view.upper()}] bones=18 neck={bones_by_name['Neck']} ShL={bones_by_name['Shoulder_L']} ElL={bones_by_name['Elbow_L']} WrL={bones_by_name['Wrist_L']}")

    heads_meta = build_heads_pack(source_dir, out_dir, neck_by_view)
    print(f"[BUILD HEADS] built {len([k for k in heads_meta if not k.startswith('_')])} entries")
    heads_meta = apply_manual_calibration_overrides(out_dir, heads_meta)
    compute_and_write_body_metrics(out_dir, heads_meta)

    audit_dir = ws_dir / "final_rig_audit"
    render_final_audits(source_dir, out_dir, audit_dir, heads_meta)
    print(f"[AUDIT] saved final rig verification sheets in {audit_dir}")


def apply_manual_calibration_overrides(out_dir: Path, heads_meta: dict) -> dict:
    """Re-applies saved manual_calibration_overrides.json while keeping PNG rect sizes exact."""
    ov_path = out_dir / "manual_calibration_overrides.json"
    if not ov_path.exists():
        return heads_meta
    ov = json.loads(ov_path.read_text(encoding="utf-8"))
    views_ov = ov.get("views", {})
    for view, v_data in views_ov.items():
        meta_p = out_dir / view / "parts_5" / "parts_5_meta.json"
        if not meta_p.exists():
            continue
        meta = json.loads(meta_p.read_text(encoding="utf-8"))
        for key in ("rig_origin", "neck_anchor", "z_orders", "bones"):
            if key in v_data and v_data[key]:
                meta[key] = v_data[key]
        if "rects" in v_data and isinstance(v_data["rects"], dict):
            cur_rects: dict[str, list[float]] = meta.get("rects", {})
            for pk, ov_r in v_data["rects"].items():
                if pk in cur_rects and len(ov_r) == 4:
                    gx, gy, gw, gh = [float(v) for v in cur_rects[pk]]
                    ox, oy, ow, oh = [float(v) for v in ov_r]
                    # Preserve calibrated position only if crop bounds did not materially change; always keep exact PNG w/h
                    if abs(ow - gw) < 1.0 and abs(oh - gh) < 1.0:
                        cur_rects[pk] = [ox, oy, gw, gh]
                    else:
                        cur_rects[pk] = [gx, gy, gw, gh]
            meta["rects"] = cur_rects
        meta_p.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    heads_ov = ov.get("heads", {})
    if heads_ov:
        if "combo_transforms" in heads_ov and isinstance(heads_ov["combo_transforms"], dict):
            heads_meta["combo_transforms"] = heads_ov["combo_transforms"]
        for h_key, h_entry in heads_ov.items():
            if h_key in heads_meta and isinstance(h_entry, dict) and isinstance(heads_meta[h_key], dict):
                for hk_field in ("sprite_offset", "neck_pivot_px"):
                    if hk_field in h_entry:
                        heads_meta[h_key][hk_field] = h_entry[hk_field]
        (out_dir / "heads" / "heads_metadata.json").write_text(json.dumps(heads_meta, indent=2) + "\n", encoding="utf-8")
    print(f"[CALIBRATION] re-applied {ov_path.name} ({len(views_ov)} views)")
    return heads_meta


def main() -> None:
    parser = argparse.ArgumentParser(description="Build 8-dir Valentina v2 planar rig asset pack.")
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--v1-dir", type=Path, default=DEFAULT_V1_DIR)
    args = parser.parse_args()
    build_all(args.source_dir, args.out_dir, args.v1_dir)


if __name__ == "__main__":
    main()
