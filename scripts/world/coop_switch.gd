extends "res://scripts/world/relay.gd"
var station: Node2D

func status_label() -> String:
	if not lit:
		return "OK"
	if not is_instance_valid(station) or station.plate_owner < 0:
		return "ACTIVA PLACA"
	return "P%d DISPARA" % (2 if station.plate_owner == 0 else 1)

func receive_projectile(amount: int, at: Vector2, shooter: int) -> bool:
	if station.plate_owner < 0 or shooter < 0 or shooter == station.plate_owner:
		_blocked_flash = 0.3
		GameManager.toast("UNO SOSTIENE LA PLACA, EL OTRO DISPARA",color)
		return false
	return super.take_damage(amount,at)

func take_damage(_amount: int, _at: Vector2) -> bool:
	return false
