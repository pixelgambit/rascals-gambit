extends Area2D

signal card_clicked(card_node)

@export var rank: String = "ace"
@export var suit: String = "hearts"
@export var is_face_up: bool = false

@onready var sprite = $CardSprite
var back = preload("res://cards/card_back_1.png")

func _ready():
	update_visual()

func update_visual():
	if is_face_up:
		var path = "res://cards/" + rank + "_of_" + suit + ".png"
		sprite.texture = load(path)
	else:
		sprite.texture = back

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		# Just emit the signal. GameManager will decide if it flips or deals.
		card_clicked.emit(self)

func get_card_value() -> int:
	match rank:
		"ace": return 14
		"jack": return 11
		"queen": return 12
		"king": return 13
		_: return rank.to_int()

func get_card_type() -> String:
	match suit:
		"spades", "clubs": return "monster"
		"hearts": return "potion"
		"diamonds": return "weapon"
		_: return "unknown"
