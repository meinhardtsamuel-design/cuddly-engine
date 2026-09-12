extends Node3D

# Drag Rivals prototype v0.1
# The physics are intentionally readable/tunable. The first goal is feel, not final realism.

const MILE_QUARTER := 402.336
const MASS_KG := 1760.0
const WHEEL_RADIUS_M := 0.345
const FINAL_DRIVE := 3.55
const DRIVETRAIN_EFF := 0.88
const IDLE_RPM := 850.0
const REDLINE_RPM := 8200.0
const SHIFT_RPM := 7550.0
const GEAR_RATIOS := [4.696, 2.985, 2.146, 1.769, 1.520, 1.275, 1.000, 0.854, 0.689, 0.636]

var player_car: Node3D
var opponent_car: Node3D
var camera: Camera3D

var player_speed := 0.0
var player_distance := 0.0
var player_rpm := IDLE_RPM
var player_gear := 1
var player_shift_timer := 0.0
var player_slip := 0.0
var player_launched := false

var opponent_speed := 0.0
var opponent_distance := 0.0
var opponent_rpm := IDLE_RPM
var opponent_gear := 1
var opponent_shift_timer := 0.0
var opponent_launched := false
var opponent_reaction := 0.215
var opponent_launch_delay_after_player := 0.0

var throttle := 0.0
var brake := 0.0
var gas_touch_id := -1
var brake_touch_id := -1

var stage_progress := 0.0
var prestaged := false
var staged := false
var state := "STAGING"
var staged_brake_time := 0.0
var tree_time := 0.0
var green_time := -1.0
var race_clock := 0.0
var reaction_time := -1.0
var red_light := false
var finish_time := -1.0
var zero_to_100 := -1.0
var hundred_to_200 := -1.0
var time_at_100 := -1.0
var trap_speed := 0.0
var camera_kick := 0.0

var speed_label: Label
var gear_label: Label
var rpm_label: Label
var rpm_bar: ProgressBar
var status_label: Label
var reaction_label: Label
var distance_label: Label
var gas_zone: ColorRect
var gas_fill: ColorRect
var brake_zone: ColorRect
var brake_fill: ColorRect
var rotate_label: Label
var result_panel: Panel
var result_label: Label
var tree_lights: Array[Label] = []
var restart_button: Button

var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 2019
    _build_world()
    _build_ui()
    reset_race()

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("8ca7bb")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("d9e2e8")
    environment.ambient_light_energy = 0.72
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    add_child(sun)

    _add_box("Ground", Vector3(60.0, 0.08, 1050.0), Vector3(0.0, -0.09, -420.0), Color("52614e"))
    _add_box("Strip", Vector3(13.5, 0.04, 1000.0), Vector3(0.0, 0.0, -405.0), Color("25282b"))
    _add_box("LeftShoulder", Vector3(1.2, 0.055, 1000.0), Vector3(-7.25, 0.01, -405.0), Color("777a7b"))
    _add_box("RightShoulder", Vector3(1.2, 0.055, 1000.0), Vector3(7.25, 0.01, -405.0), Color("777a7b"))

    for z in range(0, -850, -12):
        _add_box("CenterMark", Vector3(0.08, 0.015, 5.5), Vector3(0.0, 0.035, float(z) - 3.0), Color("d9d9d2"))
    _add_box("StartLine", Vector3(13.0, 0.025, 0.18), Vector3(0.0, 0.04, -0.9), Color("f3f3ef"))
    _add_box("FinishLine", Vector3(13.0, 0.025, 0.28), Vector3(0.0, 0.04, -MILE_QUARTER - 0.9), Color("f3f3ef"))

    player_car = _create_car("PlayerMustang", Color("24507d"), -2.35)
    opponent_car = _create_car("OpponentMustang", Color("7d2b2b"), 2.35)

    camera = Camera3D.new()
    camera.fov = 68.0
    camera.near = 0.08
    add_child(camera)
    camera.make_current()

func _add_box(node_name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.82
    mesh.material = mat
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    add_child(mesh_instance)
    return mesh_instance

func _create_car(node_name: String, color: Color, lane_x: float) -> Node3D:
    var car := Node3D.new()
    car.name = node_name
    car.position = Vector3(lane_x, 0.45, -0.9)
    add_child(car)

    var body := MeshInstance3D.new()
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(1.92, 0.52, 4.75)
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = color
    body_mat.metallic = 0.45
    body_mat.roughness = 0.28
    body_mesh.material = body_mat
    body.mesh = body_mesh
    body.position = Vector3(0.0, 0.42, 0.0)
    car.add_child(body)

    var roof := MeshInstance3D.new()
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(1.66, 0.48, 2.2)
    var roof_mat := StandardMaterial3D.new()
    roof_mat.albedo_color = color.darkened(0.08)
    roof_mat.metallic = 0.4
    roof_mat.roughness = 0.3
    roof_mesh.material = roof_mat
    roof.mesh = roof_mesh
    roof.position = Vector3(0.0, 0.89, -0.15)
    car.add_child(roof)

    for wheel_x in [-0.96, 0.96]:
        for wheel_z in [-1.55, 1.48]:
            var wheel := MeshInstance3D.new()
            var wheel_mesh := CylinderMesh.new()
            wheel_mesh.top_radius = 0.36
            wheel_mesh.bottom_radius = 0.36
            wheel_mesh.height = 0.28
            wheel_mesh.radial_segments = 18
            var wheel_mat := StandardMaterial3D.new()
            wheel_mat.albedo_color = Color("111111")
            wheel_mat.roughness = 0.95
            wheel_mesh.material = wheel_mat
            wheel.mesh = wheel_mesh
            wheel.rotation_degrees.z = 90.0
            wheel.position = Vector3(wheel_x, 0.16, wheel_z)
            car.add_child(wheel)
    return car

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)

    status_label = _label("", 22, Color.WHITE)
    status_label.position = Vector2(24, 18)
    status_label.size = Vector2(500, 70)
    canvas.add_child(status_label)

    reaction_label = _label("RT ---.---", 18, Color.WHITE)
    reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    reaction_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    reaction_label.position = Vector2(-260, 22)
    reaction_label.size = Vector2(230, 32)
    canvas.add_child(reaction_label)

    distance_label = _label("0 / 402 m", 16, Color("dddddd"))
    distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    distance_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    distance_label.position = Vector2(-260, 54)
    distance_label.size = Vector2(230, 30)
    canvas.add_child(distance_label)

    speed_label = _label("0\nkm/h", 30, Color.WHITE)
    speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    speed_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    speed_label.position = Vector2(28, -150)
    speed_label.size = Vector2(120, 88)
    _add_panel_behind(speed_label, canvas, Color(0.04, 0.04, 0.05, 0.72))
    canvas.add_child(speed_label)

    gear_label = _label("P", 40, Color.WHITE)
    gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gear_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    gear_label.position = Vector2(-50, 18)
    gear_label.size = Vector2(100, 52)
    canvas.add_child(gear_label)

    rpm_label = _label("850 RPM", 17, Color.WHITE)
    rpm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rpm_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    rpm_label.position = Vector2(-120, -72)
    rpm_label.size = Vector2(240, 30)
    canvas.add_child(rpm_label)

    rpm_bar = ProgressBar.new()
    rpm_bar.min_value = 0
    rpm_bar.max_value = REDLINE_RPM
    rpm_bar.value = IDLE_RPM
    rpm_bar.show_percentage = false
    rpm_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    rpm_bar.position = Vector2(-260, -42)
    rpm_bar.size = Vector2(520, 15)
    canvas.add_child(rpm_bar)

    _build_tree(canvas)
    _build_pedals(canvas)

    var help := _label("Touch: links Bremse · rechts Gas | Desktop: SPACE + W | R = Neustart", 14, Color(1,1,1,0.7))
    help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    help.position = Vector2(0, -24)
    help.size = Vector2(0, 22)
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    canvas.add_child(help)

    restart_button = Button.new()
    restart_button.text = "NEUSTART"
    restart_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    restart_button.position = Vector2(-150, 92)
    restart_button.size = Vector2(122, 46)
    restart_button.pressed.connect(reset_race)
    canvas.add_child(restart_button)

    result_panel = Panel.new()
    result_panel.set_anchors_preset(Control.PRESET_CENTER)
    result_panel.position = Vector2(-250, -175)
    result_panel.size = Vector2(500, 350)
    result_panel.visible = false
    canvas.add_child(result_panel)

    result_label = _label("", 23, Color.WHITE)
    result_label.position = Vector2(28, 24)
    result_label.size = Vector2(444, 250)
    result_panel.add_child(result_label)

    var result_restart := Button.new()
    result_restart.text = "NOCHMAL FAHREN"
    result_restart.position = Vector2(125, 285)
    result_restart.size = Vector2(250, 48)
    result_restart.pressed.connect(reset_race)
    result_panel.add_child(result_restart)

    rotate_label = _label("HANDY DREHEN ↻\nDieses Spiel ist für Querformat gebaut.", 30, Color.WHITE)
    rotate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rotate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    rotate_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    rotate_label.visible = false
    rotate_label.z_index = 100
    canvas.add_child(rotate_label)

func _add_panel_behind(control: Control, canvas: CanvasLayer, color: Color) -> void:
    var panel := ColorRect.new()
    panel.color = color
    panel.position = control.position
    panel.size = control.size
    panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    canvas.add_child(panel)

func _build_tree(canvas: CanvasLayer) -> void:
    var tree_panel := VBoxContainer.new()
    tree_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
    tree_panel.position = Vector2(-55, 76)
    tree_panel.size = Vector2(110, 215)
    tree_panel.alignment = BoxContainer.ALIGNMENT_CENTER
    canvas.add_child(tree_panel)

    var names := ["PRE", "STAGE", "A1", "A2", "A3", "GREEN", "RED"]
    for n in names:
        var l := _label("●        ●", 19, Color("34373a"))
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.tooltip_text = n
        l.custom_minimum_size = Vector2(110, 26)
        tree_panel.add_child(l)
        tree_lights.append(l)

func _build_pedals(canvas: CanvasLayer) -> void:
    brake_zone = ColorRect.new()
    brake_zone.color = Color(0.08, 0.08, 0.09, 0.67)
    brake_zone.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    brake_zone.position = Vector2(22, -430)
    brake_zone.size = Vector2(92, 250)
    brake_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(brake_zone)
    brake_fill = ColorRect.new()
    brake_fill.color = Color(0.72, 0.20, 0.18, 0.72)
    brake_fill.position = Vector2(8, 242)
    brake_fill.size = Vector2(76, 0)
    brake_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    brake_zone.add_child(brake_fill)
    var btxt := _label("BREMSE", 14, Color.WHITE)
    btxt.position = Vector2(4, 105)
    btxt.size = Vector2(84, 32)
    btxt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    btxt.mouse_filter = Control.MOUSE_FILTER_IGNORE
    brake_zone.add_child(btxt)

    gas_zone = ColorRect.new()
    gas_zone.color = Color(0.08, 0.08, 0.09, 0.67)
    gas_zone.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    gas_zone.position = Vector2(-114, -430)
    gas_zone.size = Vector2(92, 250)
    gas_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(gas_zone)
    gas_fill = ColorRect.new()
    gas_fill.color = Color(0.20, 0.65, 0.30, 0.72)
    gas_fill.position = Vector2(8, 242)
    gas_fill.size = Vector2(76, 0)
    gas_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gas_zone.add_child(gas_fill)
    var gtxt := _label("GAS", 14, Color.WHITE)
    gtxt.position = Vector2(4, 105)
    gtxt.size = Vector2(84, 32)
    gtxt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gtxt.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gas_zone.add_child(gtxt)

func _label(text_value: String, font_size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text_value
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    return l

func reset_race() -> void:
    player_speed = 0.0
    player_distance = 0.0
    player_rpm = IDLE_RPM
    player_gear = 1
    player_shift_timer = 0.0
    player_slip = 0.0
    player_launched = false
    opponent_speed = 0.0
    opponent_distance = 0.0
    opponent_rpm = IDLE_RPM
    opponent_gear = 1
    opponent_shift_timer = 0.0
    opponent_launched = false
    opponent_reaction = 0.18 + rng.randf_range(0.02, 0.09)
    opponent_launch_delay_after_player = 0.0
    throttle = 0.0
    brake = 0.0
    gas_touch_id = -1
    brake_touch_id = -1
    stage_progress = 0.0
    prestaged = false
    staged = false
    state = "STAGING"
    staged_brake_time = 0.0
    tree_time = 0.0
    green_time = -1.0
    race_clock = 0.0
    reaction_time = -1.0
    red_light = false
    finish_time = -1.0
    zero_to_100 = -1.0
    hundred_to_200 = -1.0
    time_at_100 = -1.0
    trap_speed = 0.0
    camera_kick = 0.0
    if player_car:
        player_car.position = Vector3(-2.35, 0.45, -0.25)
        player_car.rotation = Vector3.ZERO
    if opponent_car:
        opponent_car.position = Vector3(2.35, 0.45, -0.9)
        opponent_car.rotation = Vector3.ZERO
    if result_panel:
        result_panel.visible = false
    _set_tree_all_off()

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key_event := event as InputEventKey
        if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_R:
            reset_race()
            return
    var size := get_viewport().get_visible_rect().size
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if _is_gas_zone(touch.position, size) and gas_touch_id == -1:
                gas_touch_id = touch.index
                throttle = _gas_value_from_y(touch.position.y, size.y)
            elif _is_brake_zone(touch.position, size) and brake_touch_id == -1:
                brake_touch_id = touch.index
                brake = 1.0
        else:
            if touch.index == gas_touch_id:
                gas_touch_id = -1
                throttle = 0.0
            if touch.index == brake_touch_id:
                brake_touch_id = -1
                brake = 0.0
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == gas_touch_id:
            throttle = _gas_value_from_y(drag.position.y, size.y)
        elif drag.index == brake_touch_id:
            brake = clamp(1.0 - ((drag.position.y - size.y * 0.43) / (size.y * 0.42)), 0.15, 1.0)

func _is_gas_zone(pos: Vector2, size: Vector2) -> bool:
    return pos.x >= size.x * 0.80 and pos.y >= size.y * 0.38

func _is_brake_zone(pos: Vector2, size: Vector2) -> bool:
    return pos.x <= size.x * 0.20 and pos.y >= size.y * 0.38

func _gas_value_from_y(y: float, height: float) -> float:
    var top := height * 0.43
    var bottom := height * 0.92
    return clamp((bottom - y) / (bottom - top), 0.06, 1.0)

func _physics_process(delta: float) -> void:
    var view_size := get_viewport().get_visible_rect().size
    var portrait := view_size.y > view_size.x
    rotate_label.visible = portrait
    if portrait:
        return

    if gas_touch_id == -1:
        throttle = 1.0 if (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) else 0.0
    if brake_touch_id == -1:
        brake = 1.0 if (Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) else 0.0

    match state:
        "STAGING":
            _update_staging(delta)
        "TREE":
            _update_tree(delta)
        "RACING":
            _update_race(delta)
        "FINISHED":
            pass

    _update_free_rev(delta)
    _update_camera(delta)
    _update_ui()

func _update_staging(delta: float) -> void:
    if brake < 0.2 and throttle > 0.04:
        var creep_speed := lerp(0.05, 0.34, throttle)
        stage_progress += creep_speed * delta
    if brake > 0.25:
        stage_progress -= min(stage_progress, 0.015 * delta)
    stage_progress = clamp(stage_progress, 0.0, 0.66)
    prestaged = stage_progress >= 0.22
    staged = stage_progress >= 0.48 and stage_progress <= 0.64
    player_car.position.z = -0.25 - stage_progress

    if staged and brake > 0.72:
        staged_brake_time += delta
        if staged_brake_time > 0.42:
            state = "TREE"
            tree_time = 0.0
    else:
        staged_brake_time = 0.0

func _update_tree(delta: float) -> void:
    tree_time += delta
    if not player_launched and brake < 0.28 and tree_time < 2.30:
        red_light = true
        reaction_time = -max(0.001, 2.30 - tree_time)
        opponent_launch_delay_after_player = max(0.0, 2.30 - tree_time) + opponent_reaction
        _launch_player()
        state = "RACING"
        race_clock = 0.0
        return

    if tree_time >= 2.30 and green_time < 0.0:
        green_time = tree_time
    if green_time >= 0.0:
        if not opponent_launched and tree_time - green_time >= opponent_reaction:
            opponent_launched = true
        if opponent_launched:
            _simulate_opponent(delta)
        if not player_launched and brake < 0.28:
            reaction_time = tree_time - green_time
            opponent_launch_delay_after_player = max(0.0, opponent_reaction - reaction_time)
            _launch_player()
            state = "RACING"
            race_clock = 0.0

func _launch_player() -> void:
    player_launched = true
    player_distance = 0.0
    player_car.position.z = -0.9
    opponent_car.position.z = -0.9

func _update_race(delta: float) -> void:
    race_clock += delta
    if not opponent_launched and race_clock >= opponent_launch_delay_after_player:
        opponent_launched = true

    _simulate_player(delta)
    if opponent_launched:
        _simulate_opponent(delta)

    if player_speed * 3.6 >= 100.0 and zero_to_100 < 0.0:
        zero_to_100 = race_clock
        time_at_100 = race_clock
    if player_speed * 3.6 >= 200.0 and hundred_to_200 < 0.0 and time_at_100 >= 0.0:
        hundred_to_200 = race_clock - time_at_100

    if player_distance >= MILE_QUARTER and finish_time < 0.0:
        finish_time = race_clock
        trap_speed = player_speed * 3.6
        state = "FINISHED"
        _show_results()

func _simulate_player(delta: float) -> void:
    var result := _vehicle_step(player_speed, player_rpm, player_gear, player_shift_timer, throttle, brake, delta, true)
    player_speed = result.speed
    player_rpm = result.rpm
    if result.gear != player_gear:
        camera_kick = 1.0
    player_gear = result.gear
    player_shift_timer = result.shift_timer
    player_slip = result.slip
    player_distance += player_speed * delta

    var wiggle := 0.0
    if player_speed < 27.78 and player_slip > 0.02:
        var fade := 1.0 - player_speed / 27.78
        wiggle = sin(Time.get_ticks_msec() * 0.035) * min(player_slip * 0.12, 0.24) * fade
    player_car.position.x = -2.35 + wiggle
    player_car.position.z = -0.9 - player_distance
    player_car.rotation.y = -wiggle * 0.18

func _simulate_opponent(delta: float) -> void:
    var opp_throttle := 0.82 if opponent_speed < 9.0 else (0.94 if opponent_speed < 24.0 else 1.0)
    var result := _vehicle_step(opponent_speed, opponent_rpm, opponent_gear, opponent_shift_timer, opp_throttle, 0.0, delta, false)
    opponent_speed = result.speed * 0.999
    opponent_rpm = result.rpm
    opponent_gear = result.gear
    opponent_shift_timer = result.shift_timer
    opponent_distance += opponent_speed * delta
    opponent_car.position.x = 2.35
    opponent_car.position.z = -0.9 - opponent_distance

func _vehicle_step(speed: float, rpm: float, gear: int, shift_timer: float, gas: float, brake_value: float, delta: float, is_player: bool) -> Dictionary:
    var current_gear := gear
    var current_shift := max(0.0, shift_timer - delta)
    var ratio: float = GEAR_RATIOS[current_gear - 1]
    var wheel_rpm := speed / (TAU * WHEEL_RADIUS_M) * 60.0
    var locked_rpm := wheel_rpm * ratio * FINAL_DRIVE

    var converter_rpm := IDLE_RPM + gas * 3000.0
    var target_rpm := max(IDLE_RPM, locked_rpm)
    if speed < 8.0:
        target_rpm = max(target_rpm, converter_rpm * (1.0 - clamp(speed / 9.0, 0.0, 1.0) * 0.62))
    rpm = move_toward(rpm, target_rpm, delta * (6800.0 if gas > 0.15 else 3800.0))
    rpm = clamp(rpm, IDLE_RPM, REDLINE_RPM)

    if current_shift <= 0.0 and rpm >= SHIFT_RPM and current_gear < 10:
        current_gear += 1
        current_shift = 0.125 if is_player else 0.115
        ratio = GEAR_RATIOS[current_gear - 1]
        wheel_rpm = speed / (TAU * WHEEL_RADIUS_M) * 60.0
        rpm = max(IDLE_RPM, wheel_rpm * ratio * FINAL_DRIVE)

    var torque := _engine_torque(rpm) * gas
    var wheel_force := torque * ratio * FINAL_DRIVE * DRIVETRAIN_EFF / WHEEL_RADIUS_M
    if current_shift > 0.0:
        wheel_force *= 0.12

    # Effective rear-axle grip includes weight transfer. RPM/throttle directly determine whether demand exceeds it.
    var rear_load_fraction := 0.61 + 0.055 * gas * clamp(1.0 - speed / 28.0, 0.0, 1.0)
    var grip_mu := 1.03
    var traction_limit := MASS_KG * 9.81 * rear_load_fraction * grip_mu
    var slip := max(0.0, (wheel_force - traction_limit) / max(traction_limit, 1.0))
    var drive_force := wheel_force
    if slip > 0.0:
        drive_force = traction_limit * (1.0 - min(slip * 0.075, 0.13))
        rpm = min(REDLINE_RPM, rpm + slip * 950.0)

    var aero_drag := 0.5 * 1.225 * 0.74 * speed * speed
    var rolling := 210.0 + speed * 3.0
    var brake_force := brake_value * 15500.0
    var accel := (drive_force - aero_drag - rolling - brake_force) / MASS_KG
    speed = max(0.0, speed + accel * delta)

    return {
        "speed": speed,
        "rpm": rpm,
        "gear": current_gear,
        "shift_timer": current_shift,
        "slip": slip
    }

func _engine_torque(rpm: float) -> float:
    # Tuned for the requested character: strongest from ~3000 to ~7300 rpm, taper to 8200.
    if rpm < 1500.0:
        return lerp(280.0, 390.0, (rpm - 850.0) / 650.0)
    if rpm < 3000.0:
        return lerp(390.0, 525.0, (rpm - 1500.0) / 1500.0)
    if rpm < 4800.0:
        return lerp(525.0, 570.0, (rpm - 3000.0) / 1800.0)
    if rpm < 6500.0:
        return lerp(570.0, 548.0, (rpm - 4800.0) / 1700.0)
    if rpm < 7300.0:
        return lerp(548.0, 515.0, (rpm - 6500.0) / 800.0)
    return lerp(515.0, 420.0, clamp((rpm - 7300.0) / 900.0, 0.0, 1.0))

func _update_free_rev(delta: float) -> void:
    if state == "STAGING" or state == "TREE":
        var target := IDLE_RPM + throttle * 3300.0
        if staged and brake > 0.6:
            target = IDLE_RPM + throttle * 3500.0
        player_rpm = move_toward(player_rpm, target, delta * 5200.0)
        player_rpm = clamp(player_rpm, IDLE_RPM, 4600.0)

func _update_camera(delta: float) -> void:
    var focus_z := player_car.position.z
    var speed_kmh := player_speed * 3.6
    var dynamic_back := lerp(7.8, 10.6, clamp(speed_kmh / 220.0, 0.0, 1.0))
    var target_pos := Vector3(-4.15, 3.15, focus_z + dynamic_back)
    if camera_kick > 0.0:
        camera_kick = max(0.0, camera_kick - delta * 7.0)
        target_pos.z += camera_kick * 0.28
    camera.position = camera.position.lerp(target_pos, min(1.0, delta * 7.0))
    var target := Vector3(0.25, 0.62, focus_z - 15.5)
    camera.look_at(target, Vector3.UP)
    camera.fov = lerp(camera.fov, 68.0 + clamp(speed_kmh / 250.0, 0.0, 1.0) * 7.0, min(1.0, delta * 3.5))

func _update_ui() -> void:
    var speed_kmh := player_speed * 3.6
    speed_label.text = "%d\nkm/h" % roundi(speed_kmh)
    gear_label.text = str(player_gear) if state == "RACING" or player_launched else "D"
    rpm_label.text = "%d RPM" % roundi(player_rpm)
    rpm_bar.value = player_rpm
    distance_label.text = "%d / 402 m" % mini(roundi(player_distance), 402)
    if reaction_time >= 0.0:
        reaction_label.text = "RT %.3f" % reaction_time
    elif reaction_time < 0.0 and red_light:
        reaction_label.text = "RT %.3f RED" % reaction_time
    else:
        reaction_label.text = "RT ---.---"

    var gas_h := 234.0 * throttle
    gas_fill.position.y = 242.0 - gas_h
    gas_fill.size.y = gas_h
    var brake_h := 234.0 * brake
    brake_fill.position.y = 242.0 - brake_h
    brake_fill.size.y = brake_h

    match state:
        "STAGING":
            if not prestaged:
                status_label.text = "STAGING\nGas leicht antippen und zur Linie rollen"
            elif not staged:
                status_label.text = "PRE-STAGE ✓\nNoch ein kleines Stück vor"
            else:
                status_label.text = "STAGE ✓\nBremse halten – Drehzahl mit Gas setzen"
        "TREE":
            status_label.text = "BREMSE HALTEN · TREE LESEN"
        "RACING":
            status_label.text = "WHEELSPIN %.0f%%" % (player_slip * 100.0) if player_slip > 0.03 else "GRIP ✓"
        "FINISHED":
            status_label.text = "ZIEL"
    _update_tree_visuals()

func _set_tree_all_off() -> void:
    for l in tree_lights:
        l.add_theme_color_override("font_color", Color("34373a"))

func _update_tree_visuals() -> void:
    _set_tree_all_off()
    if prestaged or state != "STAGING":
        tree_lights[0].add_theme_color_override("font_color", Color("f2f2e8"))
    if staged or state != "STAGING":
        tree_lights[1].add_theme_color_override("font_color", Color("f2f2e8"))
    if state == "TREE" or state == "RACING" or state == "FINISHED":
        if tree_time >= 0.80 or state != "TREE":
            tree_lights[2].add_theme_color_override("font_color", Color("efb735"))
        if tree_time >= 1.30 or state != "TREE":
            tree_lights[3].add_theme_color_override("font_color", Color("efb735"))
        if tree_time >= 1.80 or state != "TREE":
            tree_lights[4].add_theme_color_override("font_color", Color("efb735"))
        if tree_time >= 2.30 or state == "RACING" or state == "FINISHED":
            tree_lights[5].add_theme_color_override("font_color", Color("39cc66"))
    if red_light:
        tree_lights[6].add_theme_color_override("font_color", Color("ed3f3f"))
        tree_lights[5].add_theme_color_override("font_color", Color("34373a"))

func _show_results() -> void:
    var rt_text := "RED LIGHT" if red_light else "%.3f s" % max(reaction_time, 0.0)
    var zero100_text := "--" if zero_to_100 < 0.0 else "%.2f s" % zero_to_100
    var one_to_two_text := "--" if hundred_to_200 < 0.0 else "%.2f s" % hundred_to_200
    var winner := "GEWONNEN" if player_distance >= opponent_distance and not red_light else "VERLOREN"
    result_label.text = "%s\n\nReaktion: %s\n0–100 km/h: %s\n100–200 km/h: %s\n1/4 Mile ET: %.3f s\nTrap Speed: %.1f km/h\n\nPrototyp v0.1" % [winner, rt_text, zero100_text, one_to_two_text, finish_time, trap_speed]
    result_panel.visible = true
