# Armas, máscaras e relíquias

O equipamento muda regras de combate. `EquipmentComponent` guarda uma arma, uma máscara opcional e até duas relíquias. Os catálogos apontam para recursos editáveis; uma definição só pode ser equipada quando tem golpes ou comportamento funcional.

| Tipo | Estado atual | Regra principal |
|---|---|---|
| Cajado | Jogável | Projéteis de médio alcance, impacto e launcher de combo |
| Adagas de Cartas | Jogável | Sequência de cartas à distância e corte pesado com deslocamento seguro |
| Fios de Marionete | Jogável | Fios de médio alcance, tração e suspensão de alvos |
| Bengala-Lâmina | Jogável | Estocadas corpo a corpo, defesa e avanço cortante |
| Grimório Vivo | Jogável | Página pesada de longo alcance e selos de área |
| Máscara do Riso | Jogável | Esquiva assim que o ataque entra na janela ativa; reinicia a cadeia após o último golpe |
| Máscara do Luto | Definida, bloqueada | Precisa de magia pesada e controle de multidão |
| Máscara Vazia | Definida, bloqueada | Precisa de parry, teleporte defensivo e contra-ataque |
| Bilhete do Bis | Jogável | Esquiva perfeita recarrega imediatamente o Baralho Maldito |

O cajado e quatro expositores no pátio permitem experimentar todas as armas. `1` escolhe o Cajado, `2` as Adagas; aproximar-se de um expositor equipa a arma apresentada. `Tab` alterna a Máscara do Riso. O Bilhete do Bis começa equipado como demonstração do sistema. Durante um golpe, a troca de arma fica pendente até a próxima janela de combo; o próximo ataque usa a cadeia da nova arma. Um adereço 3D acompanha o sprite e mostra apenas a arma equipada. A máscara permanece no rig 3D oculto; o Bilhete do Bis não tem indicador no HUD. Estado de arma, máscara e relíquias sobrevive à travessia entre cenas da sessão.

Para expandir, crie os `AttackData` e a animação/visual da arma, preencha seu `WeaponData` e implemente um `WeaponBehavior` quando ela tiver uma regra exclusiva. Máscaras implementam `MaskBehavior`; relíquias implementam `RelicBehavior`. Os controladores de combate continuam responsáveis pelas hitboxes, estados e cancelamentos.
