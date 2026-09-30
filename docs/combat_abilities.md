# Repertório do bobo da corte

O combate usa `CombatController` para golpes e janelas de cancelamento, `SpellManager` para mana/recarga e `SpellResource.effect_scene` para efeitos. Cada nova habilidade pode entrar como recurso de dados e uma cena com `activate(caster, spell)`. A UI só deve mostrar habilidades realmente equipadas. Os slots E/R do InputMap permanecem sem ação jogável até existir um efeito completo.

| Habilidade | Estado | Funcionamento ou pendência |
| --- | --- | --- |
| Baralho Maldito | Jogável em Q | Carta única ou leque após o segundo golpe; projétil luminoso, dano, estilo, mana e recarga. Futuras variantes podem ser lâmina, explosivo e armadilha dentro da mesma família. |
| Fios de Marionete | Planejada | Seleção por lock-on, agarrar um alvo válido, tração/suspensão temporária e arremesso; respeitar estados de inimigo e colisões. |
| Espelhos de Palco | Planejada | Efeito curto de deslocamento com destino seguro; integrar invulnerabilidade e contra-ataque à esquiva existente. |
| Outras máscaras | Planejadas | A Máscara do Riso já é jogável; outras máscaras ainda precisam de comportamento próprio. |
| Cajado Mutável | Planejada | Formas visuais e hitboxes por `AttackData`, sincronizadas às janelas do combo já existente. |
| Grande Finale | Planejada | Estado de arena temporário, câmera/iluminação, ataques acumulados e finalizador ligado ao medidor de estilo. |

O Baralho não cancela a animação do golpe em curso: a carta entra no meio da apresentação e preserva o buffer de combo. A partir do segundo golpe encadeado, Q abre um leque de três cartas; o custo é único para o conjunto. As cartas detectam paredes e usam `HurtboxComponent`, `HitboxComponent` e `GameManager.register_hit`, como os golpes físicos.
