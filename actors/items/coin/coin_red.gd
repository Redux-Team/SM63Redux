extends "res://actors/items/coin/coin.gd"

func _on_PickupArea_body_entered(body):
	singleton.coin_total += 2
	singleton.red_coin_total += 1
	$SFX.play()
	$PickupArea.queue_free() #clears up the acting segments of the coin so only the SFX is left
	$Sprite.queue_free()
