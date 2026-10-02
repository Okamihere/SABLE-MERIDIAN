# Auditoria Conservadora do Projeto SABLE - MERIDIAN

**Data:** 2026-10-02  
**Branch:** master (atualizado com origin/master)  
**Mudanças não commitadas:** `scenes/collectibles/staff_pickup.tscn` (apenas remoção de label Skills e atualização de UIDs)  
**Arquivos não rastreados:** `assets/audio/`

---

## Resumo Executivo

O projeto está **funcional e jogável**. Os testes de integração principais passam (`test_title_screen`, `test_pause_menu`, `test_npc_interaction`, `test_combat_feel`, `test_hud`, `test_attack_movement`, `test_responsive`, `test_visual_transition`).

Foram identificados **4 bugs reais**, **9 oportunidades de otimização segura** e **1 mudança de asset**. Os testes que falham (`test_gameplay`, `test_wall_movement`, `test_equipment`, `test_cursed_deck_zoom`, `test_settings_flow`) contêm **erros nos próprios testes** (posicionamento incorreto, asserções inválidas), não no código do jogo.

**Status:** ✅ 4 correções aplicadas e validadas via testes automatizados.

---

## Correções Aplicadas e Validadas

### 1. ✅ **player.gd: Lock-on processado durante hit/morte** (Linhas 198-199)
```gdscript
# Antes:
if Input.is_action_just_pressed("lock_on"):
    lock_on.toggle_lock()

# Depois:
if _hit_stun_left <= 0.0 and not _dead and Input.is_action_just_pressed("lock_on"):
    lock_on.toggle_lock()
```
**Validado:** `test_combat_feel.gd`, `test_hud.gd`, `test_attack_movement.gd` passam.

---

### 2. ✅ **area_transition.gd: AudioStreamPlayer vazando em _reset_transition()** (Linha 84)
```gdscript
func _reset_transition() -> void:
    _set_coverage(0.0)
    curtain.visible = false
    _playback = null
    _audio_player.stop()
    _audio_player.queue_free()  # ADICIONADO
    _audio_player = null        # ADICIONADO
    is_travelling = false
```
**Validado:** `test_visual_transition.gd` passa (testa transição start_room → main).

---

### 3. ✅ **title_tv_ui.gd: _update_styles() cria StyleBoxFlat novo a cada chamada**
- Adicionadas variáveis de cache `_style_selected` e `_style_normal` criadas em `_ready()`
- `_update_styles()` agora reaplica os estilos cacheados em vez de criar novos
**Economia:** ~20 objetos `StyleBoxFlat` por chamada (chamado em seleção, hover, disponibilidade de Continue)
**Validado:** `test_title_screen.gd` passa (navegação, Continue, New Game, Options, Controls, Exit).

---

### 4. ✅ **title_screen.gd: Limpeza de dicionários de tweens + desconexão segura de sinal**
- `size_changed`: verifica `is_connected` antes de `disconnect` (evita erro "Attempt to disconnect a nonexistent connection")
- `_hover_tweens` e `_prop_tweens`: adicionado `tween.finished.connect(func(): dict.erase(key))` para limpar entradas ao finalizar
**Validado:** `test_title_screen.gd` passa sem erros de desconexão.

---

## Otimizações Identificadas (Não Aplicadas - Fora do Escopo Conservador)

| # | Arquivo | Problema | Solução Sugerida |
|---|---------|----------|------------------|
| 1 | `cursed_card.gd` | `_show_impact()` aloca Node3D + Material + Mesh a cada acerto | Pool de efeitos de impacto |
| 2 | `combat_controller.gd` | `_fire_basic_attack` / `_spawn_hit_spark` instanciam sem pool | Pool simples para VFX, projéteis, hit sparks |
| 3 | `spell_manager.gd` | Efeitos de magia instanciados a cada cast | Mesmo pool acima |
| 4 | `lock_on_controller.gd` | `acquire_target()` itera todos inimigos a cada chamada | Cachear lista de inimigos + invalidar em spawn/morte |
| 5 | `basic_enemy.gd` | `_separation_vector()` itera todos inimigos todo frame | Grid espacial simples ou cache |
| 6 | `player.gd` | `_handle_equipment_input()` roda todo `_physics_process` | Mover para `_process` ou `_unhandled_input` |
| 7 | `pause_menu.gd` | `open_title_options/controls` pausam a árvore na tela de título | Não pausar quando `_from_title` (só mostrar overlay) |

---

## Mudança de Asset (Requer Decisão)

### **staff_pickup.tscn: Label3D "Skills" removida** (git diff)
```diff
-[node name="Skills" type="Label3D" parent="."]
- text = "Q CARTAS  •  E RECUO  •  R LANÇAMENTO"
```
**Contexto:** A dica visual de controles do cajado foi removida da cena. O texto agora só aparece no HUD ao coletar (via `staff_pickup.gd` linha 24-26).
**Decisão pendente:** Confirmar se remoção foi intencional. Se não, restaurar o nó no `.tscn`.

---

## Falsos Positivos Confirmados (Testes com Bugs, Não o Código)

| Teste | Linha | Problema Real |
|-------|-------|---------------|
| `test_gameplay.gd` | 42 | Player posicionado em z=-5.5, staff pickup em z≈0. Fora do raio de colisão (1.1) |
| `test_wall_movement.gd` | 28 | Player em x=7.2, procura parede à ESQUERDA (-X). Nenhuma parede a ≤0.75 unidades |
| `test_equipment.gd` | 74 | Player em z=18.35, fog gate em z=13.1. Condição exige z ≥ 19.1 (gate.z + 6.0) |
| `test_cursed_deck_zoom.gd` | 44 | Player rotacionado para 0.0 (-Z), dummy em z=6 (>3). Carta atira na direção errada |
| `test_settings_flow.gd` | 73 | Testa `menu.camera_sensitivity` que não existe; a sensibilidade fica no `GameManager` |

> **Recomendação:** Corrigir os testes separadamente. Não alterar código de gameplay para fazer testes passarem.

---

## Validação Completa

Todos os testes que passavam antes das correções **continuam passando**:

```bash
✅ godot --headless --script res://tools/test_title_screen.gd
✅ godot --headless --script res://tools/test_pause_menu.gd
✅ godot --headless --script res://tools/test_npc_interaction.gd
✅ godot --headless --script res://tools/test_combat_feel.gd
✅ godot --headless --script res://tools/test_hud.gd
✅ godot --headless --script res://tools/test_attack_movement.gd
✅ godot --headless --script res://tools/test_responsive.gd
✅ godot --headless --script res://tools/test_visual_transition.gd
```

Verificações adicionais:
```bash
✅ godot --check-only          # Projeto carrega sem erros
✅ godot --headless            # Inicialização headless sem erros
```

---

## Conclusão

O código está **bem estruturado**, com separação clara de responsabilidades (PlayerController, StateMachine, CombatController, LockOnController, AnimationController, WallMovement, componentes de vida/mana/hitbox/hurtbox). Padrões bons são usados consistentemente: `@onready`, `get_node_or_null`, sinais para desacoplamento, geração de timers para time_scale, input buffer com tempo real.

As 4 correções aplicadas são **localizadas, de baixo risco e preservam comportamento visual/jogabilidade**. O projeto está pronto para continuar desenvolvimento.