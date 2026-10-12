# Alba de Acero

Juego de acción y plataformas en Godot 4. Resolución del mundo: 320x180.
El menú usa un lienzo de 640x360 escalado para que las letras tengan más aire.
Abrí `project.godot` en Godot y ejecutá la escena principal.

## Modos

**Expedición**: campaña individual con ocho recorridos diseñados por zona,
checkpoints, rutas verticales, poderes de jefes y secretos.

**Hordas online (modo principal)**: de uno a cuatro pilotos, cada uno en su PC y con cámara propia. Salas con código, oleadas que escalan con el tamaño del equipo, jefes cada tres rondas y créditos personales. Entre rondas, B abre el taller: potencia, blindaje, cadencia, reparación, doble salto y jetpack. Las mejoras compradas duran esa partida. E rescata y F activa la fusión. En oleadas pares, dos pilotos pueden mantener los aros opuestos durante seis segundos para obtener un bonus de créditos para todo el equipo; jugando solo basta un aro.

En la pantalla de salas, **ENTRENAR SOLO** permite probar las hordas sin servidor ni conexión. No abre cooperativo local.

**El servidor público todavía no está alojado.** La integración fue comprobada con cuatro procesos independientes de Godot conectados al relay local. Para jugar por Internet hay que alojar `server/` y configurar su URL pública; ver `server/README.md`.

## Ocho pilotos y progresión

| Piloto | Arma y especialidad | Acceso |
| --- | --- | --- |
| Axel | Cañón cargable, velocidad equilibrada | Inicial |
| Bastion | Escopeta, reduce daño recibido en 1 | Inicial |
| Nix | Láser perforante, mayor velocidad | Inicial |
| Orion | Plasma pesado | Inicial |
| Iris | Agujas dobles, rescate al doble de velocidad | Inicial |
| Torque | Granadas con explosión | Inicial |
| Aegis | Cañón de riel que atraviesa enemigos | Vencer cuatro jefes distintos |
| Nova | Tres drones que persiguen enemigos | Completar oleada diez |

Doble salto permanente: completar oleada 3 o vencer dos jefes distintos. Jetpack permanente: completar oleada 6 o vencer cuatro jefes distintos. Volvé a pulsar Espacio para el doble salto; mantenelo en el aire para el jetpack, que recarga al tocar suelo. Los poderes de jefes se conservan y se alternan con Q.

## Escenarios y arenas

Los ocho fondos tienen composiciones propias: hornos y chimeneas, arcos en ruinas, auroras y montañas, volcán, reactor, caverna de cristales, ciudad nocturna y bosque bioluminiscente. El distrito central reemplaza la escalera interpolada por recorridos con transporte: montacargas, vagones, plataformas suspendidas y saltos dirigidos entre islas. Los saltos dirigidos no requieren habilidades desbloqueadas.

Cada arena tiene distribución y peligro propios: prensa de fundición, artillería de ruinas, viento glacial, respiraderos volcánicos, barrido del reactor, ondas de cantera, tren urbano o contaminación biológica. Los peligros anuncian su ciclo visualmente.

## Plataformas y puzzles

Las pasarelas fijas, móviles y frágiles permiten saltar desde abajo y tienen
una superficie física de 4 píxeles. El suelo y los bloques de roca son sólidos.
Las escaleras superpuestas se verifican usando el jugador y la física reales.
La entrada tiene suelo seguro, jugadores separados del borde, checkpoint
temprano, salto de práctica y cámara colocada antes de iniciar.

Cada misión recorre tres distritos de 1600 píxeles con perfiles propios:
chimeneas, galerías, crestas, torres, terrazas y azoteas. Las rutas ascienden
entre 560 y 720 píxeles desde el acceso, invierten su dirección, ofrecen
balcones opcionales y conservan checkpoints en altura. Un contrafuerte sólido
impide atravesar el distrito caminando por el fondo. La cámara cubre las cimas.
Las pasarelas tienen siluetas propias por zona y las galerías forman cubiertas
continuas; también hay ascensores y atajos inestables.

La primera sala conserva el puzzle regional de la tabla. Las otras dos son
expediciones espaciales, con distribución en altura y reglas diferentes:

| Zona | Segunda sala | Tercera sala |
| --- | --- | --- |
| Fundición | Recuperar núcleos durante el frío | Enfriar dos cámaras permaneciendo en ellas |
| Arsenal | Recorrer glifos en orden, con regreso | Transportar pesos a dos contrapesos |
| Puerto helado | Ruta de seis placas antes del deshielo | Acompañar un núcleo térmico móvil |
| Volcán | Sellar respiraderos en fases opuestas | Transportar refrigerante con descansos térmicos |
| Central | Disparar a emisores en orden durante su apertura | Cargar acumuladores sin disparar |
| Cantera | Tres viajes de transporte de mineral | Ruta contrarreloj por las marcas |
| Ciudad | Infiltrar nodos con el radar apagado | Seguir un dron durante la descarga |
| Laboratorio | Elegir muestras verdes evitando contaminación | Entregar una muestra sin recibir daño |

Las terminales aceptan **E** cerca de ellas o disparos; las marcas se activan
al alcanzarlas con el personaje. Los errores reinician el desafío sin cerrar
permanentemente el recorrido. Las pistas aparecen en el HUD, sin carteles de
fase en el fondo. Las cargas y los objetivos se sincronizan en el cooperativo.

| Zona | Puzzle | Enemigos exclusivos |
| --- | --- | --- |
| Fundición | Válvulas de presión, objetivo y ventanas de frío | Forjador / Escoria |
| Arsenal | Cuatro conductos giratorios y ruta de suministro | Blindado / Artillero |
| Puerto helado | Secuencia de destellos y placas en orden | Patinador / Cristal |
| Volcán | Reparto de seis unidades de refrigerante entre depósitos | Basalto / Salamandra |
| Central | Circuito XOR: cada interruptor cambia su luz y ambas vecinas | Bobina / Centella |
| Cantera | Contrapesos: ambas balanzas deben sumar tres | Excavador / Rocalla |
| Ciudad | Código de sombras y terminales en orden | Acechador / Prisma |
| Laboratorio | Reactivos en orden y estación 3 defendida durante la síntesis | Espora / Nodriza |

Las familias tienen siluetas y comportamientos propios: escudos, patinaje,
saltos, teletransporte, excavación, camuflaje, separación en crías y curación.
Las invocaciones de los jefes también usan la familia de su zona.

## Online por código

1. Abrí ONLINE y escribí la URL del servidor de salas.
2. El anfitrión crea la sala y comparte su código de seis caracteres.
3. Hasta tres invitados entran con ese código. Cada uno elige su piloto.
4. El anfitrión elige la arena e inicia las hordas.

El anfitrión debe permanecer conectado. La desconexión pausa la partida;
SALIR DE SALA permite regresar al menú. No hay reconexión automática durante
la partida. El servidor relay guarda las salas en memoria y limita cada una
a cuatro jugadores. Para Internet se utiliza una dirección `wss://` pública.

## Controles

Todos los jugadores online usan los mismos controles en sus respectivas PC:

- A/D: mover; W/S: apuntar verticalmente; ratón: apuntar.
- Espacio: saltar; Shift: dash.
- Clic/J: disparar. El pulso dispara al presionar; mantener y soltar carga.
- Q: recorrer armas y poderes.
- E: interactuar o mantener para rescatar a un compañero cercano.
- F: fusión cuando la energía del equipo está llena.
- B: taller entre oleadas; cada piloto compra con sus propios créditos.
- Esc: pausa. Solo el anfitrión cambia o reinicia la misión online.

## Progresión

El jefe entrega su poder inmediatamente. Permanece al cambiar de zona,
reiniciar y cerrar el juego. Todo el equipo recibe el poder online.
La salida requiere reunir al equipo y confirmar la misión completada.

| Jefe | Poder |
| --- | --- |
| Sierra | Disco perforante que regresa |
| Estruendo | Granada parabólica con explosión de área |
| Glaciar | Tres agujas que congelan enemigos normales |
| Incendio | Anillo de fuego de corto alcance |
| Voltaje | Descarga que encadena enemigos |
| Coloso | Dos ondas de choque |
| Espectro | Orbe guiado |
| Enjambre | Tres proyectiles guiados |

Los avances individual y cooperativo se guardan separados en
`user://campaign_v2.cfg`. La URL se guarda en `user://online.cfg`.

## Comprobaciones

- `tools/check_warnings.gd`: compila los scripts con advertencias como errores.
- `tests/zones_runner.tscn`: los 24 puzzles, enemigos regionales y saltos reales.
- `tests/four_online.tscn`: cuatro procesos, puestos independientes, compras, oleadas y jefes replicados.
- `tests/horde_runner.tscn`: ocho pilotos, armas, desbloqueos, escalado, compras, rescates y objetivos de dos jugadores.
- `tests/transport_runner.tscn`: saltos dirigidos y transportes con física real.
- `tests/mobility_runner.tscn`: doble salto, jetpack y recarga al aterrizar.
- `tests/online_runner.tscn`: dos procesos conectados al relay; perfiles,
  movimiento remoto, cámara, puertas, vida, poderes y desconexión.
- `server/relay.test.cjs`: códigos, capacidad, mensajes y cierre de salas.
- `tests/reconstruction_runner.tscn`: jefes, poderes, guardado y progresión.
- `tests/duo_runner.tscn`: lógica de equipo y puzzles; simulación interna para QA.
- `tests/bugfix_runner.tscn`: proyectiles reales, estados y encuadre.
- `tests/transitions_runner.tscn`: navegación, recargas y entrada segura.
- `tests/preview.tscn`: capturas en `tests/previews/`.

El balance completo de campaña y la latencia de Internet requieren jugar en
varias PC con el servidor público, además de las comprobaciones automatizadas.
