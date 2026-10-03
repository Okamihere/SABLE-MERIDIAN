extends Node

## Sistema centralizado de configurações gráficas.
##
## Gerencia presets (LOW/MEDIUM/HIGH/ULTRA/CUSTOM), aplica configurações
## via ProjectSettings e persiste em user://graphics_settings.cfg.
##
## O renderer GL Compatibility (Godot 4.7) suporta via ProjectSettings:
## - MSAA 3D, FXAA, Anisotropic Filtering
## - Shadow Quality, SSAO, SSIL
## - Volumetric Fog Quality, Glow/Bloom
## - Render Scale (scaling_3d_scale)
##
## TAA não é suportado no GL Compatibility (apenas Forward+/Mobile).
## Nota: Algumas mudanças exigem reload da cena ou restart do jogo.

signal preset_changed(preset_name: String)
signal settings_applied()

enum Preset { LOW, MEDIUM, HIGH, ULTRA, CUSTOM }

const SETTINGS_PATH := "user://graphics_settings.cfg"

## Preset atual
var current_preset: Preset = Preset.HIGH

## Configurações individuais (sobrescrevem o preset quando != -1)
var render_scale: float = -1.0
var msaa_3d: int = -1
var fxaa: bool = false
var anisotropic_filter: int = -1
var shadow_quality: int = -1
var ssao_enabled: bool = false
var ssil_enabled: bool = false
var volumetric_fog_quality: int = -1
var glow_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_settings()

## Aplica um preset e atualiza todas as configurações
func apply_preset(preset: Preset) -> void:
	current_preset = preset
	match preset:
		Preset.LOW:
			render_scale = 0.75
			msaa_3d = 0
			fxaa = true
			anisotropic_filter = 1
			shadow_quality = 0
			ssao_enabled = false
			ssil_enabled = false
			volumetric_fog_quality = 0
			glow_enabled = true
		Preset.MEDIUM:
			render_scale = 0.85
			msaa_3d = 1
			fxaa = false
			anisotropic_filter = 2
			shadow_quality = 1
			ssao_enabled = true
			ssil_enabled = false
			volumetric_fog_quality = 1
			glow_enabled = true
		Preset.HIGH:
			render_scale = 1.0
			msaa_3d = 2
			fxaa = false
			anisotropic_filter = 3
			shadow_quality = 2
			ssao_enabled = true
			ssil_enabled = true
			volumetric_fog_quality = 2
			glow_enabled = true
		Preset.ULTRA:
			render_scale = 1.0
			msaa_3d = 3
			fxaa = false
			anisotropic_filter = 4
			shadow_quality = 2
			ssao_enabled = true
			ssil_enabled = true
			volumetric_fog_quality = 3
			glow_enabled = true
		Preset.CUSTOM:
			pass
	_apply_settings()
	preset_changed.emit(_preset_to_string(preset))

## Aplica as configurações atuais via ProjectSettings
func _apply_settings() -> void:
	var vp = get_viewport()
	
	if render_scale >= 0.0:
		ProjectSettings.set_setting("rendering/viewport/scaling_3d_scale", render_scale)
		RenderingServer.viewport_set_scaling_3d_scale(vp.get_viewport_rid(), render_scale)
	
	if msaa_3d >= 0:
		ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", msaa_3d)
	
	if fxaa != (ProjectSettings.get_setting("rendering/anti_aliasing/quality/fxaa") or false):
		ProjectSettings.set_setting("rendering/anti_aliasing/quality/fxaa", fxaa)
	
	if anisotropic_filter >= 0:
		ProjectSettings.set_setting("rendering/textures/anisotropic_filter_level", anisotropic_filter)
	
	if shadow_quality >= 0:
		ProjectSettings.set_setting("rendering/shadows/quality", shadow_quality)
	
	if ssao_enabled != (ProjectSettings.get_setting("rendering/environment/ssao") or false):
		ProjectSettings.set_setting("rendering/environment/ssao", ssao_enabled)
	
	if ssil_enabled != (ProjectSettings.get_setting("rendering/environment/ssil") or false):
		ProjectSettings.set_setting("rendering/environment/ssil", ssil_enabled)
	
	if volumetric_fog_quality >= 0:
		ProjectSettings.set_setting("rendering/volumetric_fog/quality", volumetric_fog_quality)
	
	if glow_enabled != (ProjectSettings.get_setting("rendering/environment/glow") or true):
		ProjectSettings.set_setting("rendering/environment/glow", glow_enabled)
	
	settings_applied.emit()

## Define uma configuração individual e muda para CUSTOM se não for o valor do preset atual
func set_setting(setting_name: String, value: Variant) -> void:
	match setting_name:
		"render_scale": render_scale = value
		"msaa_3d": msaa_3d = value
		"fxaa": fxaa = value
		"anisotropic_filter": anisotropic_filter = value
		"shadow_quality": shadow_quality = value
		"ssao_enabled": ssao_enabled = value
		"ssil_enabled": ssil_enabled = value
		"volumetric_fog_quality": volumetric_fog_quality = value
		"glow_enabled": glow_enabled = value
		_: return
	
	if current_preset != Preset.CUSTOM:
		_verify_if_still_matches_preset()
	
	_apply_settings()

## Verifica se as configurações atuais ainda correspondem ao preset selecionado
func _verify_if_still_matches_preset() -> void:
	if current_preset == Preset.CUSTOM:
		return
	
	var matches := true
	match current_preset:
		Preset.LOW:
			matches = (render_scale == 0.75 and msaa_3d == 0 and fxaa == true and
				anisotropic_filter == 1 and shadow_quality == 0 and ssao_enabled == false and
				ssil_enabled == false and volumetric_fog_quality == 0 and glow_enabled == true)
		Preset.MEDIUM:
			matches = (render_scale == 0.85 and msaa_3d == 1 and fxaa == false and
				anisotropic_filter == 2 and shadow_quality == 1 and ssao_enabled == true and
				ssil_enabled == false and volumetric_fog_quality == 1 and glow_enabled == true)
		Preset.HIGH:
			matches = (render_scale == 1.0 and msaa_3d == 2 and fxaa == false and
				anisotropic_filter == 3 and shadow_quality == 2 and ssao_enabled == true and
				ssil_enabled == true and volumetric_fog_quality == 2 and glow_enabled == true)
		Preset.ULTRA:
			matches = (render_scale == 1.0 and msaa_3d == 3 and fxaa == false and
				anisotropic_filter == 4 and shadow_quality == 2 and ssao_enabled == true and
				ssil_enabled == true and volumetric_fog_quality == 3 and glow_enabled == true)
	
	if not matches:
		current_preset = Preset.CUSTOM
		preset_changed.emit("CUSTOM")

## Restaura os valores padrão (preset HIGH)
func restore_defaults() -> void:
	render_scale = -1.0
	msaa_3d = -1
	fxaa = false
	anisotropic_filter = -1
	shadow_quality = -1
	ssao_enabled = false
	ssil_enabled = false
	volumetric_fog_quality = -1
	glow_enabled = true
	
	apply_preset(Preset.HIGH)

## Carrega configurações salvas
func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		apply_preset(Preset.HIGH)
		return
	
	current_preset = int(config.get_value("graphics", "preset", int(Preset.HIGH)))
	render_scale = float(config.get_value("graphics", "render_scale", -1.0))
	msaa_3d = int(config.get_value("graphics", "msaa_3d", -1))
	fxaa = bool(config.get_value("graphics", "fxaa", false))
	anisotropic_filter = int(config.get_value("graphics", "anisotropic_filter", -1))
	shadow_quality = int(config.get_value("graphics", "shadow_quality", -1))
	ssao_enabled = bool(config.get_value("graphics", "ssao_enabled", false))
	ssil_enabled = bool(config.get_value("graphics", "ssil_enabled", false))
	volumetric_fog_quality = int(config.get_value("graphics", "volumetric_fog_quality", -1))
	glow_enabled = bool(config.get_value("graphics", "glow_enabled", true))
	
	_apply_settings()

## Salva configurações atuais
func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "preset", int(current_preset))
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("graphics", "msaa_3d", msaa_3d)
	config.set_value("graphics", "fxaa", fxaa)
	config.set_value("graphics", "anisotropic_filter", anisotropic_filter)
	config.set_value("graphics", "shadow_quality", shadow_quality)
	config.set_value("graphics", "ssao_enabled", ssao_enabled)
	config.set_value("graphics", "ssil_enabled", ssil_enabled)
	config.set_value("graphics", "volumetric_fog_quality", volumetric_fog_quality)
	config.set_value("graphics", "glow_enabled", glow_enabled)
	
	var result := config.save(SETTINGS_PATH)
	if result != OK:
		push_warning("Não foi possível salvar configurações gráficas: %s" % error_string(result))

## Retorna o nome do preset atual
func get_current_preset_name() -> String:
	return _preset_to_string(current_preset)

func _preset_to_string(preset: Preset) -> String:
	match preset:
		Preset.LOW: return "LOW"
		Preset.MEDIUM: return "MEDIUM"
		Preset.HIGH: return "HIGH"
		Preset.ULTRA: return "ULTRA"
		Preset.CUSTOM: return "CUSTOM"
	return "CUSTOM"

## Obtém o valor efetivo de uma configuração (considerando preset)
func get_effective_value(setting_name: String) -> Variant:
	match setting_name:
		"render_scale":
			if render_scale >= 0.0: return render_scale
			return _get_preset_value(current_preset, "render_scale")
		"msaa_3d":
			if msaa_3d >= 0: return msaa_3d
			return _get_preset_value(current_preset, "msaa_3d")
		"fxaa": return fxaa
		"anisotropic_filter":
			if anisotropic_filter >= 0: return anisotropic_filter
			return _get_preset_value(current_preset, "anisotropic_filter")
		"shadow_quality":
			if shadow_quality >= 0: return shadow_quality
			return _get_preset_value(current_preset, "shadow_quality")
		"ssao_enabled": return ssao_enabled
		"ssil_enabled": return ssil_enabled
		"volumetric_fog_quality":
			if volumetric_fog_quality >= 0: return volumetric_fog_quality
			return _get_preset_value(current_preset, "volumetric_fog_quality")
		"glow_enabled": return glow_enabled
	return null

func _get_preset_value(preset: Preset, setting: String) -> Variant:
	match preset:
		Preset.LOW:
			match setting:
				"render_scale": return 0.75
				"msaa_3d": return 0
				"fxaa": return true
				"anisotropic_filter": return 1
				"shadow_quality": return 0
				"ssao_enabled": return false
				"ssil_enabled": return false
				"volumetric_fog_quality": return 0
				"glow_enabled": return true
		Preset.MEDIUM:
			match setting:
				"render_scale": return 0.85
				"msaa_3d": return 1
				"fxaa": return false
				"anisotropic_filter": return 2
				"shadow_quality": return 1
				"ssao_enabled": return true
				"ssil_enabled": return false
				"volumetric_fog_quality": return 1
				"glow_enabled": return true
		Preset.HIGH:
			match setting:
				"render_scale": return 1.0
				"msaa_3d": return 2
				"fxaa": return false
				"anisotropic_filter": return 3
				"shadow_quality": return 2
				"ssao_enabled": return true
				"ssil_enabled": return true
				"volumetric_fog_quality": return 2
				"glow_enabled": return true
		Preset.ULTRA:
			match setting:
				"render_scale": return 1.0
				"msaa_3d": return 3
				"fxaa": return false
				"anisotropic_filter": return 4
				"shadow_quality": return 2
				"ssao_enabled": return true
				"ssil_enabled": return true
				"volumetric_fog_quality": return 3
				"glow_enabled": return true
	return null