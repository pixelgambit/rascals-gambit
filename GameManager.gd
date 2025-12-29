extends Node2D

# Player Stats
var health: int = 20
var weapon_power: int = 0
var last_monster_slain: int = 99

# Game State
var can_run_away: bool = true
var potions_used_this_room: int = 0
var cards_interacted_this_room: int = 0
var room_active: bool = false
var is_dealing: bool = false # Prevents clicking deck while dealing

# Layout Constants
const DECK_POS = Vector2(230, 380)
const FIRST_CARD_X = 510
const CARD_SPACING = 180
const CARD_Y = 380
const DEAL_SPEED = 0.1 # Delay between cards in seconds

# Deck Data
var deck = []
var discard_pile = []

# Node References
@onready var room_container = $RoomContainer
@onready var hp_label = $UI/HPLabel 
@onready var wp_label = $UI/WPLabel
@onready var draw_label = $UI/DrawLabel
@onready var discard_label = $UI/DiscardLabel
@onready var game_over_screen = $UI/GameOverScreen
@onready var retry_button = $UI/GameOverScreen/RetryButton

func _ready():
	build_official_deck()
	deck.shuffle()
	update_ui()
	setup_initial_deck_visual()
	game_over_screen.visible = false
	retry_button.modulate.a = 0.0 

func build_official_deck():
	deck.clear()
	discard_pile.clear()
	var suits = ["clubs", "spades", "diamonds", "hearts"]
	var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace"]
	
	for s in suits:
		for r in ranks:
			if (s == "hearts" or s == "diamonds") and (r in ["jack", "queen", "king", "ace"]):
				continue
			deck.append({"rank": r, "suit": s})

func setup_initial_deck_visual():
	var deck_visual = preload("res://card.tscn").instantiate()
	deck_visual.is_face_up = false 
	deck_visual.name = "DeckVisual"
	add_child(deck_visual)
	deck_visual.position = DECK_POS
	deck_visual.card_clicked.connect(_on_deck_clicked)

func _on_deck_clicked(_node):
	if not room_active and not is_dealing and deck.size() > 0:
		draw_room()

func draw_room():
	is_dealing = true
	room_active = true
	potions_used_this_room = 0
	cards_interacted_this_room = 0
	
	var existing_cards = room_container.get_children()
	var cards_needed = 4 - existing_cards.size()
	
	for i in range(cards_needed):
		if deck.size() > 0:
			# Wait for sequential deal effect
			await get_tree().create_timer(DEAL_SPEED).timeout
			
			var card_data = deck.pop_front()
			var card_node = preload("res://card.tscn").instantiate()
			card_node.rank = card_data.rank
			card_node.suit = card_data.suit
			card_node.is_face_up = true 
			card_node.card_clicked.connect(_on_card_selected)
			room_container.add_child(card_node)
			
			var slot_index = i + existing_cards.size()
			card_node.position = Vector2(FIRST_CARD_X + (slot_index * CARD_SPACING), CARD_Y)
			update_ui()
	
	is_dealing = false

func update_ui():
	hp_label.text = "HP: " + str(max(0, health)).pad_zeros(2)
	wp_label.text = "WP: " + str(weapon_power).pad_zeros(2)
	if draw_label: draw_label.text = str(deck.size()).pad_zeros(2)
	if discard_label: discard_label.text = str(discard_pile.size()).pad_zeros(2)

func _on_card_selected(card):
	if health <= 0 or is_dealing: return
	
	var type = card.get_card_type()
	var val = card.get_card_value()
	
	match type:
		"potion":
			if potions_used_this_room == 0:
				health = clampi(health + val, 0, 20)
				potions_used_this_room += 1
		"weapon":
			weapon_power = val
			last_monster_slain = 99
		"monster":
			var damage = val
			if weapon_power > 0 and val < last_monster_slain:
				damage = max(0, val - weapon_power)
				last_monster_slain = val
			health -= damage

	cards_interacted_this_room += 1
	discard_pile.append({"rank": card.rank, "suit": card.suit})
	card.queue_free()
	update_ui()
	
	if health <= 0:
		trigger_game_over()
		return

	if cards_interacted_this_room >= 3:
		room_active = false
		can_run_away = true 

func trigger_game_over():
	game_over_screen.visible = true
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(retry_button, "modulate:a", 1.0, 1.0)

func _on_retry_button_pressed():
	get_tree().reload_current_scene()
