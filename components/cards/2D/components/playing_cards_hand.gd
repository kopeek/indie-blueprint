@icon("res://components/cards/2D/icons/player_hand.svg")
class_name PlayingCardsHand extends Control

signal added_card(card: PlayingCardUI)
signal added_cards(cards: Array[PlayingCardUI])
signal removed_card(card: PlayingCardUI)
signal add_card_request_denied(card: PlayingCardUI)
signal add_cards_request_denied(card: Array[PlayingCardUI])
signal sorted_cards(previous: Array[PlayingCardUI], current: Array[PlayingCardUI])


@export var id: StringName
@export var maximum_cards: int = 4:
	set(value):
		maximum_cards = maxi(1, value)
@export var display_layout_mode: Layouts = Layouts.Horizontal:
	set(value):
		if display_layout_mode != value:
			display_layout_mode = value
			
			if is_inside_tree():
				adjust_hand_position()
			
@export_category("Horizontal layout")
@export var distance_between_cards: float = 2.0
@export var time_to_adjust: float = 0.06
@export_category("Fan layout")
@export var fan_card_offset_x: float = 20.0
@export_range(0, 360.0, 0.01, "degrees") var fan_rotation_max: float = 10.0

enum Layouts {
	Horizontal,
	Fan
}

var current_cards: Array[PlayingCardUI] = []


func _ready() -> void:
	fan_rotation_max = deg_to_rad(fan_rotation_max)


func _enter_tree() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	
	added_card.connect(on_added_card)
	removed_card.connect(on_removed_card)


func adjust_hand_position(except: Array[PlayingCardUI] = []) -> void:
	var target_cards: Array[PlayingCardUI] = current_cards.filter(
		func(card: PlayingCardUI): 
			return not card in except and not card.is_being_dragged()
			)
	
	match display_layout_mode:
		Layouts.Horizontal:
			_horizontal_layout(target_cards)
		Layouts.Fan:
			_fan_layout(target_cards)
	
		
func add_card(card: PlayingCardUI) -> void:
	if current_cards.size() == maximum_cards or current_cards.has(card):
		add_card_request_denied.emit(card)
	else:
		if not card.is_inside_tree():
			add_child(card)
		
		await get_tree().process_frame
		
		card.drag_drop_region.dragged.connect(on_card_dragged.bind(card))
		card.drag_drop_region.released.connect(on_card_released.bind(card))
		
		current_cards.append(card)
		added_card.emit(card)
		

func add_cards(cards: Array[PlayingCardUI] = []) -> void:
	if current_cards.size() == maximum_cards:
		add_cards_request_denied.emit(cards)
	else:
		var selected_cards = filter_cards_by_maximum_hand_size(cards)
		
		for card: PlayingCardUI in selected_cards:
			add_card(card)
		
		added_cards.emit(selected_cards)


func remove_card(card: PlayingCardUI):
	if has_card(card):
		if card.drag_drop_region.dragged.is_connected(on_card_dragged.bind(card)):
			card.drag_drop_region.dragged.disconnect(on_card_dragged.bind(card))
			
		if card.drag_drop_region.released.is_connected(on_card_released.bind(card)):
			card.drag_drop_region.released.disconnect(on_card_released.bind(card))
		
		current_cards.erase(card)
		removed_card.emit(card)
		
	
func has_card(card: PlayingCardUI) -> bool:
	return current_cards.has(card)
	

func is_empty() -> bool:
	return current_cards.is_empty()


func sort_cards_by_value_asc() -> void:
	if current_cards.size() > 1:
		var previous_sortered_cards: Array[PlayingCardUI] = current_cards.duplicate()
		
		current_cards.sort_custom(func(a: PlayingCardUI, b: PlayingCardUI): return a.value < b.value)
		sorted_cards.emit(previous_sortered_cards, current_cards)
		
		
func sort_cards_by_value_desc() -> void:
	if current_cards.size() > 1:
		var previous_sortered_cards: Array[PlayingCardUI] = current_cards.duplicate()
		
		current_cards.sort_custom(func(a: PlayingCardUI, b: PlayingCardUI): return a.value > b.value)
		sorted_cards.emit(previous_sortered_cards, current_cards)


func filter_cards_by_maximum_hand_size(cards: Array[PlayingCardUI]) -> Array[PlayingCardUI]:
	return cards.slice(0, maximum_cards - current_cards.size())


func lock_cards() -> void:
	for card: PlayingCardUI in current_cards:
		card.lock()


func unlock_cards() -> void:
	for card: PlayingCardUI in current_cards:
		card.unlock()


#region Layouts
func _horizontal_layout(cards: Array[PlayingCardUI]) -> void:
	for card: PlayingCardUI in cards:
		var index: int = cards.find(card)
		var new_position: Vector2 = Vector2(index * (card.front_sprite.size.x + distance_between_cards), 0)
		
		if card.drag_drop_region.tween_position_is_running():
			card.position = new_position
			card.drag_drop_region.original_position = card.global_position
		else:
			var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "position", new_position, time_to_adjust)
			tween.finished.connect(func(): 
				card.drag_drop_region.original_position = card.global_position, 
				CONNECT_ONE_SHOT
			)


func _fan_layout(cards: Array[PlayingCardUI]) -> void:
	var cards_size: int = cards.size() - 1
		
	for card: PlayingCardUI in cards:
		var index: int = cards.find(card)
		var final_position: Vector2 = -(card.front_sprite.size / 2.0) - Vector2(fan_card_offset_x * (cards_size - index), 0.0)
		final_position.x += (fan_card_offset_x * cards_size) / 2.0
	
		var final_rotation: float = lerp_angle(-fan_rotation_max, fan_rotation_max, float(index) / float(cards_size))
		card.position = final_position
		card.rotation = final_rotation
		card.drag_drop_region.original_position = card.global_position
		card.drag_drop_region.original_rotation = card.rotation

#endregion

#region Signal callbacks
func on_card_dragged(card: PlayingCardUI):
	if has_card(card):
		adjust_hand_position()
	

func on_card_released(card: PlayingCardUI):
	await GameGlobals.wait(0.1)
	
	## Check if the card released it's still on the hand to readjust the position
	if has_card(card) and card.get_parent() is PlayingCardsHand:
		adjust_hand_position()
		
		
func on_added_card(_card: PlayingCardUI) -> void:
	adjust_hand_position()
	

func on_removed_card(card: PlayingCardUI) -> void:
	adjust_hand_position([card])
#endregion
