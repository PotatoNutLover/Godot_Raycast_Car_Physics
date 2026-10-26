extends Node3D
@onready var current_car: Car = %Car
@onready var current_car_engine: CarEngine = $Car/CarEngine
@onready var ui: UILayer = %UICanvas
@onready var camera_pivot: Node3D = %CameraPivot

func _ready() -> void:
	ui.update_engine_gear_info(current_car_engine.get_gear_label())
	current_car_engine.connect("gear_changed", on_gear_changed)

func _process(delta: float) -> void:
	ui.update_engine_rpm_info(current_car_engine.current_rpm)
	
func _physics_process(delta: float) -> void:
	var steer_input: float = Input.get_axis("ui_right", "ui_left")
	camera_pivot.global_position = current_car.global_position
	var camera_target_rot = current_car.global_rotation.y 
	if abs(steer_input) > 0.0:
		camera_target_rot = current_car.global_rotation.y - steer_input * 0.02
	camera_pivot.global_rotation.y = lerp_angle(camera_pivot.global_rotation.y, camera_target_rot, 4 * delta)
	if (Input.is_action_pressed("camera_mode")):
		camera_pivot.global_rotation.y = current_car.global_rotation.y - 1.5
		
	
	
func on_gear_changed() -> void:
	ui.update_engine_gear_info(current_car_engine.get_gear_label())
	

	
