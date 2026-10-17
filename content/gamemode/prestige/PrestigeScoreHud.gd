extends HudElement

func init():
	super.init()
	Data.listen(self, "team1.prestige.score", true)
	Data.listen(self, "team1.prestige.baseperwave")
	Data.listen(self, "team1.prestige.multiplier")
	Data.listen(self, "team1.upgrade.gameover")

	if not multiplayer.is_server():
		while ( not Data.has("team1.prestige.score") or not Data.has("team1.prestige.baseperwave") or not Data.has("team1.prestige.multiplier")):
			await get_tree().process_frame

	$ScoreLabel.text = str(Data.of("team1.prestige.score"))
	$BasePerWaveLabel.text = str(Data.of("team1.prestige.baseperwave"))
	$MultiplierLabel.text = str(Data.of("team1.prestige.multiplier"))

func propertyChanged(property: String, oldValue, newValue):
	match property:
		"team1.upgrade.gameover":
			Data.unlisten(self, "team1.prestige.score")
		"team1.prestige.baseperwave":
			if not oldValue:
				oldValue = 1
			$BasePerWaveLabel.text = str(newValue)
			if newValue > 1:
				pingLabel($BasePerWaveLabel, newValue - oldValue)
		"team1.prestige.multiplier":
			if not oldValue:
				oldValue = 1
			$MultiplierLabel.text = str(newValue)
			if newValue > 0:
				pingLabel($MultiplierLabel, newValue - oldValue)
		"team1.prestige.score":
			if not oldValue:
				oldValue = 0
			var total: float = int(newValue) - int(oldValue)
			$Tween.stop_all()
			$Tween.remove_all()
			$Tween.interpolate_callback(self, 2.3, "updateToNewScore", int(total), int(oldValue), int(newValue))
			$Tween.start()

func updateToNewScore(total, oldValue, newValue):
	$ScoreLabel.pivot_offset = $ScoreLabel.size * 0.5
	var delay: = 0.0
	for i in 5:
		var baseString: = "%05.0f" % float(oldValue)
		baseString = baseString.substr(i + 1)
		$Tween.interpolate_callback($ScoreLabel, delay, "set", "text", baseString)
		delay += 0.08
	delay += 0.4
	var changeString: = str(total)
	if total >= 0:
		changeString = "+" + changeString
	$Tween.interpolate_callback($ScoreLabel, delay, "set", "text", changeString)
	$Tween.interpolate_property($ScoreLabel, "scale", Vector2.ONE * 1.6, Vector2.ONE, 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT, delay)
	$Tween.interpolate_callback($Kaching, delay, "play")
	delay += 1.6
	$Tween.interpolate_callback($ScoreLabel, delay, "set", "text", "")
	delay += 0.4

	for i in 5:
		var baseString: = "%05.0f" % float(oldValue)
		baseString = baseString.substr(4 - i)
		$Tween.interpolate_callback($ScoreLabel, delay, "set", "text", baseString)
		delay += 0.08
	delay += 0.2

	var actualDelta: = 0.0
	for i in total:
		var fraction = 1 / float(total - i * 0.99)
		var speed = 1.0 * fraction
		actualDelta += speed
		var intermediateValue = oldValue + i + 1
		if actualDelta > 0.01 and intermediateValue < newValue:
			$Tween.interpolate_callback($ScoreLabel, delay, "set", "text", "%05.0f" % float(oldValue + i + 1))
			$Tween.interpolate_callback($Ping, delay, "play")
			actualDelta = 0
		delay += speed
	$Tween.interpolate_property($ScoreLabel, "scale", Vector2.ONE * 1.6, Vector2.ONE, 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT, delay)
	$Tween.interpolate_callback($Kaching, delay, "play")
	$Tween.interpolate_callback($ScoreLabel, delay, "set", "text", "%05.0f" % float(newValue))
	$Tween.start()

func pingLabel(l: Label, magnitude):
	l.pivot_offset = l.size * 0.5
	l.scale = (1.4 + magnitude * 0.5) * Vector2.ONE
	$Tween.interpolate_property(l, "scale", l.scale, Vector2.ONE, 0.1, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.start()
