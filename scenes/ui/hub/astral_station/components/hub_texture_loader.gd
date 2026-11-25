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

	var is_headless: bool = DisplayServer.get_name() == "headless"
	if ResourceLoader.exists(res_path):
		var res_tex: Texture2D = ResourceLoader.load(res_path) as Texture2D
		if res_tex != null:
			if not generate_mipmaps:
				if not res_tex.has_mipmaps():
					_cache[cache_key] = res_tex
					return res_tex
				var res_img_nomip: Image = res_tex.get_image()
				if res_img_nomip != null:
					var copy_nomip: Image = res_img_nomip.duplicate() as Image
					copy_nomip.clear_mipmaps()
					var clean_tex: ImageTexture = ImageTexture.create_from_image(copy_nomip)
					_cache[cache_key] = clean_tex
					return clean_tex
			else:
				if res_tex.has_mipmaps() or is_headless:
					_cache[cache_key] = res_tex
					return res_tex
				var res_img_mip: Image = res_tex.get_image()
				if res_img_mip != null:
					var copy_mip: Image = res_img_mip.duplicate() as Image
					if not copy_mip.has_mipmaps():
						copy_mip.generate_mipmaps()
					var mip_tex: ImageTexture = ImageTexture.create_from_image(copy_mip)
					_cache[cache_key] = mip_tex
					return mip_tex
			_cache[cache_key] = res_tex
			return res_tex

	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	var err: Error = img.load(abs_path)
	if err != OK:
		return null

	if generate_mipmaps:
		if not is_headless and not img.has_mipmaps():
			img.generate_mipmaps()
	else:
		if img.has_mipmaps():
			img.clear_mipmaps()

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[cache_key] = tex
	return tex


static func clear_cache() -> void:
	_cache.clear()
