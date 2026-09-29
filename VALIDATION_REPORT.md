# Relatório de validação

Revisão em Godot 4.7.2. Comandos reproduzíveis no README.

- Verificação estática: recursos, cena inicial, hierarquias e rig atual; caches ignorados.
- Importação pelo editor headless: cenas e scripts aceitos pelo Godot.
- Regressão de jogabilidade: chão, câmera, timer de animação, autoacerto, bonecos, dicas de combate, transição à cidade, golpes reais, lock-on, morte e reinício.
- Regressão de paredes: detecção de superfície, agarre, deslizamento, saltos em paredes opostas, limite, recarga no chão, bloqueio durante outros estados, coleta real, persistência e prevenção de duplicação.

Os testes não garantem ausência de todos os bugs. Não cobrem todas as rotas do mapa, todos os combos, desempenho ou aparência. A sensação do salto de parede e a câmera exigem avaliação manual. Não foi feita nova inspeção visual nesta revisão.

## Revisão da interface

Vida, mana, consumo inválido, regeneração, limites e vínculos após troca de cena/morte são cobertos por `tools/test_hud.gd`. Capturas do pátio e da cidade foram inspecionadas em 1280×720, incluindo barras após dano e gasto de mana pelo teste. Não houve alteração na inteligência dos inimigos nesta revisão.
