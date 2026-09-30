class_name LockOnController
extends Node

## Escolhe alvos pela proximidade e posição na tela.
##
## Libera referências inválidas, alvos mortos e alvos fora do alcance.
## O sistema de lock-on usa um score baseado na distância ao centro da tela
## e na distância do jogador para selecionar o melhor alvo.
##
## Uso típico:
##   - Adicionar como filho do jogador
##   - Chamar [method toggle_lock] para alternar lock-on
##   - Conectar [signal target_changed] para reagir a mudanças de alvo

## Emitido quando o alvo muda. Parâmetro: novo alvo (ou null se liberado).
signal target_changed(target: Node3D)

## Distância máxima para adquirir um alvo.
@export var max_distance: float = 24.0
## Peso da distância ao centro da tela no cálculo de score.
@export var center_weight: float = 10.0
## Peso da distância do jogador no cálculo de score.
@export var distance_weight: float = 0.35

## Alvo atual de lock-on (null se não há alvo).
var current_target: Node3D

## Alterna entre adquirir e liberar alvo.
func toggle_lock() -> void:
	if is_instance_valid(current_target):
		clear_target()
	else:
		acquire_target()

## Adquire o melhor alvo disponível baseado em score.
## @return O alvo adquirido, ou null se nenhum alvo válido foi encontrado.
func acquire_target() -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var origin := get_parent() as Node3D
	var best_score := INF
	var best_target: Node3D
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not (candidate is Node3D):
			continue
		var enemy := candidate as Node3D
		if enemy.has_method("is_alive") and not enemy.call("is_alive"):
			continue
		var distance := origin.global_position.distance_to(enemy.global_position)
		if distance > max_distance or camera.is_position_behind(enemy.global_position):
			continue
		var screen_pos := camera.unproject_position(enemy.global_position + Vector3.UP * 1.2)
		var center_distance := screen_pos.distance_to(screen_center) / maxf(1.0, viewport_size.length())
		var score := center_distance * center_weight + distance * distance_weight
		if score < best_score:
			best_score = score
			best_target = enemy
	current_target = best_target
	target_changed.emit(current_target)
	return current_target

## Libera o alvo atual.
func clear_target() -> void:
	current_target = null
	target_changed.emit(null)

## Retorna o alvo atual, verificando se ainda é válido.
## @return O alvo atual, ou null se inválido/fora do alcance/morto.
func get_target() -> Node3D:
	if not is_instance_valid(current_target):
		current_target = null
		return null
	if (get_parent() as Node3D).global_position.distance_to(current_target.global_position) > max_distance:
		clear_target()
		return null
	if is_instance_valid(current_target):
		if current_target.has_method("is_alive") and not current_target.call("is_alive"):
			clear_target()
	return current_target

## Rotaciona o corpo em direção ao alvo.
## @param body O nó 3D a ser rotacionado.
## @param delta Tempo desde o último frame.
## @param rotation_speed Velocidade de rotação.
func face_target(body: Node3D, delta: float, rotation_speed: float) -> void:
	var target := get_target()
	if target == null:
		return
	var direction := target.global_position - body.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	body.rotation.y = lerp_angle(body.rotation.y, target_yaw, clampf(rotation_speed * delta, 0.0, 1.0))
