# Servidor de salas de Alba de Acero

El cooperativo usa hasta cuatro juegos conectados por WebSocket a este servidor.
El anfitrión simula la partida; el invitado envía controles y recibe el estado
de los cuatro jugadores, enemigos, proyectiles, pickups, puzzles, compuertas y jefes.
Cada PC usa WASD, ratón, espacio, Shift, Q, E y F para su propio piloto.
La conexión del invitado no controla un segundo teclado local.

## Estado del despliegue

Direccion configurada: `wss://albadeacero-juego.onrender.com`.

El primer despliegue fallo con `failed to read dockerfile: open Dockerfile: no such file or directory`. Render buscaba el Dockerfile en la raiz y solo existia `server/Dockerfile`. La correccion agrega un Dockerfile de raiz y esta publicada en `main`, commit `50ed8b5`. Si no empieza automaticamente, usar **Manual Deploy -> Deploy latest commit**.

Configuracion del repositorio completo: **Language: Docker**, **Root Directory: vacio**, **Dockerfile Path: ./Dockerfile**, **Docker Build Context: .**, **Docker Command: vacio**, **Health Check Path: /**. Las rutas de Docker se interpretan respecto a la raiz del repositorio, segun la [documentacion de Render](https://render.com/docs/blueprint-spec#docker).

`render.yaml` de raiz configura ese caso. `server/render.yaml` usa rutas explicitas a `./server/Dockerfile` y `./server` para el mismo repositorio. No aplicar ambos como servicios separados. HTTPS `/` debe devolver JSON con `service: "alba-room-relay"`; este servicio aloja las salas, no una version web del juego.

Cuatro procesos independientes de Godot verificaron compras, embarque, ascenso y llegada al siguiente piso tanto contra el relay local como contra el servidor publico de Render. La prueba publica paso 46 comprobaciones. `node server/public-smoke.cjs` tambien verifica cuatro conexiones y las cierra al terminar. HTTPS `/` responde con el JSON esperado.

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
La correccion del despliegue fue publicada y el servicio publico fue verificado.

Para desarrollo:

```sh
npm install
npm test
npm start
```

Conectá los clientes a `ws://127.0.0.1:8787` solo para pruebas en la misma PC.
La variable ALBA_RELAY_URL puede fijar la URL sin guardarla en las preferencias.

ALBA_RELAY_URL se lee en el proceso del juego para pruebas o servidores alternativos. El servidor requiere PORT para escuchar en el puerto indicado por Render.

## Flujo del juego

1. Elegí ONLINE en el menú.
2. Configurá la dirección del servidor.
3. El anfitrión elige CREAR SALA y comparte el código de seis caracteres.
4. El invitado ingresa ese código y elige ENTRAR.
5. Cada jugador elige su propio piloto.
6. El anfitrion elige un edificio e inicia las hordas.
7. Tras despejar cada piso, entren a la cabina central y confirmen con E. Los cuatro puestos no tienen que estar ocupados.

Una sala admite hasta cuatro jugadores y puede iniciarse con uno. Al irse el anfitrión se cierra; al irse el
invitado, las hordas siguen con los pilotos restantes. No hay reconexion
automática durante una partida. Las salas vacías de invitado caducan tras
treinta minutos. El proxy de hosting debe permitir conexiones WebSocket largas.

## Verificación

`relay.test.cjs` comprueba códigos, ingreso, capacidad, transmisión y cierre.
`tests/four_online.tscn` comprueba cuatro clientes de Godot, movimientos independientes, compras, créditos y oleadas sincronizadas.
`tests/online_runner.tscn` conserva la prueba de expedición cooperativa de dos clientes, controles remotos,
cámara del invitado, puzzles, compuertas, salud, poderes y desconexión.
Las pruebas de integración usan guardados temporales propios.
