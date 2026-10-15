# Online: salas públicas o Radmin/LAN

Todos deben usar la versión nueva del juego (protocolo 3). El servidor de Render sigue permitiendo salas con código.

## Jugar con Radmin VPN

1. Instalen [Radmin VPN](https://www.radmin-vpn.com/es/help/) y entren todos a la misma red virtual de Radmin.
2. En el menú online del juego, seleccionen **RADMIN / LAN DIRECTA**.
3. El anfitrión pulsa **CREAR SALA** y comparte su IP de Radmin, normalmente `26.x.x.x`. **COPIAR MI IP** prioriza esa dirección; compruébenla con la que muestra Radmin.
4. Los demás escriben esa IP en **IP DEL ANFITRIÓN** y pulsan **ENTRAR**. El anfitrión elige el edificio e inicia la partida. Admite de uno a cuatro jugadores.
5. Si Windows solicita acceso de red para el juego/Godot, permitan la conexión en la red que utilizan. El anfitrión escucha en **UDP 27840**. Si no conecta, revisen que ambos aparezcan conectados en Radmin y que el firewall permita ese puerto al juego.

En una red LAN física se usa el mismo modo, escribiendo la IP local del anfitrión. Para las salas por código, seleccionen **INTERNET / SALAS CON CODIGO**.

La conexión directa evita el relay de Render. Su latencia depende del recorrido real entre las PC, de Wi-Fi, de la conexión del anfitrión y del túnel de Radmin; no se garantiza un ping concreto. Se verificaron cuatro procesos por UDP en esta PC y cuatro clientes a través de Render; queda pendiente una prueba entre cuatro PC con Radmin.

## Cambios de red y presentación

- Estados comprimidos, descarte de estados antiguos y límite de cola de salida. En el escenario de prueba con 60 enemigos y 160 proyectiles: antes 27.619 bytes por actualización; ahora aproximadamente 3.511 bytes por actualización transmitida por WebSocket, incluyendo más datos visuales. Reducción aproximada: 87 %. Es una medición sintética de tráfico, no una promesa de FPS ni de ping.
- Predicción local de caminar, saltar, dash y jetpack; el anfitrión mantiene la autoridad sobre daño, compras y enemigos. Corrección con secuencias de entrada reconocidas.
- Contadores de pulsaciones: un salto/disparo breve sobrevive a paquetes agrupados o a la pérdida de un paquete UDP.
- Sonidos y efectos transitorios replicados una sola vez; los invitados conservan sus preferencias de audio aunque el anfitrión tenga los sonidos desactivados.
- Animaciones de escenario, enemigos, carga, disparos y sierras activas en los invitados. Los proyectiles conservan su textura, tamaño y color.

## Balance

- Dispersión: recarga de 0,20 a 0,42 s; láser de 0,09 a 0,20 s; plasma de 0,40 a 0,60 s. También se ajustaron agujas, granadas, rail, drones y varios poderes/armas del taller.
- Potencia: +10 % por nivel, hasta +50 %. Cadencia: +5,5 % por nivel y Overclock +12 %, con un máximo combinado de +40 %. Los textos del taller reflejan estos valores.
- Equipar/cambiar arma conserva la recuperación; cambiar continuamente no reinicia la recarga.
- Tesla/Voltaje necesitan apuntado, alcance y línea de visión, con saltos cortos entre objetivos.
- Las salvas radiales y de drones tienen límites de impactos por objetivo: rodear a un jefe con ocho proyectiles de la misma nova ya no multiplica todo el daño contra él. Los proyectiles restantes siguen sirviendo para otros enemigos.
