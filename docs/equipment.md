# Armas, máscaras e relíquias

O equipamento muda regras de combate. `EquipmentComponent` guarda uma arma, uma máscara opcional e até duas relíquias. Os catálogos apontam para recursos editáveis; uma definição só pode ser equipada quando tem golpes ou comportamento funcional.

| Tipo | Estado atual | Regra principal |
|---|---|---|
| Cajado | Jogável | Alcance médio, quatro golpes e launcher após o segundo |
| Adagas de Cartas | Jogável | Alcance curto, cadeia rápida, ataques aéreos e corte pesado com deslocamento seguro |
| Fios de Marionete | Definido, bloqueado | Precisa de agarrar, suspender e lançar alvos |
| Bengala-Lâmina | Definida, bloqueada | Precisa da revelação da lâmina dentro de um combo |
| Grimório Vivo | Definido, bloqueado | Precisa de conjurações de área e animações próprias |
| Máscara do Riso | Jogável | Esquiva assim que o ataque entra na janela ativa; reinicia a cadeia após o último golpe |
| Máscara do Luto | Definida, bloqueada | Precisa de magia pesada e controle de multidão |
| Máscara Vazia | Definida, bloqueada | Precisa de parry, teleporte defensivo e contra-ataque |
| Bilhete do Bis | Jogável | Esquiva perfeita recarrega imediatamente o Baralho Maldito |

O jogador recebe o Cajado e pode conjurar as Adagas de Cartas ao pegar o cajado no pátio. `1` escolhe o Cajado, `2` as Adagas e `Tab` alterna a Máscara do Riso. O Bilhete do Bis começa equipado como demonstração do sistema. Durante um golpe, a troca de arma fica pendente até a próxima janela de combo; o próximo ataque usa a cadeia da nova arma. O personagem visível usa apenas sprites direcionais de repouso: cajado, adagas e máscara estão ligados ao rig 3D oculto e não aparecem no sprite atual. O Bilhete do Bis é passivo e não tem indicador no HUD. Estado de arma, máscara e relíquias sobrevive à travessia entre cenas da sessão.

Para expandir, crie os `AttackData` e a animação/visual da arma, preencha seu `WeaponData` e implemente um `WeaponBehavior` quando ela tiver uma regra exclusiva. Máscaras implementam `MaskBehavior`; relíquias implementam `RelicBehavior`. Os controladores de combate continuam responsáveis pelas hitboxes, estados e cancelamentos. Os recursos definidos como bloqueados só devem receber golpes/comportamentos quando esses sistemas forem reais.
