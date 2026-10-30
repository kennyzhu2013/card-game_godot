extends PanelContainer

const QteControllerScript = preload("res://scripts/combat/qte_controller.gd")

var cursor_position: float = 0.0
var running: bool = false

@onready var _progress_bar: ProgressBar = get_node_or_null("VBox/ProgressBar")
@onready var _label: Label = get_node_or_null("VBox/Label")
@onready var _cursor: ColorRect = get_node_or_null("VBox/ProgressBar/Cursor")


func _ready() -> void:
	_update_ui()


func _process(delta: float) -> void:
	tick(delta)


func start() -> void:
	cursor_position = 0.0
	running = true
	visible = true
	_update_ui()


func stop() -> void:
	running = false
	visible = false


func tick(delta: float) -> void:
	if not running:
		return
	cursor_position = min(cursor_position + delta, QteControllerScript.BAR_LENGTH)
	_update_ui()


func resolve() -> Dictionary:
	var result: Dictionary = QteControllerScript.resolve(cursor_position)
	stop()
	return result


func _update_ui() -> void:
	if _progress_bar != null:
		_progress_bar.max_value = QteControllerScript.BAR_LENGTH
		_progress_bar.value = cursor_position
		if _cursor != null:
			_cursor.position.x = _cursor_x()
	if _label != null:
		_label.text = "QTE %.2fs" % cursor_position


func _cursor_x() -> float:
	if _progress_bar == null:
		return 0.0
	var ratio: float = cursor_position / QteControllerScript.BAR_LENGTH
	var width: float = max(_progress_bar.size.x, _progress_bar.custom_minimum_size.x)
	return max(0.0, width - 4.0) * ratio
