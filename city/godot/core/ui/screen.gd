## A single menu screen inside a `ScreenStack`. Fills its parent's canvas
## layer, eats mouse clicks so nothing behind it reacts to them, and builds
## its children lazily, the first time the stack pushes it. Under a skin
## whose focus is `glow`, it also draws a soft halo behind whichever of its
## controls has the focus.
extends Control
class_name Screen

## The shared shader that draws the `glow` halo.
const FOCUS_GLOW := preload("res://core/ui/focus_glow.gdshader")

## The stack this screen belongs to, set by `ScreenStack.push` before
## `build()` runs.
var stack: ScreenStack

## The theme most recently applied by `apply_theme`.
var ui: UiTheme

## The control to refocus when this screen is uncovered again, recorded by
## the stack when another screen is pushed on top of it.
var last_focus: Control

## The `glow` skin's halo: a panel drawn behind the focused control (its
## internal child, shown behind it), reaching `UiTheme.GLOW_SPREAD` pixels
## beyond it. `null` under any other focus mode.
var focus_halo: Panel

## Whether `build()` has already run, so pushing the same screen twice does
## not build it twice.
var _built := false

## Below this width, in pixels, a screen takes its narrow layout: its parts
## stack vertically rather than side by side (the window of a small
## laptop turned tall, or a phone later).
const NARROW_WIDTH := 900.0
## Whether this screen is narrower than NARROW_WIDTH; when it changes, the
## screen restyles, and `restyle` lays it out for its width.
var narrow := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Builds this screen's children. Virtual: does nothing by default. Runs
## once, the first time the stack pushes this screen.
func build() -> void:
	pass


## Watches the viewport's focus while in the tree, for the halo.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		var viewport := get_viewport()
		if not viewport.gui_focus_changed.is_connected(_on_focus_changed):
			viewport.gui_focus_changed.connect(_on_focus_changed)
	elif what == NOTIFICATION_EXIT_TREE:
		var viewport := get_viewport()
		if viewport != null and viewport.gui_focus_changed.is_connected(_on_focus_changed):
			viewport.gui_focus_changed.disconnect(_on_focus_changed)
	elif what == NOTIFICATION_RESIZED:
		var now := size.x > 0.0 and size.x < NARROW_WIDTH
		if now != narrow:
			narrow = now
			if _built and ui != null:
				restyle()


## Called once per push, after `build()` has run at least once. Assigns the
## theme, adds or removes the focus halo to suit it, and asks the screen to
## restyle itself.
func apply_theme(t: UiTheme) -> void:
	ui = t
	narrow = size.x > 0.0 and size.x < NARROW_WIDTH
	theme = t.theme
	if ui.focus_mode() == "glow":
		_ensure_halo()
		var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		_on_focus_changed(owner)
	elif is_instance_valid(focus_halo):
		focus_halo.free()
		focus_halo = null
	restyle()


## Makes the halo if there is none (its control may have been freed with
## it), and colours it from the current skin.
func _ensure_halo() -> void:
	if not is_instance_valid(focus_halo):
		focus_halo = Panel.new()
		focus_halo.name = "FocusHalo"
		focus_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_halo.focus_mode = Control.FOCUS_NONE
		focus_halo.show_behind_parent = true
		focus_halo.visible = false
		# A plain box over the whole rectangle, for the shader to paint.
		var box := StyleBoxFlat.new()
		box.bg_color = Color.WHITE
		focus_halo.add_theme_stylebox_override("panel", box)
		var glow := ShaderMaterial.new()
		glow.shader = FOCUS_GLOW
		focus_halo.material = glow
		focus_halo.resized.connect(_size_halo)
		add_child(focus_halo, false, Node.INTERNAL_MODE_FRONT)
	var glow_material := focus_halo.material as ShaderMaterial
	glow_material.set_shader_parameter("glow_colour", ui.glow_colour())
	glow_material.set_shader_parameter("spread", float(UiTheme.GLOW_SPREAD))
	glow_material.set_shader_parameter("radius", float(ui.button_radius()))


## Moves the halo behind `control` when it is one of this screen's own, and
## hides it when the focus is elsewhere (another screen, or nothing). A
## container never takes it, since it would lay the halo out as a child.
func _on_focus_changed(control: Control) -> void:
	if ui == null or ui.focus_mode() != "glow":
		return
	_ensure_halo()
	if control == null or not is_ancestor_of(control) or control is Container:
		focus_halo.visible = false
		return
	if focus_halo.get_parent() != control:
		focus_halo.get_parent().remove_child(focus_halo)
		control.add_child(focus_halo, false, Node.INTERNAL_MODE_FRONT)
	var spread := float(UiTheme.GLOW_SPREAD)
	focus_halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_halo.offset_left = -spread
	focus_halo.offset_top = -spread
	focus_halo.offset_right = spread
	focus_halo.offset_bottom = spread
	focus_halo.visible = true
	_size_halo()


## The shader works in pixels, so it is told the halo's size.
func _size_halo() -> void:
	if is_instance_valid(focus_halo):
		(focus_halo.material as ShaderMaterial).set_shader_parameter("size", focus_halo.size)


## Re-applies `ui` to this screen's children. Virtual: does nothing by
## default.
func restyle() -> void:
	pass


## Focuses `last_focus` when it is still valid and visible in the tree,
## otherwise the first focusable descendant.
func focus_first() -> void:
	if is_instance_valid(last_focus) and last_focus.is_visible_in_tree():
		last_focus.grab_focus()
		return
	var first := _first_focusable(self)
	if first != null:
		first.grab_focus()


static func _first_focusable(node: Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _first_focusable(child)
		if found != null:
			return found
	return null


## Called when the stack is about to pop this screen for `ui_cancel` or a
## back gesture. Virtual: returns false by default, so the stack pops the
## screen. Returning true means the screen handled the back itself (closed
## a sub-panel, say) and should stay on the stack.
func on_back() -> bool:
	return false


## Whether the world (walking, camera, and the like) should keep receiving
## input while this screen is the top of the stack. False by default; the
## play HUD overrides this to true, since it is not a blocking menu.
func wants_world_input() -> bool:
	return false
