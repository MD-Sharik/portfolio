extends SceneTree
## Builds the Play Store images from the two source artworks:
##   godot --headless --path . --script res://tools/make_store_assets.gd -- --banner BANNER.webp --square SQUARE.webp
## Writes: store/icon_512.png, store/feature_graphic_1024x500.png and the launcher icons in assets/store/.

func _load(path: String) -> Image:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		push_error("cannot load %s" % path)
		quit(1)
	img.convert(Image.FORMAT_RGBA8)
	return img

func _scaled(img: Image, w: int, h: int) -> Image:
	var c := img.duplicate() as Image
	c.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return c

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var banner_path := ""
	var square_path := ""
	for i in args.size():
		if args[i] == "--banner": banner_path = args[i + 1]
		if args[i] == "--square": square_path = args[i + 1]
	var banner := _load(banner_path)
	var square := _load(square_path)

	# Feature graphic 1024x500, no alpha. The source banner has a watermark sparkle in its
	# bottom-right corner, so use only the top-left 1884x920 (same 1024:500 aspect) of it.
	var region := banner.get_region(Rect2i(0, 0, 1884, 920))
	var fg := _scaled(region, 1024, 500)
	fg.convert(Image.FORMAT_RGB8)
	fg.save_png("res://store/feature_graphic_1024x500.png")

	# Play Store icon 512x512 + legacy launcher icon 192x192.
	var s512 := _scaled(square, 512, 512)
	s512.save_png("res://store/icon_512.png")
	_scaled(square, 192, 192).save_png("res://assets/store/icon_192.png")

	# Adaptive icon: the OS masks the outer third, so shrink the art into the 66% safe zone.
	var fg432 := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	fg432.fill(Color(0, 0, 0, 0))
	var art := _scaled(square, 300, 300)
	fg432.blit_rect(art, Rect2i(0, 0, 300, 300), Vector2i(66, 66))
	fg432.save_png("res://assets/store/icon_fg_432.png")
	var bg432 := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg432.fill(Color.WHITE)
	bg432.save_png("res://assets/store/icon_bg_432.png")
	print("store assets written")
	quit(0)
