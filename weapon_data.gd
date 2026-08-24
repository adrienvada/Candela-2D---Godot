extends Resource
class_name WeaponData

const Charte := preload("res://charte.gd")

@export var name: String = "Pistolet"
@export var cooldown: float = 1.0
@export var bullet_speed: float = 12000.0
@export var bullet_max_distance: float = 10000.0
@export var damage_center: float = 50.0
@export var damage_edge: float = 25.0
@export var max_bounces: int = 0
@export var damages_shooter: bool = false
@export var projectile_count: int = 1
@export var spread_angles_deg: Array[float] = [0.0]
@export var emits_light: bool = true

@export_group("Flashlight")
@export var torch_angle_deg: float = 30.0
@export var torch_scale: float = 2.3
@export var torch_brightness: float = 1.0

@export_group("Visibility & Mobility")
@export var muzzle_flash_intensity: float = 1.0
@export var muzzle_flash_duration: float = 0.1
@export var backlight_multiplier: float = 1.0
@export var movement_speed_while_reloading: float = 1.0
@export var can_run_while_reloading: bool = true

@export_group("Projectile Visuals")
@export var bullet_color: Color = Charte.AMBRE_INCANDESCENT
@export var bullet_light_energy: float = 50.0
@export var bullet_width: float = 5.0

var _torch_texture: ImageTexture

func get_torch_texture() -> ImageTexture:
	if _torch_texture != null:
		return _torch_texture
		
	var tex_size = 512
	var img = Image.create_empty(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var center = Vector2(tex_size / 2.0, tex_size / 2.0)
	var max_dist = tex_size / 2.0
	var cone_angle = deg_to_rad(torch_angle_deg)
	
	for y in range(tex_size):
		for x in range(tex_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist >= max_dist:
				continue
				
			var dir = center.direction_to(pos)
			var angle = abs(dir.angle())
			var intensity = 0.0
			
			if angle <= cone_angle:
				var beam_intensity = 1.0 - (dist / max_dist)
				var angle_fade = clamp((cone_angle - angle) * 8.0, 0.0, 1.0)
				intensity = max(intensity, beam_intensity * angle_fade)
				
			var halo_angle = deg_to_rad(80.0)
			if angle <= halo_angle:
				var halo_dist = max_dist * 0.2
				if dist < halo_dist:
					var halo_intensity = pow(1.0 - (dist / halo_dist), 2.5) * 0.15
					var angle_fade = clamp((halo_angle - angle) * 4.0, 0.0, 1.0)
					intensity = max(intensity, halo_intensity * angle_fade)
				
			if intensity > 0:
				img.set_pixel(x, y, Color(Charte.HALOGENE, intensity * torch_brightness))
	
	_torch_texture = ImageTexture.create_from_image(img)
	return _torch_texture

var _torch_texture_flat: ImageTexture

func get_torch_texture_flat() -> ImageTexture:
	if _torch_texture_flat != null:
		return _torch_texture_flat
		
	var tex_size = 512
	var img = Image.create_empty(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var center = Vector2(tex_size / 2.0, tex_size / 2.0)
	var max_dist = tex_size / 2.0
	var cone_angle = deg_to_rad(torch_angle_deg)
	
	for y in range(tex_size):
		for x in range(tex_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist >= max_dist:
				continue
				
			var dir = center.direction_to(pos)
			var angle = abs(dir.angle())
			var intensity = 0.0
			
			if angle <= cone_angle:
				# Solid light, but with a slight diffuse edge to prevent harsh pixelated steps
				var angle_fade = clamp((cone_angle - angle) * 16.0, 0.0, 1.0)
				var dist_fade = clamp((max_dist - dist) / 25.0, 0.0, 1.0)
				intensity = angle_fade * dist_fade
				
			var halo_angle = deg_to_rad(80.0)
			if angle <= halo_angle:
				var halo_dist = max_dist * 0.2
				if dist < halo_dist:
					var halo_angle_fade = clamp((halo_angle - angle) * 8.0, 0.0, 1.0)
					var halo_dist_fade = clamp((halo_dist - dist) / 15.0, 0.0, 1.0)
					intensity = max(intensity, halo_angle_fade * halo_dist_fade)
				
			if intensity > 0:
				img.set_pixel(x, y, Color(Charte.HALOGENE, intensity * torch_brightness))
	
	_torch_texture_flat = ImageTexture.create_from_image(img)
	return _torch_texture_flat
