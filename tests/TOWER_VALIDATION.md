# Online building and elevator

- Strict compile: 72 scripts, zero failures (`tower_strict_final.log`).
- Horde regression: 118 checks, zero failures (`tower_horde_final.log`).
- Physical boarding and tower state: 64 checks, zero failures (`tower_runner_final.log`). Covers parties of one through four, preventing departure with an outside teammate, closing doors, ascent, the next layout, retained upgrades, and ignoring disconnected slots.
- Four independent Godot processes: 46 checks, zero failures (`tower_online_host.log`, `tower_online_one.log`, `tower_online_two.log`, `tower_online_three.log`). Checks remote input, purchases, cabin boarding, ascent snapshots, arrival, and floor collisions.
- Relay tests: four slots, fifth connection rejected, sender identity, broadcasts, mid-match admission rejection and cleanup passed.
- Visual captures: `previews/tower_cabin_four.png`, `previews/tower_ascent.png`, `previews/tower_floor_three.png`.

The relay URL is wss://albadeacero-juego.onrender.com. Public HTTP and WebSocket probes timed out while the Render deployment was failed. The user supplied the build error: Dockerfile missing at repository root. The root Dockerfile was added locally and pushed to RenzoBarbitta/AlbaDeAcero-Juego main, commit 50ed8b5ec0e2cf6b5921b3d15b3337afd26fc60e. It copies only server/package.json and server/relay.cjs and starts the relay on the hosting PORT.

Render now serves the expected relay JSON. The public relay smoke test passed with four connections. Four independent Godot processes also passed 46 checks against the public WSS URL, including input, upgrades, boarding, ascent, arrival, and floor collision layout (`public_verified_host.log`, `public_verified_one.log`, `public_verified_two.log`, `public_verified_three.log`). Public integration timeouts allow 30 seconds for variable Internet latency; an initial shorter run failed to observe one client's arrival in time, so that run is not counted as passing. No real four-PC combat balance session was performed.
