# Verificación del online y balance

Godot 4.7.2, Windows, octubre de 2026. Pruebas automatizadas; no equivalen a una sesión de cuatro PC con Radmin.

- `network_regression.tscn`: 16 comprobaciones, 0 fallos. Recuperación al equipar, cadencia acumulada, daño mejorado, límite de nova contra un mismo objetivo, línea de visión del rayo, pulsaciones breves/paquetes perdidos, compresión, audio del anfitrión silenciado, deduplicación y autoridad sobre daño.
- `network_online.tscn`: cuatro procesos independientes, 57 comprobaciones y 0 fallos en cada transporte. Render público: RTT de aplicación observado 352–359 ms; UDP directo por loopback: 28–35 ms. **No son mediciones comparables del rendimiento de Radmin**: el segundo recorrido permanece en la misma PC. Se verificaron compras, movimiento predictivo, estados de jefes, avisos de ataque, sonidos, efectos, animación de escenario y textura/tamaño/rotación de proyectiles de invitados.
- `network_budget.tscn`: escenario sintético con 60 enemigos y 160 proyectiles. Antes: 27.619 bytes/estado. Después, con más información de presentación: aproximadamente 3.511 bytes/estado transmitido por WebSocket. Reducción aproximada del 87 %. La CPU se midió en modo headless de desarrollo; no se extrapolan FPS de producción.
- Regresiones: jefes 119, hordas 118, correcciones previas 290 comprobaciones; todas sin fallos. Compilación estricta: 76 scripts, 0 fallos. Prueba del relay Node: aprobada.

Logs finales: `network_verified_public_{host,one,two,three}.log`, `network_verified_direct_{host,one,two,three}.log`, `net_verified_network_regression.log`, `net_verified_boss_identity_runner.log`, `net_verified_horde_runner.log`, `net_final_bugfix_runner.log`, `net_final_strict.log`. Los logs son locales y no se versionan.

Para repetir con cuatro procesos, usar `ALBA_TEST_ROLE=host|one|two|three`, `ALBA_DIRECT=1` para UDP o `ALBA_DIRECT=0` y `ALBA_RELAY_URL=wss://albadeacero-juego.onrender.com` para el relay público. El runner escribe `network_room.txt` y marcadores `network_online_*_done.txt`; eliminarlos entre ejecuciones, sin ejecutar dos grupos a la vez sobre esos mismos archivos.
