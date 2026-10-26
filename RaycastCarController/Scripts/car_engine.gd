class_name CarEngine
extends Node

@export_group("Engine Specs")
@export var idle_rpm: float = 1000.0
@export var max_rpm: float = 7000.0
@export var max_torque: float = 380.0
@export var engine_breaking: float = 90.0
@export var rpm_accel_smooth: float = 12.0
@export var torque_curve: Curve

@export_group("Gearbox Specs")
@export var gear_ratios: Array[float] = [-3.2, 0.0, 3.2, 2.1, 1.3, 0.9]
@export var final_drive: float = 4.8
@export var shift_duration: float = 0.15
@export var launch_rpm: float = 2800.0

signal gear_changed

var current_rpm: float = 1000.0
var current_gear: int = 2
var shift_timer: float = 0.0

func _ready() -> void:
	pass
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shift_up"):
		shift_up()
	elif event.is_action_pressed("shift_down"):
		shift_down()
		
func shift_up() -> void:
	if(current_gear < gear_ratios.size() - 1):
		current_gear += 1
		shift_timer = shift_duration
		gear_changed.emit()
	
func shift_down() -> void:
	if(current_gear > 0):
		current_gear -= 1
		shift_timer = shift_duration
		gear_changed.emit()
		
func calculate_drive_force(throttle: float, avg_wheel_vel: float, wheel_radius: float, is_grounded: bool, delta: float) -> float:
	if shift_timer > 0.0:
		shift_timer = max(0.0, shift_timer - delta)
		
	var gear_ratio: float = gear_ratios[current_gear]
	var total_ratio: float = gear_ratio * final_drive
	
	var wheel_angular_vel: float = avg_wheel_vel / max(wheel_radius, 0.05)
	var wheel_locked_rpm: float = abs(wheel_angular_vel * total_ratio) * (60.0 / TAU)
	
	var target_rpm: float = idle_rpm
	
	if is_equal_approx(gear_ratio, 0.0) or shift_timer > 0.0 or not is_grounded:
		target_rpm = lerpf(idle_rpm, max_rpm, throttle)
	else:
		var clutch_slip_rpm: float = lerpf(idle_rpm, launch_rpm, throttle)
		target_rpm = max(wheel_locked_rpm, clutch_slip_rpm)
		
	current_rpm = lerpf(current_rpm, target_rpm, rpm_accel_smooth * delta)
	current_rpm = clamp(current_rpm, idle_rpm, max_rpm)
	
	if is_equal_approx(gear_ratio, 0.0) or shift_timer > 0.0:
		return 0.0
		
	var rpm_factor: float = (current_rpm - idle_rpm) / (max_rpm - idle_rpm)
	var available_torque: float = torque_curve.sample_baked(clamp(rpm_factor, 0, 1.0)) * max_torque
	
	if wheel_locked_rpm >= max_rpm:
		available_torque = 0.0
	
	var net_engine_torque: float = 0.0
	if throttle > 0.05:
		net_engine_torque = available_torque * throttle
	else:
		var move_dir_sign: float = sign(avg_wheel_vel * gear_ratio)
		if move_dir_sign > 0.0:
			net_engine_torque = -engine_breaking * rpm_factor * sign(gear_ratio)
			
	return (net_engine_torque * total_ratio) / max(wheel_radius, 0.05)
	
func get_gear_label() -> String:
	if current_gear == 0:
		return 'R'
	elif current_gear == 1:
		return 'N'
	return str(current_gear - 1)



















		
