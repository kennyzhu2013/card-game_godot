# WebQA Regression Gate

This folder contains the reusable browser/export regression gate for the Godot client.

Primary command from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File output\webqa\run_webqa_regression.ps1
```

Quick path when `client/output/web/index.html` is already freshly exported:

```powershell
powershell -ExecutionPolicy Bypass -File output\webqa\run_webqa_regression.ps1 -SkipExport
```

The gate writes:

- `output/webqa/artifacts/webqa-regression-result.json`
- `output/webqa/artifacts/webqa-summary.md`
- `output/webqa/artifacts/webqa-console.json`
- `output/webqa/artifacts/webqa-screenshot.png`
- `output/webqa/artifacts/webqa-command.log`

Expected pass criteria:

- Godot Web export succeeds into `client/output/web`.
- A local HTTP server starts.
- A real browser opens the Web build.
- The page reaches a nonblank Godot canvas or reports the first blocking error.
- Console/page/network findings are captured in artifacts.

Known environment requirements:

- Godot console executable: `godot` or `godot4` on PATH, or pass `-GodotExe <path>`.
- Godot Web export templates installed for the current Godot version.
- Node/npm available for Playwright.
- Playwright Chromium browser available or downloadable into repo-local cache.

This gate is intentionally conservative. If export templates, browser binaries, or other tooling are absent, it writes a `blocked` result with the exact reason instead of silently passing.
