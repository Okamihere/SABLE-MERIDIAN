# SABLE MERIDIAN — Godot 4 Combat Prototype

A self-contained third-person action prototype using only Godot primitives and GDScript.

## Run
1. Open this folder in Godot 4.x.
2. Run the project (`F6/F5` depending on your workflow; main scene is configured).
3. Click the game window to capture the mouse.

## Controls
- WASD: move
- Space: jump
- Shift: dodge
- Left Mouse: light attack
- Right Mouse: heavy attack
- Q: toggle lock-on
- Esc: release/capture mouse
- F3: toggle combat debug overlay/volumes

## Combat notes
- Chain light attacks for a four-hit combo.
- After the second light, heavy becomes a launcher.
- In the air, light attacks help keep launched targets suspended.
- Dodge late into an incoming enemy hit to trigger a perfect dodge.

## World layout
The prototype is now a large but finite environment rather than a single enclosed arena. The playable blockout spans multiple connected districts and uses distant skyline geometry to create an open-world-like sense of scale without requiring actual open-world streaming.

## Fall recovery
If the player falls below the playable world, the controller automatically returns to the last stable grounded position. `fall_limit_y`, `respawn_height_offset` and `safe_position_delay` are exported under **Fall Recovery** on the Player node.

## Entrada no jogo
A sala inicial permite testar os controles. Pressione **Enter** para entrar na cidade.
**Esc** libera/captura o mouse; após morrer, a cena reinicia automaticamente.

## Verificação de jogabilidade
Execute `godot --headless --path . --script tools/test_gameplay.gd` para testar a sala inicial, entrada na cidade, dano por colisão, proteção contra autoacerto, alcance do lock-on, morte e reinício.

O pátio de treino inclui blocos de salto, marcações de esquiva e dois bonecos indestrutíveis para praticar lock-on e ataques. As seis dicas são concluídas por ações, em qualquer ordem; Enter permite sair a qualquer momento.

## Poder de parede e orbes

Pule contra uma parede e mantenha a direção apontando para ela. O personagem segura por 0,4 segundo e depois desliza lentamente. Pressione **Espaço novamente** para saltar para longe dela; vire a direção para a outra parede para encadear saltos.

Você começa com **2 saltos de parede por sequência aérea**. Tocar o chão ou recuperar uma queda repõe a reserva; ataques, dano e esquiva não permitem agarrar. O contador PAREDE mostra a reserva atual. O pátio tem um corredor de treino à direita.

Cada orbe azul encontrada aumenta o limite em **+1**. Há três orbes colocadas no protótipo. A coleta fica salva em `user://wall_orbs.cfg` e sobrevive à morte e ao reinício do jogo. Isso salva somente as melhorias, não a posição ou todo o progresso do jogo.

## Organização do código

- `scripts/player`: movimento, estados, lock-on, poses procedurais e poder de parede.
- `scripts/combat`, `scripts/components`: ataques, vida e áreas de dano.
- `scripts/levels`: tutorial e comportamento dos coletáveis/bonecos.
- `scripts/systems`: entradas, estilo e persistência das orbes.
- `scenes/collectibles/wall_orb.tscn`: orbe reutilizável. Cada instância precisa de um `orb_id` único e estável.
- `resources/skeletons/player_skeleton.tscn`: Skeleton3D válido, instanciado pelo personagem atual `player_rig.tscn`.
- `scenes/player/player.tscn`: versão legada, mantida como referência.
- `tools`: validações. `.godot` é cache; arquivos `.gd.uid` acompanham seus scripts.

### Testar

```sh
python3 tools/validate_project.py
godot --headless --path . --editor --quit
godot --headless --path . --script tools/test_gameplay.gd
godot --headless --path . --script tools/test_wall_movement.gd
```

O teste de parede usa um arquivo temporário próprio, sem modificar seu progresso salvo. Testes headless não substituem avaliar visualmente câmera, animações e sensação dos controles.

## Interface, vida e mana

O pátio e a cidade compartilham o HUD: vida vermelha, mana azul, saltos de parede, estilo e avisos de coleta. Os números mostram os valores atuais; as barras fazem transições curtas.

A reserva de mana começa em 100. Por enquanto, nenhum movimento ou golpe a consome. O componente já oferece consumo validado e regeneração de 8 por segundo após 1,5 segundo sem gasto, para integrar poderes futuros. Vida e mana voltam ao máximo no reinício da cena; esses valores não são persistidos.

Execute `godot --headless --path . --script tools/test_hud.gd` para verificar dano, cura, mana, limites, regeneração e sincronização entre cenas.

## Telas e redimensionamento

A interface acompanha o tamanho real da janela. Em telas pequenas ou verticais, usa painéis compactos, texto com quebra de linha e dicas reduzidas; em telas maiores, amplia a escala. Ultrawide aproveita a largura disponível. O indicador de alvo acompanha a projeção da câmera na nova escala.

Validação de layout: `godot --headless --path . --script tools/test_responsive.gd`. A matriz cobre 320×568, 360×640, 640×360, 800×600, 1024×768, 1280×720, 1920×1080, 2560×1080, 3440×1440 e 3840×2160. Isso verifica adaptação visual; o jogo ainda usa teclado e mouse, sem controles de toque.
