extends Node2D

# Player Stats
var health: int = 20
var weapon_power: int = 0
var last_monster_slain: int = 99

# Game State
var room_active: bool = false
var is_dealing: bool = false 
var game_over: bool = false 
var can_escape: bool = true # From Knowledge: No back-to-back escapes
var cards_interacted_this_room: int = 0 
var potions_used_this_room: int = 0 
var dungeon_level: int = 0 

# Layout Constants
const DECK_POS = Vector2(230, 380)
const FIRST_CARD_X = 510
const CARD_SPACING = 180
const CARD_Y = 380
const DEAL_SPEED = 0.1 

# Deck Data
var deck = []

@onready var room_container = $RoomContainer

# Scene Tree Paths
@onready var hp_label = $UI/HUDContainer/HPLabel 
@onready var wp_label = $UI/HUDContainer/WPLabel
@onready var room_label = $UI/HUDContainer/RoomLabel 
@onready var hud_container = $UI/HUDContainer
@onready var hud_bar = $UI/HUDBar

@onready var game_over_screen = $UI/GameOverScreen
@onready var retry_button = $UI/GameOverScreen/RetryButton

@onready var run_button = $UI/RunButton

func _ready():
	# UI CLICK FIX: Ensure HUD elements don't block clicks
	if hud_container:
		hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hud_bar:
		hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	# FORCE VISIBILITY: Ensures RoomLabel is on top of the green table
	if room_label:
		room_label.z_index = 10
		room_label.top_level = true 
		
	build_official_deck()
	deck.shuffle()
	setup_initial_deck_visual()
	
	if game_over_screen:
		game_over_screen.visible = false
		game_over_screen.modulate.a = 0 
	
	# Signal Connections
	retry_button.pressed.connect(_on_retry_button_pressed)
	run_button.pressed.connect(_on_run_away_pressed)
	
	update_ui()

func build_official_deck():
	deck.clear()
	var suits = ["clubs", "spades", "diamonds", "hearts"]
	var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace"]
	for s in suits:
		for r in ranks:
			# Filtered deck based on "Scoundrel" PDF rules
			if (s == "hearts" or s == "diamonds") and (r in ["jack", "queen", "king", "ace"]):
				continue
			deck.append({"rank": r, "suit": s})

func setup_initial_deck_visual():
	var deck_visual = preload("res://card.tscn").instantiate()
	deck_visual.is_face_up = false 
	add_child(deck_visual)
	deck_visual.position = DECK_POS
	deck_visual.card_clicked.connect(_on_deck_clicked)

func _on_deck_clicked(_node):
	if not room_active and not is_dealing and not game_over and deck.size() > 0:
		draw_room()

func draw_room():
	is_dealing = true
	room_active = true
	cards_interacted_this_room = 0 
	potions_used_this_room = 0 
	dungeon_level += 1 
	
	var active_cards = room_container.get_children()
	var occupied_slots = []
	for card in active_cards:
		var slot = round((card.position.x - FIRST_CARD_X) / CARD_SPACING)
		occupied_slots.append(int(slot))
	
	for i in range(4):
		if i not in occupied_slots and deck.size() > 0:
			await get_tree().create_timer(DEAL_SPEED).timeout 
			var card_data = deck.pop_front()
			var card_node = preload("res://card.tscn").instantiate()
			card_node.rank = card_data.rank
			card_node.suit = card_data.suit
			card_node.is_face_up = true 
			card_node.card_clicked.connect(_on_card_selected)
			room_container.add_child(card_node)
			card_node.position = Vector2(FIRST_CARD_X + (i * CARD_SPACING), CARD_Y)
	
	is_dealing = false
	update_ui()

func _on_card_selected(card):
	if game_over or is_dealing or cards_interacted_this_room >= 3:
		return
	
	# Knowledge Check: Interacting with a card allows escaping the NEXT room
	can_escape = true 
	
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
	card.queue_free()
	
	if health <= 0:
		health = 0
		game_over = true
		room_active = false
		show_game_over_with_fade() 
	
	elif cards_interacted_this_room >= 3:
		room_active = false 
	
	update_ui()

func _on_run_away_pressed():
	# Knowledge Check: Block if back-to-back escape
	if not can_escape or is_dealing or game_over or not room_active:
		return
	_execute_simplified_scoop()

func _execute_simplified_scoop():
	can_escape = false # Rule applied: Escape consumed
	room_active = false
	is_dealing = true 
	
	var cards = room_container.get_children()
	# Sort Right to Left based on position
	cards.sort_custom(func(a, b): return a.position.x > b.position.x)
	
	var center_point = Vector2(780, 380)
	var tween = create_tween().set_parallel(false)
	
	# Move to center
	for i in range(cards.size()):
		tween.tween_property(cards[i], "position", center_point, 0.2).set_delay(0.05)
	
	tween.tween_interval(0.1)
	
	# Flip over and move to bottom of deck
	for card in cards:
		var flip_tween = create_tween().set_parallel(true)
		flip_tween.tween_property(card, "scale:x", 0.0, 0.1)
		flip_tween.chain().tween_property(card, "scale:x", 1.0, 0.1)
		
		var bury_tween = create_tween().set_parallel(true)
		bury_tween.tween_property(card, "position", DECK_POS, 0.3)
		bury_tween.tween_property(card, "modulate:a", 0.0, 0.3)
		
		# Push to back of array (bottom of pile)
		deck.push_back({"rank": card.rank, "suit": card.suit})
	
	await tween.finished
	
	for card in cards:
		card.queue_free()
	
	is_dealing = false
	dungeon_level -= 1 
	update_ui()

func show_game_over_with_fade():
	if game_over_screen:
		game_over_screen.visible = true
		game_over_screen.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(game_over_screen, "modulate:a", 1.0, 1.0)

func update_ui():
	if hp_label: hp_label.text = "HP: " + str(health).pad_zeros(2)
	if wp_label: wp_label.text = "WP: " + str(weapon_power).pad_zeros(2)
	
	if room_label:
		room_label.text = "Dungeon " + str(dungeon_level) + " - Moves " + str(cards_interacted_this_room) + "/3"
		room_label.reset_size()
		await get_tree().process_frame
		
		var viewport_size = get_viewport_rect().size
		room_label.global_position.x = (viewport_size.x / 2.0) - (room_label.size.x / 2.0)
		room_label.global_position.y = viewport_size.y - 80 
	
	if run_button:
		# Run button logic constrained by Scoundrel rules
		run_button.visible = can_escape and not game_over and room_active

func _on_retry_button_pressed():
	get_tree().reload_current_scene()
