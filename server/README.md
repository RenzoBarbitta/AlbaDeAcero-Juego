# Servidor de salas de Alba de Acero

El cooperativo usa hasta cuatro juegos conectados por WebSocket a este servidor.
El anfitrión simula la partida; el invitado envía controles y recibe el estado
de los cuatro jugadores, enemigos, proyectiles, pickups, puzzles, compuertas y jefes.
Cada PC usa WASD, ratón, espacio, Shift, Q, E y F para su propio piloto.
La conexión del invitado no controla un segundo teclado local.

## Estado del despliegue

El servidor y los cuatro clientes fueron probados juntos en la misma máquina,
como procesos independientes. **Todavía no hay un servidor público alojado.**
El código de sala funciona entre PC por Internet cuando ambas usan la misma
dirección pública del servidor. El código por sí solo no reemplaza ese servidor.

## Alojarlo

Construí la imagen desde esta carpeta:

```sh
docker build -t alba-relay .
docker run --rm -p 8787:8787 alba-relay
```

En hosting con proxy HTTPS, exponé el puerto indicado por la variable PORT.
El endpoint HTTP / comprueba la salud; WebSocket usa la misma dirección.
Usá la dirección pública como `wss://tu-dominio` en todos los juegos.
El archivo `render.yaml` incluye la configuración de un servicio Docker.
El despliegue requiere una cuenta de hosting y no se realizó en esta tarea.

Para desarrollo:

```sh
npm install
npm test
npm start
```

Conectá los clientes a `ws://127.0.0.1:8787` solo para pruebas en la misma PC.
La variable ALBA_RELAY_URL puede fijar la URL sin guardarla en las preferencias.

## Flujo del juego

1. Elegí ONLINE en el menú.
2. Configurá la dirección del servidor.
3. El anfitrión elige CREAR SALA y comparte el código de seis caracteres.
4. El invitado ingresa ese código y elige ENTRAR.
5. Cada jugador elige su propio piloto.
6. El anfitrión elige una arena e inicia las hordas.

Una sala admite hasta cuatro jugadores y puede iniciarse con uno. Al irse el anfitrión se cierra; al irse el
invitado se pausa el juego y se informa la desconexión. No hay reconexión
automática durante una partida. Las salas vacías de invitado caducan tras
treinta minutos. El proxy de hosting debe permitir conexiones WebSocket largas.

## Verificación

`relay.test.cjs` comprueba códigos, ingreso, capacidad, transmisión y cierre.
`tests/four_online.tscn` comprueba cuatro clientes de Godot, movimientos independientes, compras, créditos y oleadas sincronizadas.
`tests/online_runner.tscn` conserva la prueba de expedición cooperativa de dos clientes, controles remotos,
cámara del invitado, puzzles, compuertas, salud, poderes y desconexión.
Las pruebas de integración usan guardados temporales propios.
