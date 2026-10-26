class_name Car
extends RigidBody3D

@export var suspension_rest_dist: float = 0.55
@export var spring_strength: float = 42000.0
@export var spring_damping: float = 4800.0
@export var wheel_radius: float = 0.35

#@export var engine_power: float = 18000.0
@export var brake_power: float = 12000.0
@export var max_steer_angle: float = 32.0
@export var steer_speed: float = 6.0

@export var front_tire_grip: float = 4.5
@export var rear_tire_grip: float = 3.8
@export var drift_grip_multiplier: float = 0.45
@export var slip_thereshold: float = 6.0

@onready var wheels: Array[Node] = %Wheels.get_children()
@onready var engine_node: CarEngine = %CarEngine

var current_steer: float = 0.0
var last_rear_wheel_vel: float = 0.0
var rear_wheels_grounded: bool = false
var free_wheel_vel: float = 0.0

func _ready() -> void:
	for ray in wheels:
		if ray is RayCast3D:
			ray.add_exception(self)
			ray.target_position = Vector3(0, -(suspension_rest_dist+wheel_radius), 0)

func _physics_process(delta: float) -> void:
	var throttle_input: float = Input.get_action_strength("ui_up")
	var brake_input: float = Input.get_action_strength("ui_down")
	var steer_input: float = Input.get_axis("ui_right", "ui_left")
	var handbrake: bool = Input.is_action_pressed("ui_accept")
	
	var total_drive_force: float = engine_node.calculate_drive_force(
		throttle_input,
		last_rear_wheel_vel,
		wheel_radius,
		rear_wheels_grounded,
		delta
	)
	
	
	var speed: float = linear_velocity.length()
	var speed_factor: float = clamp(1.0 - (speed / 45.0) * 0.6, 0.35, 1.0)
	var target_steer: float = steer_input * deg_to_rad(max_steer_angle) * speed_factor
	current_steer = move_toward(current_steer, target_steer, steer_speed * delta)
	
	var rear_vel_sum: float = 0.0
	var grounded_rear_count: int = 0
	
	for ray in wheels: 
		if not ray is RayCast3D:
			continue
		var current_ray: RayCast3D = ray
		var is_front: bool = current_ray.name.contains("FL") or current_ray.name.contains("FR")
		
		if is_front:
			current_ray.rotation.y = current_steer
			
		current_ray.force_raycast_update()
		
		if current_ray.is_colliding():
			var contact_point: Vector3 = current_ray.get_collision_point()
			var contact_normal: Vector3 = current_ray.get_collision_normal()
			var spring_up_dir: Vector3 = current_ray.global_basis.y
			
			var force_pos_offset: Vector3 = current_ray.global_position - global_position
			var tire_force_offset: Vector3 = contact_point - global_position + spring_up_dir * 0.25
			
			var tire_vel: Vector3 = _get_point_velocity(current_ray.global_position)
			
			var ray_dist: float = current_ray.global_position.distance_to(contact_point)
			var compression: float = (suspension_rest_dist + wheel_radius) - ray_dist
			compression = clamp(compression, 0.0, suspension_rest_dist)
			
			var spring_vel: float = spring_up_dir.dot(tire_vel)
			var spring_force: float = (compression * spring_strength) - (spring_vel * spring_damping)
			spring_force = max(0.0, spring_force)
			
			apply_force(contact_normal * spring_force, force_pos_offset)
			
			var forward_dir: Vector3 = -current_ray.global_basis.z
			var forward_vel: float = forward_dir.dot(tire_vel)
			
			if not is_front:
				rear_vel_sum += forward_vel
				grounded_rear_count += 1
			
			var drive_share: float = 0.175 if is_front else 0.325
			apply_force(forward_dir * (total_drive_force * drive_share), tire_force_offset)
			
			if brake_input > 0.0:
				var brake_dir: float = -sign(forward_vel) if abs(forward_vel) > 0.05 else 0.0
				apply_force(forward_dir * (brake_dir * brake_input * brake_power), tire_force_offset)
			
			var right_dir: Vector3 = current_ray.global_basis.x
			var lateral_vel: float = right_dir.dot(tire_vel)
			
			var grip: float = front_tire_grip if is_front else rear_tire_grip
			
			if not is_front:
				if handbrake:
					grip *= drift_grip_multiplier * 0.5
				elif abs(lateral_vel) > slip_thereshold:
					grip *= lerpf(1.0, drift_grip_multiplier, clamp((abs(lateral_vel) - slip_thereshold) / 8.0, 0.0, 1.0))
			
			var desired_accel: float = -lateral_vel * grip
			var tire_load_mass: float = mass * 0.25
			var lateral_force: Vector3 = right_dir * (tire_load_mass * desired_accel)
			
			apply_force(lateral_force, tire_force_offset)
			
			_update_wheel_visual(current_ray, ray_dist - wheel_radius, forward_vel, delta)
		else:
			#_update_wheel_visual(current_ray, suspension_rest_dist, 0.0, delta)
			if throttle_input > 0.0:
				free_wheel_vel = clamp(free_wheel_vel + total_drive_force * 0.00005, -100.0, 100.0)
			else:
				free_wheel_vel = lerpf(free_wheel_vel, 0.0, ease(30 * delta, 5))
				last_rear_wheel_vel = max(0.0, lerpf(last_rear_wheel_vel, 0.0, ease(30 * delta, 5)))
				
			#print(free_wheel_vel)
			_update_wheel_visual(current_ray, suspension_rest_dist, last_rear_wheel_vel + free_wheel_vel, delta)
			
			
	rear_wheels_grounded = grounded_rear_count > 0
	if rear_wheels_grounded:
		last_rear_wheel_vel = rear_vel_sum / float(grounded_rear_count)
	
			
			
func _get_point_velocity(point_global_pos: Vector3) -> Vector3:
	var r: Vector3 = point_global_pos - (global_position + global_basis * center_of_mass)
	return linear_velocity + angular_velocity.cross(r)
	
	
func _update_wheel_visual(ray: RayCast3D, suspension_offset: float, forward_vel: float, delta: float) -> void:
	if ray.get_child_count() == 0:
		return
	var wheel_mesh: Node3D = ray.get_child(0)
	wheel_mesh.position.y = move_toward(wheel_mesh.position.y, -suspension_offset, 5.0 * delta)
	wheel_mesh.rotate_x(-forward_vel / wheel_radius * delta)
	
	
	
	
	
	
	
	
	
	
	
