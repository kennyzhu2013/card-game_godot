# Configuration

## Default-Safe Behavior

- AI GM network access defaults to offline.
- Missing keys, disabled networking, budget limits and transport failures use deterministic template fallback.
- Tests use fake/injected network clients and do not call a real model service.
- The TypeScript admin surface is disabled while `M3_ADMIN_TOKEN` is empty.
- Saves, local settings, model keys and QA logs use generated or Godot `user://` paths that are ignored by Git.

## Godot Client

Import `client/project.godot` with Godot 4.6.x. The project uses a 1280x720 logical viewport and the compatibility renderer.

The following autoloads are configured:

- `SymbolLibrary`
- `ReactionTable`
- `GameState`
- `Bgm`
- `Sfx`

Runtime BGM files and their import settings are already included. Godot regenerates `.godot/` cache content on first import.

## Optional AI GM Key

The prototype client can write a user-provided key through `AIGMSecretStore` to `user://ai_gm_secret.json`. That file is outside the project tree.

Real network sampling requires both:

1. a locally supplied key;
2. an explicit local change that disables `AIGMNetwork.force_offline`.

Do not place a key in `.gd`, JSON, Markdown, shell history, screenshots or Issues. Production credentials should live in a server-side secret store.

## TypeScript Server

| Variable | Default | Purpose |
| --- | --- | --- |
| `M3_PORT` | `3001` | WebSocket gateway port |
| `M3_ADMIN_PORT` | `3002` | Local admin-inspection port |
| `M3_ADMIN_TOKEN` | empty | Bearer token; empty disables admin routes |

PowerShell example:

```powershell
$env:M3_ADMIN_TOKEN = '<set-your-own-random-token>'
cd server
npm run m3:dev
```

`.env.example` is documentation only. The server reads process environment variables directly and does not automatically load `.env`.

## WebQA

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File output\webqa\run_webqa_regression.ps1 -GodotExe <godot-console-path>
```

When `godot` or `godot4` is available on PATH, `-GodotExe` may be omitted. The current Godot version's Web export templates and Node/npm are also required. The script installs or reuses the matching Playwright Chromium build under the ignored repository-local browser cache.

Generated Web builds, Playwright packages, browsers, logs, results and screenshots stay under ignored output directories.

## Publication Exclusions

The public repository intentionally excludes:

- real credentials and local environment files;
- Godot cache, user saves and editor state;
- Node dependencies and build output;
- Windows exports, PCK files and archives;
- QA artifacts and screenshots;
- external reference games and research copies;
- image-generation prompts, failed outputs and relay configuration;
- original private Git history.

Godot source-side `.uid` files and resource import-setting `.import` files are intentionally retained because they are part of a reproducible project.

The source files `scripts/battle/phigros/phigros_battle_scene.tscn`, `scripts/battle/phigros/stage/battle_bridge.gd`, and `scripts/battle/phigros/stage/phigros_battle_scene.gd` are retained for auditability but excluded from Web, Windows and Android exports. They are an unreferenced experiment whose missing external battle-logic and tap-audio dependencies never existed in the current Greycrown source tree. No external reference-game asset is copied in to make that experiment appear complete.
