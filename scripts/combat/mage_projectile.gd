extends Area2D
## Proyectil azul del mago.

@export var speed: float = 280.0
@export var lifetime: float = 1.6
@export var damage: int = 1

var direction: Vector2 = Vector2.RIGHT
## Quién lo disparó (ClassController): recibe carga de ultimate al acertar.
var source: Node = null
var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	monitoring = true
	monitorable = true
	collision_layer = 4
	collision_mask = 2  # enemies


func setup(dir: Vector2, tex: Texture2D) -> void:
	direction = dir.normalized()
	rotation = direction.angle()
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite and tex:
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area.get_parent())


func _try_hit(node: Node) -> void:
	if node and node.has_method("take_hit"):
		node.take_hit(damage, global_position)
		if source and source.has_method("_add_meter"):
			source.call("_add_meter", 6.0)
		queue_free()
