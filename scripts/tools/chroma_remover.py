import sys
import os
from PIL import Image

def remove_chroma_key(image_path: str, output_path: str, key_color=(255, 0, 255), tolerance=60, crop=True, rotate_deg=-90) -> bool:
    """
    Removes key_color (default Magenta #FF00FF) from image_path using pure PIL,
    replaces it with transparency, crops to bounding box, optionally rotates,
    and saves to output_path.
    """
    try:
        img = Image.open(image_path).convert("RGBA")
        kr, kg, kb = key_color
        
        datas = img.getdata()
        new_data = []
        
        for item in datas:
            r, g, b, a = item
            # Euclidean color distance
            dist = ((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2) ** 0.5
            if dist < tolerance:
                new_data.append((255, 255, 255, 0))
            else:
                new_data.append(item)
                
        img.putdata(new_data)
        
        if crop:
            bbox = img.getbbox()
            if bbox:
                img = img.crop(bbox)
                
        if rotate_deg != 0:
            # Rotate image (expand=True so nothing is cut off)
            img = img.rotate(rotate_deg, expand=True, resample=Image.Resampling.BICUBIC)
            if crop:
                bbox = img.getbbox()
                if bbox:
                    img = img.crop(bbox)
                
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        img.save(output_path, "PNG")
        print(f"Successfully processed: {output_path} (Size: {img.size})")
        return True
    except Exception as e:
        print(f"Error processing {image_path}: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python chroma_remover.py <input_path> <output_path> [tolerance] [crop] [rotate_deg]")
        sys.exit(1)
        
    inp = sys.argv[1]
    outp = sys.argv[2]
    tol = int(sys.argv[3]) if len(sys.argv) > 3 else 60
    do_crop = sys.argv[4].lower() != "false" if len(sys.argv) > 4 else True
    rot = int(sys.argv[5]) if len(sys.argv) > 5 else 0
    
    remove_chroma_key(inp, outp, key_color=(255, 0, 255), tolerance=tol, crop=do_crop, rotate_deg=rot)
