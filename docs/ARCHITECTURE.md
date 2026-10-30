# Architecture

## 1. Runtime Shape

`client/project.godot` starts at `client/scenes/hub/hub.tscn` and registers shared state, ritual libraries and audio players as autoloads. The current playable loop is local-first: Hub actions open city, tower, combat, deck, forge, settings and dialogue surfaces against deterministic game state.

The TypeScript server is a separate authoritative-system prototype. It is tested with the repository but is not required to boot the current offline Godot loop.

## 2. Deterministic Gameplay Systems

Runtime code is split by ownership:

- `scripts/state/` owns durable player and world state.
- `scripts/combat/` and `scripts/ui/battle*` own card effects, actors, turn flow and battle presentation.
- `scripts/ritual/` owns symbols, reactions, forging, reforge rules and rhythm checkpoints.
- `scripts/world/` and `scripts/hub/` own district movement, opportunities, commissions, NPC interactions and day-cycle actions.
- `scripts/tower/` owns floor generation, dispatch, encounter routing, boss results and retreat rules.
- `scripts/audio/` owns BGM routing and bounded SFX playback.

Content is data-driven under `client/data/`. Cards, enemies, events, shops, pathways, commissions and AI GM templates are loaded from JSON/resources instead of being embedded in one central script.

## 3. AI GM Runtime

`PromptContext` is the narrow model boundary. It copies scene identifiers, player state, scene payload, contract state and NPC context into structured dictionaries instead of exposing the full runtime object graph.

`AIGMService.call_ai_gm()` processes a request in this order:

1. Validate context.
2. Build a stable cache key for cacheable scenes.
3. Check the offline switch and daily call/cost budget.
4. Try configured providers through `AIGMNetwork`.
5. Retry only transport/5xx failures within fixed limits.
6. Render a deterministic template when network use is disabled or fails.
7. Return text plus structured source/error metadata.

Model output is presentation text. Callers still validate and apply every state transition through deterministic game services.

The current network adapter implements Anthropic Messages API transport. Other provider names represent explicit extension boundaries and return `provider_not_implemented`. Normal gameplay and all default tests run with network access disabled.

## 4. Cache, Budget and Secret Boundaries

Only selected scenes are cacheable. Cache keys hash identifying payload combinations, and tests verify that persisted cache files do not expose raw identifiers.

The budget layer estimates calls and provider tiers to support downgrade/fallback decisions. These values are engineering limits, not measured billing claims.

`AIGMSecretStore` writes an optional local prototype key to Godot `user://` storage. It is never part of repository state. A production design should move provider credentials behind a service gateway.

## 5. TypeScript Server

The server isolates network input before state mutation:

- Gateway: connection lifecycle, authentication, heartbeat, reconnect grace and rate limits.
- Protocol: operation names, envelope validation and payload validation.
- World: shards, movement, AOI, delta ledger, snapshots, interactions and monster runtime.
- Combat: combat instances, routing and world combat locks.
- Admin: local state inspection protected by an environment-provided Bearer token.

An empty `M3_ADMIN_TOKEN` disables admin routes. In-memory identity and persistence are deliberate prototype boundaries.

## 6. Verification Layers

- Godot unit/integration runners cover domain services, runtime wiring and player-facing regressions.
- Focused runners isolate AI GM, forging, opportunity, commission and tower paths.
- Vitest covers server units, integration flows, protocol handling and local load behavior.
- WebQA exports the Godot Web build and drives a real browser through a core interaction path.
- Publication tooling validates an allowlist, deterministic sanitization, media metadata and prohibited artifacts before Git staging.

## 7. Current Limitations

- The client/server multiplayer integration is not the default playable path.
- Real AI network transport is disabled by default and only one provider adapter is implemented.
- There is no general-purpose Agent planner, unrestricted tool registry or long-term vector memory.
- Unified trace IDs, prompt/evaluation datasets and production telemetry remain future work.
- SFX has a complete routing/fallback layer, but missing real SFX files resolve to silence.
- The retained legacy Phigros experiment under `scripts/battle/phigros/` includes three unused scene/bridge files that reference dependencies absent from the current project. They are not reachable from the main runtime and are explicitly excluded by platform export presets; the reusable and MPL-covered lane components remain available as source.
