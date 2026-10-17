extends Stage


func beforeStart():
	self.fadeInTime = 0.0
	self.fadeOutTime = 0.2
	find_child("RawFury").modulate.a = 0.0
	find_child("RawFury").modulate.r = 0.0
	find_child("RawFury").modulate.g = 0.0
	find_child("RawFury").modulate.b = 0.0

	if BuildCustomization.has_feature("porting_credits_splashscreen"):
		%RawFury.visible = false
		%bb_rawfury_seaven_pasta.visible = true
		%LogoAnimation.free()
		%LogoSound.free()
		%bb_rawfury_seaven_pasta.modulate.a = 0.0
		%bb_rawfury_seaven_pasta.modulate.r = 0.0
		%bb_rawfury_seaven_pasta.modulate.g = 0.0
		%bb_rawfury_seaven_pasta.modulate.b = 0.0
		$Tween.interpolate_property( %bb_rawfury_seaven_pasta, "modulate:a", 0.0, 1.0, 0.2)
		$Tween.interpolate_property( %bb_rawfury_seaven_pasta, "modulate:r", 0.0, 1.0, 0.2, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.2)
		$Tween.interpolate_property( %bb_rawfury_seaven_pasta, "modulate:g", 0.0, 1.0, 0.2, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.2)
		$Tween.interpolate_property( %bb_rawfury_seaven_pasta, "modulate:b", 0.0, 1.0, 0.2, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.2)
		$Tween.interpolate_callback(self, 2.5, "finishStage")
		$Tween.start()

func end_animation():
	$Tween.interpolate_property(find_child("RawFury"), "modulate:a", 0.0, 1.0, 0.2)
	$Tween.interpolate_property(find_child("RawFury"), "modulate:r", 0.0, 1.0, 0.2, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.2)
	$Tween.interpolate_property(find_child("RawFury"), "modulate:g", 0.0, 1.0, 0.2, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.2)
	$Tween.interpolate_property(find_child("RawFury"), "modulate:b", 0.0, 1.0, 0.2, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.2)
	$Tween.interpolate_callback(self, 1.5, "finishStage")
	$Tween.start()

func finishStage():
	emit_signal("request_end")
