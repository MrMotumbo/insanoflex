extends Node2D

# --- ASSETS & CONFIG ---
var card_scene: PackedScene = preload("res://Scenes/card.tscn")

var deck: Array = []
var player_hands: Array = [[]]
var dealer_hand: Array = []
var active_hand_index: int = 0
var player_money: int = 100
var current_bet: int = 5
var wager: int = 0
var game_started: bool = false
var original_change_label_pos: Vector2
var indicator_tween: Tween # Add this under your other variables
var music_playlist: Array = [
	preload("res://Audio/Music/Alex_Morgan_Jazz_1.mp3"),
	preload("res://Audio/Music/Alex_Morgan_Jazz_2.mp3"),
	preload("res://Audio/Music/Alex_Morgan_Jazz_3.mp3"),
	preload("res://Audio/Music/Alex_Morgan_Jazz_4.mp3")
]
var current_track_index: int = 0

# --- INITIALIZATION ---
func _ready():
	randomize()
	# UI Setup
	$UI_Layer/TitleScreen.show()
	$UI_Layer/PauseMenu.hide()
	$BetButton.hide()
	hide_gameplay_buttons()
	update_money_display()
	
	# Initialize toggles
	$UI_Layer/TitleScreen/MusicToggle.button_pressed = true
	$UI_Layer/PauseMenu/MusicToggle.button_pressed = true 
	
	$UI_Layer/TitleScreen/VolumeSlider.value = 1.0
	$UI_Layer/TitleScreen/SFXSlider.value = 1.0
	
	$BGMPlayer.finished.connect(_on_music_finished)
	current_track_index = randi() % music_playlist.size()
	_play_music()
	
	setup_indicator_animation()
	get_tree().paused = true
	original_change_label_pos = $MoneyChangeLabel.position

# --- CORE GAME FLOW ---
func start_game():
	game_started = true
	get_tree().paused = false
	$UI_Layer/TitleScreen.hide()
	$UI_Layer/PauseMenu.hide()
	
	reset_game_state()
	start_round()

func reset_game_state():
	clear_table()
	player_money = 100
	
	# Reset the betting variables to the starting amount
	current_bet = 5
	wager = current_bet
	
	player_hands = [[]]
	dealer_hand = []
	active_hand_index = 0
	
	build_deck()
	deck.shuffle()
	update_money_display()
	$BetButton.show()
	$BetButton.disabled = false
	show_betting_controls() # Ensure your buttons are visible again

# --- INPUT HANDLING ---
func _unhandled_input(event):
	if event.is_action_pressed("pause_game"):
		if game_started:
			toggle_pause(!$UI_Layer/PauseMenu.visible)

# --- GAME LOGIC ---
func build_deck():
	deck.clear()
	var suits = ["Hearts", "Diamonds", "Clubs", "Spades"]
	var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King", "Ace"]
	for suit in suits:
		for rank in ranks:
			var val = 10 if rank in ["Jack", "Queen", "King"] else (11 if rank == "Ace" else int(rank))
			deck.append({
				"suit": suit, "rank": rank, "value": val,
				"texture": load("res://Sprites/Cards/%s of %s.png" % [rank, suit])
			})

func deal_card(target_hand: Array, spawn_marker: Marker2D, is_face_up: bool):
	if deck.is_empty(): return null
	$CardSound.play()
	var card_data = deck.pop_back()
	target_hand.append(card_data)
	
	var new_card = card_scene.instantiate()
	add_child(new_card)
	new_card.setup_card(card_data.suit, card_data.rank, card_data.value, card_data.texture, is_face_up)
	new_card.global_position = $DeckSprite.global_position
	card_data["node"] = new_card
	
	update_hand_positions(target_hand, spawn_marker)
	return new_card

func calculate_score(hand: Array) -> int:
	var total = 0
	var aces = 0
	for card in hand:
		total += card.value
		if card.rank == "Ace": aces += 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total

func start_round():
	hide_betting_controls()
	clear_table()
	player_hands = [[]]
	dealer_hand = []
	active_hand_index = 0
	
	# Check if deck needs a shuffle
	if deck.size() < 15:
		$ShuffleLabel.show()
		$ShuffleLabel.text = "SHUFFLING DECK..."
		play_shuffle_animation() # Play the animation here!
		await get_tree().create_timer(1.0).timeout
		build_deck()
		deck.shuffle()
		$ShuffleLabel.hide()

	# Dealing sequence
	for i in range(2):
		deal_card(player_hands[0], $StartSpawnPos, true)
		await get_tree().create_timer(0.5).timeout
		deal_card(dealer_hand, $DealerSpawnPos, i == 1)
		await get_tree().create_timer(0.5).timeout

	if calculate_score(player_hands[0]) == 21:
		if dealer_hand[0].has("node"): dealer_hand[0]["node"].flip()
		end_round_logic()
	else:
		show_gameplay_buttons()

func end_round_logic():
	hide_gameplay_buttons()
	if dealer_hand.size() > 0 and dealer_hand[0].has("node") and not dealer_hand[0]["node"].is_face_up:
		dealer_hand[0]["node"].flip()
		await get_tree().create_timer(0.5).timeout

	while calculate_score(dealer_hand) < 17:
		deal_card(dealer_hand, $DealerSpawnPos, true)
		await get_tree().create_timer(0.5).timeout

	var d_score = calculate_score(dealer_hand)
	var total_money_change = 0
	var final_summary = ""

	for i in range(player_hands.size()):
		var p_score = calculate_score(player_hands[i])
		var change = 0
		if p_score > 21: change = -wager; final_summary += "Bust "
		elif p_score > d_score or d_score > 21: change = wager; final_summary += "Win "
		elif p_score == d_score: final_summary += "Push "
		else: change = -wager; final_summary += "Loss "
		total_money_change += change

	player_money += (wager + total_money_change)
	show_money_change(total_money_change)
	show_notification(final_summary)
	await get_tree().create_timer(2.0).timeout
	show_betting_controls()
	update_money_display()

# --- UTILITIES ---
func clear_table():
	for hand in player_hands + [dealer_hand]:
		for card in hand:
			if card.has("node") and is_instance_valid(card["node"]): card["node"].queue_free()
		hand.clear()
func toggle_pause(pause_state: bool):
	if !game_started: return
	get_tree().paused = pause_state
	$UI_Layer/PauseMenu.visible = pause_state
func update_hand_positions(hand, marker):
	var spacing = 40
	var offset = ((hand.size() - 1) * spacing) / 2.0
	for i in range(hand.size()):
		if hand[i].has("node") and is_instance_valid(hand[i]["node"]):
			var tween = create_tween()
			tween.tween_property(hand[i]["node"], "global_position", marker.global_position + Vector2(i * spacing - offset, 0), 0.3)

func update_money_display(): 
	# Ensure this displays 'wager' (which now updates correctly via the buttons)
	$MoneyLabel.text = "Money: $%d\nBet: $%d" % [player_money, wager]

func show_notification(msg):
	$EventLabel.text = msg
	$EventLabel.show()
	var t = create_tween()
	t.tween_property($EventLabel, "modulate:a", 0, 2.0).from(1.0)
	t.tween_callback($EventLabel.hide)

func show_gameplay_buttons():
	for btn in [$HitButton, $StandButton, $DoubleDownButton, $SplitButton]: btn.show(); btn.disabled = false
	$HandIndicator.show(); update_hand_indicator()

func hide_gameplay_buttons():
	for btn in [$HitButton, $StandButton, $DoubleDownButton, $SplitButton]: btn.hide()
	$HandIndicator.hide()

func update_hand_indicator():
	if player_hands.size() > 1:
		$HandIndicator.show()
		
		# Removed the .stop() line that was causing the crash
		
		var target_pos = ($PlayerSpawnPos2.global_position if active_hand_index == 1 else $PlayerSpawnPos1.global_position) + Vector2(0, -150)
		$HandIndicator.global_position = target_pos
		
		# Now this function will properly kill the old loop and start a new one
		setup_indicator_animation() 
	else: 
		$HandIndicator.hide()
		if indicator_tween: indicator_tween.kill() # Stop animation if hidden

func setup_indicator_animation():
	# Kill any existing animation before starting a new one
	if indicator_tween:
		indicator_tween.kill()
		
	indicator_tween = create_tween().set_loops()
	
	# Make sure to use 'indicator_tween' here, not 'tween'
	indicator_tween.tween_property($HandIndicator, "position:y", $HandIndicator.position.y - 10, 0.5).set_trans(Tween.TRANS_SINE)
	indicator_tween.tween_property($HandIndicator, "position:y", $HandIndicator.position.y + 10, 0.5).set_trans(Tween.TRANS_SINE)

func show_money_change(amount: int):
	var label = get_node_or_null("MoneyChangeLabel")
	if not label: return
	
	# Reset to original position BEFORE moving
	label.position = original_change_label_pos 
	label.modulate.a = 1.0 # Reset opacity
	
	label.text = ("+$" if amount >= 0 else "-$") + str(abs(amount))
	label.modulate = Color.GREEN if amount >= 0 else Color.RED
	label.show()
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0, 1.0)
	tween.tween_callback(label.hide)

func trigger_game_over():
	hide_gameplay_buttons()
	$BetButton.hide()
	$BetButton.disabled = true
	show_notification("Game Over! You're broke.")
	await get_tree().create_timer(2.0).timeout
	game_started = false
	get_tree().paused = true
	$UI_Layer/PauseMenu.hide()
	$UI_Layer/TitleScreen.show()
	player_money = 100
	update_money_display()

func get_spawn_node_for_hand(index):
	if player_hands.size() > 1:
		return $PlayerSpawnPos2 if index == 1 else $PlayerSpawnPos1
	return $StartSpawnPos

# --- AUDIO ---
func _play_music():
	$BGMPlayer.stream = music_playlist[current_track_index]
	$BGMPlayer.play()

func _on_music_finished():
	current_track_index = (current_track_index + 1) % music_playlist.size()
	_play_music()

func _on_volume_slider_value_changed(v):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(v))
	# Sync both menus
	$UI_Layer/TitleScreen/VolumeSlider.set_value_no_signal(v)
	$UI_Layer/PauseMenu/VolumeSlider.set_value_no_signal(v)

func _on_sfx_slider_value_changed(v):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(v))
	# Sync both menus
	$UI_Layer/TitleScreen/SFXSlider.set_value_no_signal(v)
	$UI_Layer/PauseMenu/SFXSlider.set_value_no_signal(v)

func _on_music_toggle_toggled(is_checked: bool):
	$BGMPlayer.stream_paused = !is_checked 
	
	var title_toggle = $UI_Layer/TitleScreen/MusicToggle
	var pause_toggle = $UI_Layer/PauseMenu/MusicToggle
	
	if title_toggle.button_pressed != is_checked:
		title_toggle.set_pressed_no_signal(is_checked)
	if pause_toggle.button_pressed != is_checked:
		pause_toggle.set_pressed_no_signal(is_checked)

func _change_track(direction: int):
	current_track_index = (current_track_index + direction + music_playlist.size()) % music_playlist.size()
	_play_music()

# --- SIGNAL HANDLERS ---
func _on_next_song_button_pressed(): _change_track(1)
func _on_prev_song_button_pressed(): _change_track(-1)
func _on_start_button_pressed(): start_game()
func _on_new_game_button_pressed(): start_game()
func _on_resume_button_pressed(): toggle_pause(false)
func _on_quit_button_pressed(): get_tree().quit()
func _on_bet_button_pressed(): 
	if player_money >= current_bet: player_money -= current_bet; start_round()
	else: trigger_game_over()

func _on_hit_button_pressed():
	var spawn_node = get_spawn_node_for_hand(active_hand_index)
	deal_card(player_hands[active_hand_index], spawn_node, true)
	if calculate_score(player_hands[active_hand_index]) > 21:
		end_round_logic()

func _on_stand_button_pressed():
	if active_hand_index < player_hands.size() - 1: active_hand_index += 1; update_hand_indicator()
	else: end_round_logic()

func _on_double_down_button_pressed(): 
	wager *= 2; update_money_display()
	deal_card(player_hands[active_hand_index], $StartSpawnPos, true)
	end_round_logic()

func _on_split_button_pressed(): 
	if player_hands.size() == 1 and player_hands[0].size() == 2 and player_hands[0][0].rank == player_hands[0][1].rank:
		player_money -= current_bet; wager += current_bet; player_hands.append([player_hands[0].pop_back()])
		deal_card(player_hands[0], $PlayerSpawnPos1, true)
		deal_card(player_hands[1], $PlayerSpawnPos2, true)
		active_hand_index = 0; update_hand_indicator()

func _on_next_track_button_pressed() -> void:
	_change_track(1)
func _on_prev_track_button_pressed():
	_change_track(-1)
func _on_bet_plus_pressed():
	if player_money >= (wager + 5): # Check if they can afford more
		wager += 5
		current_bet = wager # Keep both in sync
		update_money_display()

func _on_bet_minus_pressed():
	if wager > 5: # Assuming $5 is your minimum
		wager -= 5
		current_bet = wager
		update_money_display()

func show_betting_controls():
	$BetButton.show()
	$BetPlus.show()
	$BetMinus.show()

func hide_betting_controls():
	$BetButton.hide()
	$BetPlus.hide()
	$BetMinus.hide()

func play_shuffle_animation():
	$ShufflePlayer.play()
	
	# 1. Capture the "normal" scale the sprite currently has in the inspector
	var normal_scale = $DeckSprite.scale
	
	# 2. Calculate the "big" scale (1.2x bigger than your normal size)
	var big_scale = normal_scale * 1.2
	
	var tween = create_tween()
	
	# 3. Rotation shake
	tween.tween_property($DeckSprite, "rotation_degrees", 15, 0.1)
	tween.tween_property($DeckSprite, "rotation_degrees", -15, 0.1)
	tween.tween_property($DeckSprite, "rotation_degrees", 0, 0.1)
	
	# 4. Use the relative scales we calculated
	tween.tween_property($DeckSprite, "scale", big_scale, 0.1)
	tween.tween_property($DeckSprite, "scale", normal_scale, 0.1)
	
