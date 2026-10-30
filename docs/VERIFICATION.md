# Verification

This file records reproducible evidence from the sanitized repository. Local absolute paths, secrets and generated screenshots are intentionally omitted.

## Publication Preparation

| Check | Result |
| --- | --- |
| Initial audited stage | `1977 files` |
| Current allowlist plan | `1978 files` (adds one `.gd` capture runner, no screenshot) |
| Runtime PNG assets | `229` |
| Runtime MP3 BGM files | `7` |
| Largest staged file | `4.79 MiB` |
| Initial source/stage SHA-256 comparison | `1970 matched, 0 missing, 0 mismatched` |
| Current deterministic sanitizer | `8 files` |
| Publication tooling | `31 tests passed` |

The eight deterministic transformations cover the public project name/description, the invalid optional export icon, portable platform output paths and legacy experimental-scene export filters, one simulated AI-key test value, the default-empty admin token, two portable manual-test output paths, and portable WebQA script/documentation paths. The WebQA transformation also installs the matching Chromium build into an ignored local cache.

## Final Public-Copy Evidence

Verification was run from the sanitized feature worktree with Godot `4.6.2.stable`, Node.js `24.15.0`, npm `11.12.1`, TypeScript and Vitest `4.1.10`.

| Check | Result |
| --- | --- |
| Godot editor import | exit code `0`, no UID/parse/load errors |
| Complete Godot suite | `16726 passed, 0 failed` |
| AI GM focused runner | `699 passed, 0 failed` |
| Publication regressions | `1518 passed, 0 failed` |
| Clean Godot Web export | exit code `0`, no script/parse/export errors |
| WebQA | `passed`, Playwright `1/1`, nonblank canvas inspected |
| Browser page errors | `0` |
| Browser failed requests | `0` |
| Vitest | `47 files, 190 tests passed` |
| TypeScript build | exit code `0` |
| Production dependency audit | `0 vulnerabilities` (`npm audit --omit=dev`) |

The complete Godot runner intentionally exercises negative paths that print expected warnings/errors, and Godot reports resource/RID cleanup diagnostics at process exit. Assertions still finish at zero failures with exit code `0`. WebQA logs expected browser fullscreen/autoplay warnings and the documented silent SFX fallback; coordinate-driven screenshots are diagnostic smoke artifacts, not individual end-to-end business-flow assertions.

## Commands

```powershell
godot --headless --editor --path client --quit
godot --headless --path client -s res://tests/run_unit_tests.gd
godot --headless --path client -s res://tests/run_portfolio_tests.gd
godot --headless --path client -s res://tests/run_publication_regressions.gd

cd server
npm ci
npm test
npm run m3:build
```

WebQA:

```powershell
powershell -ExecutionPolicy Bypass -File output\webqa\run_webqa_regression.ps1 -GodotExe <godot-console-path>
```

## Repository Policy Gate

After removing regenerated test output, the public-copy policy gate reported:

| Check | Result |
| --- | --- |
| Secret/PII/private-path/media-metadata scanner | `0 findings` |
| Runtime PNG candidates | `229` |
| Runtime MP3 candidates | `7` |
| Screenshot PNG candidates | `0` |
| Prohibited files/directories | `0` |
| Largest candidate file | `4.79 MiB` (`foghorn_harbor.mp3`) |

The staged asset counts and Git size policy are checked again against the exact index before commit. The local/remote `main` hash comparison is performed after a normal push. Generated dependencies, Web exports, browser caches, logs and screenshots remain ignored and are not part of the repository.
