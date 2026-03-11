extends Node
## TEMPORARY TEST — Delete after verifying autoloads work.
##
## Attach this to any node in your scene.
## Press SPACE to start the deterioration clock.
## Watch the Output panel for messages.


var _last_printed_second: int = -1


func _ready() -> void:
	# Connect to the EventBus signals we want to monitor.
	# This is exactly how every future system will work:
	# "hey bulletin board, let me know when X happens."
	GameEventBus.deterioration_updated.connect(
			_on_deterioration_updated
	)
	GameEventBus.deterioration_threshold_reached.connect(
			_on_threshold_reached
	)
	GameEventBus.game_ending.connect(_on_game_ending)

	print("=== AUTOLOAD TEST READY ===")
	print("Press SPACE to start the deterioration clock.")
	print("Press P to pause/resume.")
	print("Watch this panel for messages.")
	print("")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				if not GameDeteriorationClock.is_running():
					GameDeteriorationClock.start()
					GameStates.can_player_move = true
					_last_printed_second = -1
					var fake_flower := Resource.new()
					GameStates.add_flower(fake_flower)
					print("[TEST] First flower collected! Clock should start.")
					print("[TEST] Clock STARTED. Player can move.")
					print(
						"[CLOCK] %s / %s"
						% [_format_time(0), _format_time(int(GameDeteriorationClock.GAME_DURATION))]
					)
				else:
					print("[TEST] Clock is already running.")

			KEY_P:
				if GameDeteriorationClock.is_running():
					GameDeteriorationClock.pause()
					print("[TEST] Clock PAUSED.")
				else:
					GameDeteriorationClock.resume()
					print("[TEST] Clock RESUMED.")


func _on_deterioration_updated(value: float) -> void:
	var elapsed_seconds: int = int(floor(
			value * GameDeteriorationClock.GAME_DURATION
	))

	if elapsed_seconds == _last_printed_second:
		return

	_last_printed_second = elapsed_seconds

	print(
			"[CLOCK] %s / %s (%.1f%%)"
			% [
				_format_time(elapsed_seconds),
				_format_time(int(GameDeteriorationClock.GAME_DURATION)),
				value * 100.0,
			]
	)


func _on_threshold_reached(threshold_name: StringName) -> void:
	# This is the big one — phase transitions!
	var value: float = GameDeteriorationClock.get_value()
	print("")
	print(">>> THRESHOLD CROSSED: %s at %.1f%% <<<" % [
		threshold_name,
		value * 100.0,
	])
	print("")


func _on_game_ending() -> void:
	print("")
	print("========================================")
	print("  GAME ENDING — Deterioration reached 1.0")
	print("  Flowers collected: %d" % GameStates.get_flower_count())
	print("========================================")
	print("")


func _format_time(total_seconds: int) -> String:
	var minutes: int = floori(total_seconds / 60.0)
	var seconds: int = total_seconds % 60

	return "%02d:%02d" % [minutes, seconds]
