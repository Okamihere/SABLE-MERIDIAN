# Repertório do bobo da corte

O combate usa `CombatController` para golpes e janelas de cancelamento, `SpellManager` para mana/recarga e `SpellResource.effect_scene` para efeitos. Cada arma jogável tem ataques básicos Mouse1/Mouse2 sem mana e três skills Q/E/R. Novas habilidades podem entrar como recurso de dados e uma cena com `activate(caster, spell)`.

| Habilidade | Estado | Funcionamento ou pendência |
| --- | --- | --- |
| Cajado / Baralho Maldito | Jogável em Q/E/R | Cartas violetas, recuo em área e lançamento; cartas seguem o alvo de lock-on. |
| Adagas de Cartas | Jogável em Q/E/R | Leque de cartas, deslocamento e armadilha. |
| Fios de Marionete | Jogável em Q/E/R | Tração, suspensão e controle em área. |
| Bengala-Lâmina | Jogável em Q/E/R | Estocada, defesa e avanço cortante. |
| Grimório Vivo | Jogável em Q/E/R | Página arcana, selo e explosão em área. |
| Espelhos de Palco | Planejada | Efeito curto de deslocamento com destino seguro; integrar invulnerabilidade e contra-ataque à esquiva existente. |
| Outras máscaras | Planejadas | A Máscara do Riso já é jogável; outras máscaras ainda precisam de comportamento próprio. |
| Cajado Mutável | Planejada | Formas adicionais e hitboxes por `AttackData`, sincronizadas às janelas do combo existente. |
| Grande Finale | Planejada | Estado de arena temporário, câmera/iluminação, ataques acumulados e finalizador ligado ao medidor de estilo. |

O Baralho não cancela a animação do golpe em curso: a carta entra no meio da apresentação e preserva o buffer de combo. A partir do segundo golpe encadeado, Q abre um leque de três cartas; o custo é único para o conjunto. As cartas detectam paredes e usam `HurtboxComponent`, `HitboxComponent` e `GameManager.register_hit`, como os golpes físicos.
