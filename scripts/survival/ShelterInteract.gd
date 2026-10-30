extends StaticBody3D
var shelter: Node3D
var kind: String
func get_interact_text() -> String:
 if kind=="door":return "[E] "+("Открыть" if shelter.door_closed else "Закрыть")+" дверь стоянки"
 return "[E] Отдых · требуется закрытая дверь"
func survival_interact() -> void:
 if kind=="door":shelter.toggle_door()
 elif kind=="bed" and has_method("is_sleep_point"):shelter.session.open_sleep(self)
