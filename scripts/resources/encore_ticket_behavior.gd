class_name EncoreTicketBehavior
extends RelicBehavior

## Esquiva perfeita devolve o Baralho à mão imediatamente.
func on_perfect_dodge(player: PlayerController) -> void:
	if player.spells.is_empty() or player.spell_manager == null:
		return
	var deck: SpellResource = player.spells[0]
	if deck == null or player.spell_manager == null:
		return
	if player.spell_manager.get_cooldown_remaining(deck) <= 0.0:
		return
	player.spell_manager.reset_cooldown(deck)
	var hud := player.get_parent().get_node_or_null("HUD")
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice("BIS DA CORTINA", "O Baralho Maldito voltou à sua mão.", 1.6)
