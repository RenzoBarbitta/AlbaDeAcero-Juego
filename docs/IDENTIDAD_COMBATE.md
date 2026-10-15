# Direccion del combate y del escenario

Godot 4.7, mundo 320x180, pixel art con contorno oscuro y placas de acero. Se conserva la escala del jugador; las armaduras de jefes usan modulos de dos pixeles, brillos superiores y sombra inferior. La animacion deforma solo la ilustracion, nunca el cuerpo fisico. El rig tiene clips idle/tell/act/wait en AnimationPlayer y piezas particulares por jefe.

| Jefe | Silueta y movimiento | Ataques y respuesta |
| --- | --- | --- |
| Sierra | Operario acorazado, disco sobredimensionado y zancadas | Discos que regresan, rebote y corte desde extremos. Saltar y castigar la recuperacion |
| Estruendo | Tanque de orugas, lanzadores y canon con retroceso | Bombardeo marcado, abanico de asedio y morteros balisticos. Salir de las marcas y flanquear el blindaje frontal |
| Glaciar | Corona de prismas y cristales flotantes | Lluvia por carriles, abanico y ventisca con hueco central. Cambiar de carril o saltar por el hueco |
| Incendio | Reactor alado, toberas y cola de fuego | Geiseres secuenciales, picada y frente de fuego bajo. Reposicionarse y saltar el frente |
| Voltaje | Bobinas gemelas, antenas y arcos | Conductores verticales, riel bajo y riel alto. Alternar salto y suelo |
| Coloso | Golem excavador, punos articulados y grietas luminosas | Salto-impacto, fallas del suelo y rocas que caen. Evitar impactos y atacar durante el descanso |
| Espectro | Capa con estelas y guadana | Marcas fantasma, caceria con desplazamiento y apariciones por carriles. Abandonar las marcas |
| Enjambre | Reina mecanica, abdomen segmentado y cuatro alas | Crianza, aguijones y nidos defensivos. Destruir los nidos con disparos reduce su escudo |
| Nucleo | Reactor orbital con satelites | Carriles, orbitas y cruce escalonado. Buscar huecos y cambiar de posicion |

Todas las fases finales conservan un aviso. Los ataques separan advertencia y ventana de dano. Los peligros pertenecen al jefe y desaparecen al morir. Sus estados, movimientos y geometrias se replican por el relay; el cliente muestra el aviso y el anfitrion resuelve el dano.

Los 24 sectores existentes y las ocho arenas reciben maquinaria o naturaleza animada: engranajes y gruas, arcos con vegetacion, prismas, fisuras de lava, bobinas y cableado, poleas y cestas, paneles urbanos y lluvia, y brotes bioluminiscentes. La torre incorpora esos detalles en las dos alas dejando libre la cabina. Son ilustraciones sin colision, sobre recorridos previamente verificados.

Los pilotos usan un ciclo de pasos ligado a la velocidad, con carriles separados para cada pierna y pequenas chispas al apoyar. Los ataques de jefe usan sonidos existentes con tono propio.

Proveniencia: todas las ilustraciones y animaciones son codigo nativo del proyecto. No se incorporaron imagenes ni audios de terceros. Referencias de trabajo: skills godot-gdscript, godot-animation, game-ai, game-feel, level-design y create-game-assets. El usuario delego la eleccion visual; se conservo la direccion robotica y la paleta existentes.
