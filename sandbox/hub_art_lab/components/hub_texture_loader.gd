class_name HubTextureLoader
extends RefCounted

## Cargador determinista de texturas Multi-Mapa para Hub Art Lab.
## Garantiza que los mapas *_ink_sdf.png carguen estrictamente SIN mipmaps (LOD 0)
## y que albedo/id/ilm mantengan el estado de mipmaps apropiado incluso en pruebas headless.

static var _cache: Dictionary = {}


static func load_texture_2d(res_path: String, generate_mipmaps: bool = true) -> Texture2D:
	var cache_key: String = "%s|%s" % [res_path, "mip" if generate_mipmaps else "nomip"]
	if _cache.has(cache_key):
		return _cache[cache_key] as Texture2D

	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	var err: Error = img.load(abs_path)
	if err != OK:
		if ResourceLoader.exists(res_path):
			var res_tex: Texture2D = ResourceLoader.load(res_path) as Texture2D
			if res_tex != null:
				if not generate_mipmaps:
					var res_img: Image = res_tex.get_image()
					if res_img != null and res_img.has_mipmaps():
						var copy_img: Image = res_img.duplicate() as Image
						copy_img.clear_mipmaps()
						var clean_tex: ImageTexture = ImageTexture.create_from_image(copy_img)
						_cache[cache_key] = clean_tex
						return clean_tex
				_cache[cache_key] = res_tex
				return res_tex
		return null

	if generate_mipmaps:
		if not img.has_mipmaps():
			img.generate_mipmaps()
	else:
		if img.has_mipmaps():
			img.clear_mipmaps()

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[cache_key] = tex
	return tex


static func clear_cache() -> void:
	_cache.clear()
