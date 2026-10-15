# Combat and environment identity validation

- Strict core scripts: 75 scripts, zero failures.
- Boss identity suite: nine repertoires, three actions each, nine phase-two openings, rig clips, warning windows, attack geometry, cleanup on death, actual collision damage and destructible nests.
- Campaign progression, powers and saves: 164 checks, zero failures.
- Horde regression: 118 checks, zero failures.
- Existing interaction/layout regression: 290 checks, zero failures.
- Campaign routes with the slowest pilot: 125 checks, zero failures.
- Public Render integration: four independent Godot processes verified movement, purchases, animated boss states, warning geometry and active attack geometry; 39 checks, zero failures.

In-context captures: tests/previews/identity_arena_*.png. Rig sheets: tests/previews/boss_family_idle.png, boss_family_tell.png, boss_family_act.png, boss_family_wait.png. Campaign captures can be regenerated with campaign_preview.tscn. No four-PC latency/combat balance playtest was performed; the public integration used four processes on this PC through Render.
