# Diseño de juego – Crazy Space's (port a Godot 4.7)

Roguelike de supervivencia por oleadas. Disparo automático con autoapuntado:
el jugador solo se mueve, hace dash y elige mejoras. Todos los números viven en
`scripts/autoload/datos.gd`.

## Controles
| | PC / mando | Teléfono (horizontal) |
|---|---|---|
| Mover | WASD / flechas / stick | Joystick flotante en la mitad izquierda (aparece donde tocas) **o** arrastre relativo (Ajustes → CONTROL) |
| Dash | Espacio / Enter / A | Botón DASH grande abajo a la derecha (anillo = recarga) |
| Reparar | R / X | Botón + con el costo en chatarra |
| Pausa | Esc / P / Start | Icono de pausa arriba a la derecha; salir de la app también pausa |

Opciones táctiles: sensibilidad del arrastre, tamaño del joystick, opacidad de los
controles y vibración. "CONTROLES TÁCTILES: SIEMPRE" los muestra en PC.

## Potenciadores del campo
| Potenciador | Tipo | Efecto | ¿Se acumula? | HUD |
|---|---|---|---|---|
| REPARACIÓN | instantáneo | +1 vida; si está llena: +1 escudo, y si también: +15 chatarra | No (se aplica al tocarlo) | Corazones |
| ESCUDO | carga | +1 carga; si está lleno sube la capacidad hasta 3; luego +10 chatarra | Sí, hasta 3 cargas | Barra segmentada bajo los corazones |
| SOBRECARGA | temporal | Cadencia x1.75 | Suma 8 s, tope 20 s | Icono con anillo y cuenta atrás |
| IMPULSO | temporal | Velocidad x1.4 | Suma 8 s, tope 20 s | Icono con anillo y cuenta atrás |
| IMÁN | temporal | Atrae toda la XP, chatarra y potenciadores | Suma 6 s, tope 15 s | Icono con anillo y cuenta atrás |
| PULSO NOVA | instantáneo | Onda de daño que borra balas enemigas | No | — |

Aparición: el primero a los 15 s; después cada 18–26 s, que baja a 12–18 s según
sube la amenaza. Máximo 2 en el campo; cada uno dura 15 s (parpadea los últimos 3).
El tipo se elige según lo que necesitas (más reparación si estás herido, más escudo
si no tienes, más imán si hay mucho botín). Durante un jefe sale uno cada 20 s y
solo de supervivencia (reparación, escudo, sobrecarga). Si un potenciador queda
fuera de pantalla, una flecha en el borde indica dónde está.

## Naves (cada desbloqueo es una mejora real)
| Nave | Puntos | Diferencias | Empieza con |
|---|---|---|---|
| NOVA MK.I | 0 | base | — |
| COMETA | 700 | daño x1.05, velocidad x1.12, dash cada 3.5 s | — |
| SPECTRA | 1500 | daño x1.1, cadencia x1.05, +12% crítico | — |
| VÓRTICE | 2600 | daño x1.1, cadencia x1.08, +1 vida | Dron de apoyo |
| MANTA-7 | 4100 | daño x1.18, velocidad x1.08, +20% vel. de bala, +1 vida, perfora 1 | — |
| BASTIÓN | 6000 | daño x1.2, +3 vidas, 1 escudo, velocidad x0.95 | — |
| ESPECTRO | 8200 | daño x1.25, cadencia x1.15, velocidad x1.15, dash 3.75 s, +1 vida | Satélite |
| FÉNIX | 10800 | daño x1.3, cadencia x1.1, +2 vidas, renace una vez | — |
| LEVIATÁN | 14200 | daño x1.38, cadencia x1.12, +2 vidas, 1 escudo | Misiles |
| ECLIPSE | 18500 | daño x1.45, cadencia x1.2, velocidad x1.1, +2 vidas, 1 escudo, +8% crítico | Cañón múltiple + Nova |

El hangar muestra barras comparables, el rasgo y las armas iniciales.

## Mejoras por nivel (fórmulas en `Nave.stat_*`)
Cada tarjeta muestra el cambio real ("DAÑO 18 → 21"). Medido con `tests/prueba_mejoras.tscn`
(daño en 30 s): todas suben al menos un 12% por nivel en su caso de uso.
| Arma | Por nivel |
|---|---|
| Cañón múltiple | +1 cañón paralelo que converge en el blanco; daño total x1.0 / 1.6 / 2.2 / 2.8 / 3.4 |
| Dron de apoyo | +1 dron, cada uno con su blanco; daño 0.5+0.1n, recarga 0.62−0.07n s |
| Misiles | salva de n misiles a blancos distintos; daño 1.5+0.25n, área 38+10n |
| Satélite (bolas de energía) | n orbes de radio 4.5+1.5n en órbita 46+10n; golpean, empujan y destruyen balas |
| Pulso nova | radio 120+32n, daño 1.4+0.6n, cada 7.5−0.9n s, empuja |
| Bomba | vuela al grupo más denso; radio 80+16n, daño 1.1+0.55n, cada 8.4−1.3n s (2 bombas en nv 3) |
| Núcleo inestable | explosión en cadena de radio 50+16n (los eslabones lejanos pierden fuerza) |
| Mira de precisión | +10% crítico y +0.25 al multiplicador crítico |

Los impactos empujan a los enemigos según su masa (coloso x3, artillero x1.6, élite x2).

## Efectos
Explosiones por capas (fogonazo, fuego, onda de calor, humo, chispas, brasas, escombros y
el sprite del enemigo partido en 4 trozos). Las grandes encadenan explosiones secundarias
y un fogonazo de pantalla. Cada explosión pide sacudida según su tamaño; la sacudida
usa "trauma" (ruido suave + leve giro) y se regula en Ajustes → SACUDIDA.
Escudo de plasma: panal hexagonal que gira, una placa por carga y una onda que sale del
punto del impacto (además empuja a los enemigos cercanos y borra balas).

## Jefes
- Cinco jefes en orden de dificultad, cada uno con su movimiento:
  | Jefe | ★ | Movimiento | Ataques propios |
  |---|---|---|---|
  | CENTINELA | 1 | barrido lento de lado a lado | abanico, barrera con hueco |
  | JEFE MECÁNICO | 2 | recorre un ocho | misiles, embestida |
  | REINA COLMENA | 3 | rodea la arena y cambia de sentido | invoca esbirros, lluvia ácida |
  | OVERLORD | 4 | persigue tu posición | embestidas, espiral |
  | NÚCLEO DEL VACÍO | 5 | se desvanece y reaparece (avisa con un brillo) | estallido al reaparecer, barrera |
  Después del quinto el ciclo se repite con +8% de agresividad por vuelta (nombre "Ω2", "Ω3"…).
  Sprites de los jefes nuevos: `tools/generar_jefes.py`.
- Primer jefe a los 90 s (si el jugador aún no tiene nivel 3 y 22 bajas, espera
  hasta 20 s más). Después, uno cada 120 s. 
- La vida se calcula con el daño real que construiste para un duelo de ~40 s.
- Movimiento: patrulla en la parte alta de la arena con un resorte amortiguado,
  se inclina al desplazarse y flota. En fase 2 (55% de vida) es más rápido y amplio.
- Avisos **sin líneas**: antes de atacar frena, tiembla, se ilumina y las bocas de
  fuego que van a disparar absorben chispas; el nombre del ataque aparece debajo.
  El blanco se fija 0.25 s antes de disparar, así que moverse en el último momento
  sirve para esquivar.
- Embestida: toma impulso hacia atrás, carga con imágenes residuales, impacta con
  un anillo de balas y regresa a su altura.
- Al morir: cadena de explosiones, la música pasa al siguiente sector y eliges una
  mejora con probabilidades de rareza de jefe (20/50/30).

## Música adaptativa
Menú → sector 1 → (jefe fase 1 → fase 2 "Climax") → sector 2 → … Las pistas de
sector rotan tras cada jefe. En pausa y en la elección de mejora la música se
apaga con un filtro paso bajo en lugar de cortarse.

## Pruebas
```
flatpak run org.godotengine.Godot --headless --path . res://tests/prueba.tscn --fixed-fps 30
flatpak run org.godotengine.Godot --path . res://tests/captura.tscn --fixed-fps 30 -- --tactil
flatpak run org.godotengine.Godot --path . res://tests/captura_menu.tscn
flatpak run org.godotengine.Godot --headless --path . res://tests/prueba_jefes.tscn
flatpak run org.godotengine.Godot --headless --path . res://tests/prueba_mejoras.tscn
```
La primera juega una partida automática y comprueba potenciadores (acumulación y
topes), aparición/fases/derrota del jefe, recompensas, topes de rendimiento y el
fin de partida. Las otras guardan capturas en `user://capturas/`.
