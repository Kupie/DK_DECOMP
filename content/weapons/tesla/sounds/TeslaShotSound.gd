extends Node2D

func play(powervfx, shotPosition, quickshot: = false):
	position = shotPosition
	match int(powervfx):

		0:
			if quickshot:
				$Quickshotsound.startSound()
				$Shot0.setAdditionalVolume(-5)
			$Shot0.startSound()
			$Shot0.connect("sound_duration_elapsed", Callable(self, "queue_free"))
		1:
			if quickshot:
				$Quickshotsound.startSound()
				$Shot1.setAdditionalVolume(-5)
			$Shot1.startSound()
			$Shot1.connect("sound_duration_elapsed", Callable(self, "queue_free"))
		2:
			if quickshot:
				$Quickshotsound.startSound()
				$Shot2.setAdditionalVolume(-5)
			$Shot2.startSound()
			$Shot2.connect("sound_duration_elapsed", Callable(self, "queue_free"))
		3:
			if quickshot:
				$Quickshotsound.startSound()
				$Shot0.setAdditionalVolume(-5)
			$Shot3.startSound()
			$Shot3.connect("sound_duration_elapsed", Callable(self, "queue_free"))
		4:
			if quickshot:
				$Quickshotsound.startSound()
				$Shot4.setAdditionalVolume(-3)
			$Shot4.startSound()
			$Shot4.connect("sound_duration_elapsed", Callable(self, "queue_free"))
