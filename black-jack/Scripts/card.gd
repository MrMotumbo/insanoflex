extends Node2D
class_name Card

var suit: String
var rank: String
var value: int
var is_face_up: bool = true

@onready var sprite: Sprite2D = $Sprite2D
var face_texture: Texture2D
var back_texture: Texture2D = preload("res://Sprites/Cards/Card Back + Ship.png")

# Notice we added 'p_face_up' to the end of this function
func setup_card(p_suit: String, p_rank: String, p_value: int, p_texture: Texture2D, p_face_up: bool = true):
	suit = p_suit
	rank = p_rank
	value = p_value
	face_texture = p_texture
	is_face_up = p_face_up
	update_visuals()

func update_visuals():
	if is_face_up:
		sprite.texture = face_texture
	else:
		sprite.texture = back_texture

func flip():
	is_face_up = !is_face_up
	update_visuals()
