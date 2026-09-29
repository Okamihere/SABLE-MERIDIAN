# Guia de desenvolvimento — SABLE MERIDIAN

## Responsabilidades

PlayerController controla movimento e dano; CombatController temporiza ataques via AttackData; LockOnController escolhe alvos; PlayerStateMachine centraliza estados. Os scripts têm cabeçalhos explicando suas responsabilidades e comentários nas regras menos óbvias.

PlayerAnimationController anima Skeleton3D por poses procedurais, sem AnimationTree. Hips é raiz; Spine é filho de Hips e Head é filho de Spine; braços e pernas são filhos de Hips. Malhas rígidas acompanham BoneAttachment3D. As janelas de dano são controladas pelo combate, não pelas animações.

GameManager mantém entradas, estilo e efeitos globais de tempo. Progression mantém somente IDs de orbes coletadas, calcula o limite de saltos e salva em arquivo local. Save completo, configurações e checkpoints ainda são futuros.

## Paredes e melhorias

WallMovement é um componente criado pelo jogador. Só detecta superfícies verticais na camada World, na direção pressionada. O impulso inicial tem uma breve proteção contra retorno imediato à parede. A reserva base é dois saltos; cada ID de orbe adiciona um. Chão e recuperação de queda zeram o gasto.

Agarre é temporário e depois vira deslizamento. Liberar a direção solta a parede. Ataques, dano, morte e esquiva têm prioridade. O contador aparece pelo autoload Progression.

Para espalhar melhorias, instancie `scenes/collectibles/wall_orb.tscn` e defina `orb_id` único no inspetor. Não altere IDs já publicados: eles identificam a coleta salva. Uma orbe sem ID não concede melhoria. Coletas duplicadas não aumentam o limite.

## Convenções

Camadas físicas: 1 mundo, 2 jogador, 3 inimigos, 4 golpes do jogador, 5 golpes de inimigos, 6 hurtboxes. Personagens olham em +Z; a câmera usa -Z.

Hitboxes ignoram seu dono e atingem cada hurtbox uma vez por ativação. Monitoramento é alterado de forma adiada para respeitar callbacks da física. O sinal de morte é síncrono: não sobrescreva DEAD depois de aplicar dano fatal.

Tempos de combate usam delta da física; buffer e expiração de combo usam tempo real. O contador de geração do GameManager evita que timers antigos interrompam novos efeitos de tempo.

## Fluxo e limites

O pátio inicial abre a cidade por Enter. O treino é opcional e suas lições não são salvas. A cidade é um blockout finito; inimigos ainda não usam navegação. A cena `player.tscn` é legada; os mapas usam `player_rig.tscn`.

Execute as verificações listadas no README. Os testes usam o Godot de desenvolvimento com asserções habilitadas. Arte, câmera junto a paredes e equilíbrio do movimento ainda precisam de avaliação manual.

## HUD compartilhado e mana

`scenes/ui/hud.tscn` é usado no tutorial e na cidade. Seus StyleBoxFlat podem ser editados no Godot. A apresentação de saltos de parede e avisos pertence ao HUD; Progression mantém os dados e o tempo do aviso, sem criar controles visuais.

PlayerController cria ManaComponent antes de registrar o jogador. Poderes futuros devem verificar `mana.try_spend(custo)` antes de agir. Nenhuma habilidade atual foi ligada a esse consumo. A regeneração para quando o jogador morre. O HUD lê valores iniciais e acompanha sinais de vida e mana; desconecta vínculos antigos ao receber outro jogador.

## Layout responsivo

O stretch global está desativado para medir o viewport em pixels reais. O HUD aplica uma escala própria de 0,85 a 2,5 e organiza os painéis em coordenadas lógicas. Abaixo de 900 unidades de largura ou 600 de altura, usa o modo compacto. O CanvasLayer do tutorial usa a mesma escala.

O sinal size_changed recalcula o layout; a altura de textos com quebra de linha é ajustada após o passe dos containers. Mudanças de lição também reposicionam o painel inferior. Ao projetar um alvo 3D, divida a posição de tela pela escala do HUD.
