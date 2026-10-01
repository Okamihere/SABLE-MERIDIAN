# Architecture — SABLE MERIDIAN

## Responsibilities

| Component | Role |
|-----------|------|
| `PlayerController` | Movement, damage intake, wall grip |
| `CombatController` | Attack timing via `AttackData` |
| `LockOnController` | Target selection & switching |
| `PlayerStateMachine` | Centralized state management |
| `PlayerAnimationController` | Procedural poses for the retained, currently hidden 3D rig |
| `DirectionalSprite` | Camera-relative selection of eight idle/walk directions in `AnimatedSprite3D` |
| `GameManager` | Input, style score, global time effects |
| `Progression` | Orb IDs, wall jump limit, local save |
| `NpcInteraction` | Escolhe o NPC disponível mais próximo, mostra F e abre o diálogo |

## Animation

The visible player uses `AnimatedSprite3D` with eight camera-relative idle directions and walk cycles where frames are available. Other visual states fall back to idle. `WeaponDisplay` shows the equipped weapon beside the sprite. The retained 3D rig is hidden; its procedural `PlayerAnimationController` still runs, and its meshes follow `BoneAttachment3D`. Damage windows are controlled by combat, not animations.

## Wall Movement

`WallMovement` detects vertical surfaces on the **World** layer in the pressed direction. Base reserve is **2 jumps**; each orb ID adds one. Ground touch and fall recovery reset the spend.

Grip is temporary, then becomes a slide. Releasing the direction drops the wall. Attacks, damage, death, and dodge take priority.

To place upgrades, instance `scenes/collectibles/wall_orb.tscn` and set a unique `orb_id`. **Do not change published IDs** — they identify saved pickups.

## Conventions

- **Physics layers:** 1 World, 2 Player, 3 Enemies, 4 Player hits, 5 Enemy hits, 6 Hurtboxes
- Characters face **+Z**; camera uses **-Z**
- Hitboxes ignore their owner and hit each hurtbox once per activation
- Death signal is synchronous — do not overwrite `DEAD` after fatal damage
- Combat timers use physics delta; buffer and combo expiry use real time

## Flow & Limits

The starting room opens the city only when the player crosses `FogGate` under the north arch. `AreaTransition` covers the viewport with animated fog, changes scenes while fully covered, then reveals the city. The central `StaffPickup` and four weapon exhibits equip playable weapons and provide nearby training targets. Basic attacks remain disabled until a weapon is acquired. `GameManager.has_staff` carries the equipment state into the city. Training is optional and not saved. The city is a finite blockout; enemies do not use navigation yet. `player.tscn` is legacy; maps use `player_rig.tscn`.

The camera keeps its SpringArm collision and interpolates a wheel controlled target distance between 3.2 and 9.2 units. Lock-on uses one depth-aware post-process pass with a smooth shared fade for blur and distant desaturation. `SpellManager` shares the player's `ManaComponent` and activates the `effect_scene` in each `SpellResource`. The Baralho Maldito launches one card or a three card fan after the second combo hit; the cards use the same hitbox, hurtbox and style pipeline as melee attacks. See `docs/combat_abilities.md` for the playable weapon skills.

## Title, HUD & Mana

`scenes/ui/title_screen.tscn` é a cena inicial. `TitleScreen` monta a televisão low poly e o palco em 3D; `title_tv_ui.tscn` é desenhada numa `SubViewport` aplicada à tela da TV. O script converte raios do mouse em coordenadas dessa `SubViewport`, mantendo clique e destaque corretos durante a leve animação do aparelho. `Continuar` só fica disponível com orbes persistidas e retorna ao pátio; `Novo jogo` chama `Progression.clear_progress()`. O título e a pausa reutilizam o mesmo menu de configurações em `PauseMenu`.

`PauseMenu` preserva `user://video_settings.cfg` para compatibilidade com as opções de vídeo já salvas. O arquivo agora também armazena VSync, limite de FPS, volumes dos buses Master/Music/SFX e sensibilidade da câmera. Os buses são criados uma vez na inicialização; o áudio da transição usa SFX. A câmera lê a sensibilidade do menu ao entrar em cada cena. O botão de retorno ao título libera pausa e mouse antes de mudar de cena.

`scenes/ui/hud.tscn` is shared between tutorial and city. Its permanent display contains life and mana; the lock-on marker, wall hint and event notices appear only when relevant. `Progression.upgraded` triggers the orb pickup notice, and other systems may use `HUD.show_notice(title, detail, duration)`. Mana starts at 100 and regenerates at 8/s after 1.5s without spending. Shared UI typography is configured in `resources/ui/game_theme.tres`, using Noto Sans and Noto Serif Display; their Apache 2.0 license is included with the font files.

`NpcInteraction` is a global scene with the reusable conversation prompt and `DialogueBox`. A new NPC should join the `npcs` group, implement `can_interact()`, `get_character_name()`, `start_dialogue()`, `advance_dialogue()` and `end_dialogue()`, and emit `dialogue_line_changed(line_text, speaker_name)`. The optional `get_interaction_anchor()` places the prompt above its head; otherwise the system uses 2.25 units above the root. Place the NPC in any level; the prompt and F interaction require no level-specific wiring.

O Contrarregra ocupa um banco de pedra no canto noroeste do pátio. Seu modelo importado não contém animação de sentar; o script aplica uma pose estática simples às partes do visual. Ele emite somente a fala aprovada em toda interação, mantendo a UI e o contrato de diálogo genéricos para NPCs futuros.

## Responsive Layout

Global stretch is disabled. The HUD scales between **0.75 and 1.25** and repositions its controls on `size_changed`. NPC prompts use camera projection and stay inside the viewport.
