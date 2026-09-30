class_name Hurtbox3D
extends Area3D

## Área receptora de dano 3D para magias e projéteis.
##
## Recebe dano de Hitbox3D e emite sinal para o sistema de vida.
## Pode ser usada por personagens, inimigos ou objetos destrutíveis.
##
## Uso típico:
##   - Adicionar como filho de um personagem ou objeto
##   - Conectar [signal take_damage] para reagir a dano
##   - Configurar camadas de colisão para receber dano de hitboxes

## Emitido quando dano é recebido. Parâmetro: quantidade de dano.
signal take_damage(amount: float)

## Recebe dano e emite sinal.
## @param amount Quantidade de dano a aplicar.
## @return true se o dano foi aceito, false caso contrário.
func receive_damage(amount: float) -> bool:
	if amount <= 0.0:
		return false
	take_damage.emit(amount)
	return true
