"""
Astra Dream — Procesadores ML Secuenciales para RTX 2060 (6 GB VRAM)
Ubicación: sandbox/pilot_rig_lab/tools/ml_stage_processors.py

Cada etapa pesada carga su modelo, ejecuta inferencia y libera VRAM antes de la
siguiente etapa para mantenerse holgado dentro de 6 GB VRAM:
  1. isnet-anime (rembg ONNX)        -> Extracción limpia de fondo (#808080 o #4EB347)
  2. SAM 2.1 Hiera Tiny (~0.6 GB)     -> Corte interactivo de piezas por puntos/caja
  3. Sapiens-Lite 0.3B Normal (~2.2GB)-> Mapa de normales 2.5D suave
  4. Depth-Anything-V2-Small (~0.5 GB)-> Mapa de profundidad relativa nítida para anime
  5. K-Means CIELAB                   -> Agrupación determinista de materiales (Clown Pass)
"""
import gc
import os
from typing import Dict, List, Optional, Tuple

import cv2
import numpy as np
import torch
from PIL import Image

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
MODELS_CACHE = os.path.join(os.path.dirname(__file__), "models")
os.makedirs(MODELS_CACHE, exist_ok=True)
os.environ.setdefault("HF_HOME", MODELS_CACHE)
os.environ.setdefault("U2NET_HOME", os.path.join(MODELS_CACHE, "u2net"))


def clear_vram() -> None:
    """Libera memoria de Python y caché CUDA entre etapas secuenciales."""
    gc.collect()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()


def get_device() -> str:
    return "cuda" if torch.cuda.is_available() else "cpu"


def remove_background_anime(pil_rgb: Image.Image) -> Image.Image:
    """
    Extrae el primer plano con rembg (isnet-anime) evitando color spill sobre
    fondos #808080 o #4EB347. Conserva la tinta #080812 y limpia motas aisladas.
    """
    from rembg import new_session, remove

    session = new_session("isnet-anime")
    fg_rgba = remove(pil_rgb.convert("RGB"), session=session).convert("RGBA")
    del session
    clear_vram()

    arr = np.array(fg_rgba)
    alpha_bin = (arr[:, :, 3] > 96).astype(np.uint8)
    # Conservar componentes significativos (en hojas de cabezas puede haber 3 islas)
    num_l, labels, stats, _ = cv2.connectedComponentsWithStats(alpha_bin)
    keep = np.zeros_like(alpha_bin)
    min_area = max(300, int(arr.shape[0] * arr.shape[1] * 0.002))
    for i in range(1, num_l):
        if stats[i, cv2.CC_STAT_AREA] >= min_area:
            keep[labels == i] = 1

    # Suavizado ligero del alfa solo en bordes reales dentro de los componentes retenidos
    keep_u8 = (keep * 255).astype(np.uint8)
    arr[:, :, 3] = np.minimum(arr[:, :, 3], keep_u8)
    return Image.fromarray(arr, mode="RGBA")


class Sam2Session:
    """Sesión interactiva rápida con SAM 2.1 Tiny (~0.63 GB VRAM)."""

    def __init__(self, fg_rgba: Image.Image) -> None:
        from sam2.sam2_image_predictor import SAM2ImagePredictor

        self.device = get_device()
        arr = np.array(fg_rgba.convert("RGBA"))
        self.alpha_mask = arr[:, :, 3] > 80
        # Componer sobre gris neutro #808080 para contraste limpio de bordes
        comp = np.full((arr.shape[0], arr.shape[1], 3), 128, dtype=np.uint8)
        comp[self.alpha_mask] = arr[:, :, :3][self.alpha_mask]
        self.comp_rgb = comp

        self.predictor = SAM2ImagePredictor.from_pretrained(
            "facebook/sam2.1-hiera-tiny",
            device=self.device,
        )
        self.predictor.set_image(self.comp_rgb)

    def predict(
        self,
        points_xy: List[Tuple[int, int]],
        labels: List[int],
        box_xyxy: Optional[Tuple[int, int, int, int]] = None,
    ) -> np.ndarray:
        """Devuelve máscara booleana (H, W) recortada al alfa del personaje."""
        if not points_xy and box_xyxy is None:
            return np.zeros(self.alpha_mask.shape, dtype=bool)

        pts_np = np.array(points_xy, dtype=np.float32) if points_xy else None
        lbl_np = np.array(labels, dtype=np.int32) if labels else None
        box_np = np.array(box_xyxy, dtype=np.float32)[None, :] if box_xyxy is not None else None

        masks, scores, _ = self.predictor.predict(
            point_coords=pts_np,
            point_labels=lbl_np,
            box=box_np,
            multimask_output=True,
        )
        best_idx = int(np.argmax(scores))
        raw_mask = (masks[best_idx] > 0.0) & self.alpha_mask
        return raw_mask

    def close(self) -> None:
        del self.predictor
        self.predictor = None
        clear_vram()


def estimate_sapiens_normals_and_depth(fg_rgba: Image.Image) -> Image.Image:
    """
    Estima mapa Normal 2.5D (RGB) + Profundidad relativa (A) de forma secuencial
    para no superar ~2.9 GB VRAM en RTX 2060:
      - Normales: facebook/sapiens-normal-0.3b-torchscript
      - Profundidad: depth-anything/Depth-Anything-V2-Small-hf
    """
    from huggingface_hub import hf_hub_download
    from transformers import AutoImageProcessor, AutoModelForDepthEstimation

    device = get_device()
    arr = np.array(fg_rgba.convert("RGBA"))
    h, w = arr.shape[:2]
    alpha = arr[:, :, 3] > 64

    comp = np.full((h, w, 3), 128, dtype=np.uint8)
    comp[alpha] = arr[:, :, :3][alpha]
    comp_pil = Image.fromarray(comp)

    # --- Etapa A: Sapiens-Lite 0.3B Normales ---
    clear_vram()
    nrm_rgb_vis = np.full((h, w, 3), 128, dtype=np.uint8)
    nrm_rgb_vis[:, :, 2] = 255
    try:
        ckpt = hf_hub_download(
            repo_id="facebook/sapiens-normal-0.3b-torchscript",
            filename="sapiens_0.3b_normal_render_people_epoch_66_torchscript.pt2",
            cache_dir=MODELS_CACHE,
        )
        model = torch.jit.load(ckpt).eval().to(device)
        rgb_sap = arr[:, :, :3].copy()
        rgb_sap[~alpha] = 0
        resized = cv2.resize(rgb_sap, (768, 1024), interpolation=cv2.INTER_AREA)
        ten = torch.from_numpy(resized).float().permute(2, 0, 1).unsqueeze(0) / 255.0
        mean = torch.tensor([123.5, 116.5, 103.5]).view(1, 3, 1, 1) / 255.0
        std = torch.tensor([58.395, 57.12, 57.375]).view(1, 3, 1, 1) / 255.0
        ten = ((ten - mean) / std).to(device)

        with torch.no_grad():
            if device == "cuda":
                with torch.amp.autocast("cuda", dtype=torch.float16):
                    out = model(ten)
            else:
                out = model(ten)

        nrm = np.transpose(out[0].float().cpu().numpy(), (1, 2, 0))
        norm_len = np.linalg.norm(nrm, axis=2, keepdims=True) + 1e-6
        nrm = nrm / norm_len
        nrm_u8 = np.clip((nrm * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
        nrm_full = cv2.resize(nrm_u8, (w, h), interpolation=cv2.INTER_CUBIC)
        # Suavizado bilateral preserva bordes anatómicos y borra escalonado de grilla 512x384
        nrm_smooth = cv2.bilateralFilter(nrm_full, d=9, sigmaColor=28, sigmaSpace=9)
        nrm_rgb_vis[alpha] = nrm_smooth[alpha]
        del model, ten, out
    except Exception as exc:
        print(f"[Warn] Sapiens Normal fallback analítico: {exc}")
        dist = cv2.distanceTransform(alpha.astype(np.uint8), cv2.DIST_L2, 5)
        dist_n = cv2.GaussianBlur(dist / max(float(dist.max()), 1.0), (15, 15), 4.0)
        gx = cv2.Sobel(dist_n, cv2.CV_32F, 1, 0, ksize=5)
        gy = cv2.Sobel(dist_n, cv2.CV_32F, 0, 1, ksize=5)
        vec = np.stack([-gx * 2.5, -gy * 2.5, np.ones_like(gx)], axis=2)
        vec /= np.linalg.norm(vec, axis=2, keepdims=True) + 1e-6
        nrm_rgb_vis = np.clip((vec * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    finally:
        clear_vram()

    # --- Etapa B: Depth-Anything-V2-Small ---
    depth_u8 = np.zeros((h, w), dtype=np.uint8)
    try:
        da_proc = AutoImageProcessor.from_pretrained("depth-anything/Depth-Anything-V2-Small-hf")
        da_model = AutoModelForDepthEstimation.from_pretrained(
            "depth-anything/Depth-Anything-V2-Small-hf"
        ).to(device)
        da_in = da_proc(images=comp_pil, return_tensors="pt").to(device)
        with torch.no_grad():
            da_out = da_model(**da_in)
        dep_pred = torch.nn.functional.interpolate(
            da_out.predicted_depth.unsqueeze(1),
            size=(h, w),
            mode="bicubic",
            align_corners=False,
        ).squeeze().cpu().numpy()
        valid = dep_pred[alpha]
        if valid.size > 0:
            d_min, d_max = float(np.percentile(valid, 2)), float(np.percentile(valid, 98))
            dep_norm = np.clip((dep_pred - d_min) / max(d_max - d_min, 1e-5), 0.0, 1.0)
            depth_u8[alpha] = (dep_norm[alpha] * 255.0).astype(np.uint8)
        del da_model, da_proc, da_in, da_out
    except Exception as exc:
        print(f"[Warn] Depth-Anything fallback EDT: {exc}")
        dist = cv2.distanceTransform(alpha.astype(np.uint8), cv2.DIST_L2, 5)
        depth_u8[alpha] = np.clip((dist[alpha] / max(float(dist.max()), 1.0)) * 255.0, 0, 255).astype(np.uint8)
    finally:
        clear_vram()

    out_rgba = np.zeros((h, w, 4), dtype=np.uint8)
    out_rgba[:, :, :3] = nrm_rgb_vis
    out_rgba[:, :, 3] = depth_u8
    return Image.fromarray(out_rgba, mode="RGBA")


def estimate_head_normals_and_depth(head_rgba: Image.Image) -> Image.Image:
    """
    Estima Profundidad con Depth-Anything-V2-Small en recorte de cabeza con padding neutro
    y deriva normales 2.5D volumétricas suaves (pelo, nariz, mejillas, monóculo).
    """
    from transformers import AutoImageProcessor, AutoModelForDepthEstimation

    device = get_device()
    arr = np.array(head_rgba.convert("RGBA"))
    h, w = arr.shape[:2]
    alpha = arr[:, :, 3] > 64

    comp = np.full((h, w, 3), 128, dtype=np.uint8)
    comp[alpha] = arr[:, :, :3][alpha]
    pad = max(24, int(max(h, w) * 0.16))
    padded = np.full((h + pad * 2, w + pad * 2, 3), 128, dtype=np.uint8)
    padded[pad:pad + h, pad:pad + w] = comp
    comp_pil = Image.fromarray(padded)

    clear_vram()
    depth_f = np.zeros((h, w), dtype=np.float32)
    try:
        da_proc = AutoImageProcessor.from_pretrained("depth-anything/Depth-Anything-V2-Small-hf")
        da_model = AutoModelForDepthEstimation.from_pretrained(
            "depth-anything/Depth-Anything-V2-Small-hf"
        ).to(device)
        da_in = da_proc(images=comp_pil, return_tensors="pt").to(device)
        with torch.no_grad():
            da_out = da_model(**da_in)
        dep_pad = torch.nn.functional.interpolate(
            da_out.predicted_depth.unsqueeze(1),
            size=(h + pad * 2, w + pad * 2),
            mode="bicubic",
            align_corners=False,
        ).squeeze().cpu().numpy()
        dep_crop = dep_pad[pad:pad + h, pad:pad + w]
        valid = dep_crop[alpha]
        if valid.size > 0:
            d_min, d_max = float(np.percentile(valid, 2)), float(np.percentile(valid, 98))
            depth_f[alpha] = np.clip((dep_crop[alpha] - d_min) / max(d_max - d_min, 1e-5), 0.0, 1.0)
        del da_model, da_proc, da_in, da_out
    except Exception as exc:
        print(f"[Warn] Head Depth fallback EDT: {exc}")
        dist = cv2.distanceTransform(alpha.astype(np.uint8), cv2.DIST_L2, 5)
        depth_f[alpha] = np.clip(dist[alpha] / max(float(dist.max()), 1.0), 0.0, 1.0)
    finally:
        clear_vram()

    # Mezcla profundidad AI + curvatura de silueta para normales 2.5D limpias sin ruido cel
    dist_sil = cv2.distanceTransform(alpha.astype(np.uint8), cv2.DIST_L2, 5)
    dist_sil = dist_sil / max(float(dist_sil.max()), 1.0)
    comb = cv2.GaussianBlur(depth_f * 0.72 + dist_sil * 0.28, (9, 9), 2.4)
    gx = cv2.Sobel(comb, cv2.CV_32F, 1, 0, ksize=5)
    gy = cv2.Sobel(comb, cv2.CV_32F, 0, 1, ksize=5)
    vec = np.stack([-gx * 1.9, -gy * 1.9, np.ones_like(gx)], axis=2)
    vec /= np.linalg.norm(vec, axis=2, keepdims=True) + 1e-6

    nrm_rgb = np.full((h, w, 3), 128, dtype=np.uint8)
    nrm_rgb[:, :, 2] = 255
    nrm_smooth = cv2.bilateralFilter(np.clip((vec * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8), d=7, sigmaColor=22, sigmaSpace=7)
    nrm_rgb[alpha] = nrm_smooth[alpha]

    out_rgba = np.zeros((h, w, 4), dtype=np.uint8)
    out_rgba[:, :, :3] = nrm_rgb
    out_rgba[:, :, 3] = np.clip(depth_f * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(out_rgba, mode="RGBA")


def cluster_materials_kmeans(
    fg_rgba: Image.Image,
    n_clusters: int = 8,
    is_head: bool = False,
    is_legs: bool = False,
) -> Tuple[np.ndarray, List[Dict]]:
    """
    Agrupa píxeles de color (excluyendo tinta negra #080812 y fondo) en espacio CIELAB
    mediante K-Means y propone asignaciones semánticas iniciales:
      - 'skin'      -> 0 (no recoloreado)
      - 'accent'    -> R (monóculo, visor, tiras de energía)
      - 'armor'     -> G (placas metálicas, hombreras, grebas)
      - 'suit'      -> B (tela oscura del plugsuit)
      - 'hair'      -> A en cabeza
      - 'stockings' -> A en piernas
    Devuelve (cluster_id_map [-1 fondo/tinta, 0..K-1], metadata_por_cluster).
    """
    from sklearn.cluster import MiniBatchKMeans

    arr = np.array(fg_rgba.convert("RGBA"))
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3] > 80

    rgb_f = rgb.astype(np.float32) / 255.0
    luma = 0.299 * rgb_f[:, :, 0] + 0.587 * rgb_f[:, :, 1] + 0.114 * rgb_f[:, :, 2]
    non_ink = alpha & (luma > 0.088)

    cluster_map = np.full((h, w), -1, dtype=np.int32)
    if int(non_ink.sum()) < 50:
        return cluster_map, []

    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.float32)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)

    pts_lab = lab[non_ink]
    k_eff = min(n_clusters, max(2, len(pts_lab) // 40))
    kmeans = MiniBatchKMeans(n_clusters=k_eff, random_state=42, batch_size=2048, n_init=5)
    labels_flat = kmeans.fit_predict(pts_lab)
    cluster_map[non_ink] = labels_flat

    yy, _ = np.mgrid[0:h, 0:w]
    yn = yy.astype(np.float32) / max(float(h), 1.0)

    clusters_info: List[Dict] = []
    for cid in range(k_eff):
        m = cluster_map == cid
        if not np.any(m):
            continue
        mean_rgb = rgb[m].mean(axis=0)
        r_m, g_m, b_m = float(mean_rgb[0]), float(mean_rgb[1]), float(mean_rgb[2])
        mean_hsv = hsv[m].mean(axis=0)
        hue, sat, val = float(mean_hsv[0]), float(mean_hsv[1]), float(mean_hsv[2])
        y_mean = float(yn[m].mean())
        luma_m = (0.299 * r_m + 0.587 * g_m + 0.114 * b_m) / 255.0

        # Heurística semántica inicial calibrada para Valentina (Editable en 1 clic)
        warmth = r_m - b_m
        red_dom = r_m - max(g_m, b_m)
        role = "suit"
        if is_head:
            if red_dom > 42.0 and sat > 92.0 and luma_m < 0.58 and (hue < 18.0 or hue > 152.0):
                role = "accent"
            elif (warmth > 8.0 and (hue <= 28.0 or hue >= 158.0) and sat >= 14.0 and luma_m > 0.22):
                role = "skin"
            elif sat < 45.0 and luma_m > 0.34:
                role = "hair"
            elif luma_m <= 0.34:
                role = "suit"
            else:
                role = "hair"
        else:
            if red_dom > 36.0 and sat > 92.0 and (hue < 16.0 or hue > 156.0):
                role = "accent"
            elif val > 140.0 and warmth > 18.0 and (4.0 <= hue <= 26.0 or hue >= 165.0) and 16.0 <= sat < 145.0:
                role = "skin"
            elif is_legs and y_mean < 0.68 and warmth > 4.0 and sat < 96.0 and 0.15 <= luma_m <= 0.48:
                role = "stockings"
            elif luma_m > 0.36 and sat < 42.0:
                role = "armor"
            elif luma_m <= 0.30:
                role = "suit"
            else:
                role = "armor" if (sat < 36.0 and luma_m >= 0.31) else "suit"

        clusters_info.append({
            "id": cid,
            "count": int(m.sum()),
            "mean_rgb": [int(round(r_m)), int(round(g_m)), int(round(b_m))],
            "luma": round(luma_m, 3),
            "y_mean": round(y_mean, 3),
            "role": role,
        })

    clusters_info.sort(key=lambda c: -c["count"])
    return cluster_map, clusters_info


def render_id_mask_from_clusters(
    fg_rgba: Image.Image,
    cluster_map: np.ndarray,
    clusters_info: List[Dict],
    part_name: str,
) -> Image.Image:
    """Hornea <part>_id_mask.png RGBA compatible 100% con pilot_rig_stylizer.gdshader."""
    arr = np.array(fg_rgba.convert("RGBA"), dtype=np.float32) / 255.0
    h, w = arr.shape[:2]
    alpha = arr[:, :, 3]
    luma = 0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]

    role_by_cid = {c["id"]: c["role"] for c in clusters_info}
    ch_r = np.zeros((h, w), dtype=np.float32)
    ch_g = np.zeros((h, w), dtype=np.float32)
    ch_b = np.zeros((h, w), dtype=np.float32)
    ch_a = np.zeros((h, w), dtype=np.float32)
    skin_block = np.zeros((h, w), dtype=np.float32)

    for cid, role in role_by_cid.items():
        m = (cluster_map == cid).astype(np.float32)
        if role == "accent":
            ch_r += m
        elif role == "armor":
            ch_g += m
        elif role == "suit":
            ch_b += m
        elif role == "hair" and part_name.startswith("head"):
            ch_a += m
        elif role == "stockings" and part_name == "hips_legs":
            ch_a += m
        elif role == "skin":
            skin_block += m

    ink_weight = np.clip((0.095 - luma) / 0.040, 0.0, 1.0)
    hard_lock = (
        (1.0 - np.clip(skin_block, 0.0, 1.0))
        * (1.0 - ink_weight * 0.90)
        * np.clip((alpha - 0.10) / 0.40, 0.0, 1.0)
    )

    k3 = np.ones((3, 3), dtype=np.uint8)

    def finalize(ch: np.ndarray) -> np.ndarray:
        dil = cv2.dilate(np.clip(ch, 0.0, 1.0), k3, iterations=1)
        sm = cv2.GaussianBlur(dil, (3, 3), 0.75)
        return np.clip(sm * hard_lock * 255.0, 0.0, 255.0).astype(np.uint8)

    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[:, :, 0] = finalize(ch_r)
    out[:, :, 1] = finalize(ch_g)
    out[:, :, 2] = finalize(ch_b)
    out[:, :, 3] = finalize(ch_a)
    return Image.fromarray(out, mode="RGBA")
