# Greycrown Complete Publication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the public AI-only extract with a sanitized, self-contained Greycrown game repository containing the complete Godot runtime, all runtime art and BGM, tests, and the maintained TypeScript server.

**Architecture:** Export the private working tree through an allowlist into a fresh staging directory, apply deterministic public-safe transformations, and scan that staging tree before merging it into the existing public repository. Preserve the existing public Git history and security hardening, then validate the public copy itself before a normal fast-forward push.

**Tech Stack:** Python 3 standard library, PowerShell, Git, Godot 4.6, GDScript, Node.js, TypeScript, Vitest

---

## File Map

Workspace-only publication tooling:

- Modify `tools/portfolio/build_exports.py`: allow a fresh staging directory name without changing the repository manifest identity.
- Modify `tools/portfolio/test_build_exports.py`: cover explicit staging names and invalid names.
- Modify `tools/portfolio/export_manifest.json`: expand Greycrown from a feature slice to the complete runtime allowlist.
- Create `tools/portfolio/sanitize_greycrown_export.py`: apply deterministic, fail-closed transformations to the staged copy.
- Create `tools/portfolio/test_sanitize_greycrown_export.py`: verify every required transformation.
- Modify `tools/portfolio/scan_public_repo.py`: inspect sensitive PNG and MP3 metadata in addition to text files.
- Modify `tools/portfolio/test_scan_public_repo.py`: cover embedded metadata without echoing matched values.

Published repository:

- Add/replace `client/`: complete Godot project, runtime resources, and tests.
- Add/replace `server/`: maintained TypeScript server and tests.
- Add `output/webqa/README.md`, `output/webqa/run_webqa_regression.ps1`, and `output/webqa/webqa_playwright.spec.js`: portable verification tooling only.
- Modify `README.md`: describe the complete game instead of an AI-only extract.
- Modify `.gitignore`: ignore regenerated dependencies, saves, imports cache, exports, and WebQA artifacts without ignoring `.uid` or sidecar `.import` settings.
- Create `.gitattributes`: mark PNG and MP3 files as binary and normalize source text line endings.
- Modify `.env.example`: document optional server configuration with empty secret values.
- Modify `PORTFOLIO_NOTICE.md`: disclose project-owned generated media and preserve third-party rights.
- Create `THIRD_PARTY_NOTICES.md`: identify the MPL-2.0 `godot-phigros` derivative files.
- Create `licenses/MPL-2.0.txt`: bundle the complete third-party license text.
- Create `server/README.md`: document the maintained server only.
- Modify `docs/ARCHITECTURE.md`, `docs/CONFIGURATION.md`, `docs/INTERVIEW_NOTES.md`, and `docs/VERIFICATION.md`: align documentation with the full repository.

### Task 1: Add Safe Staging Target Support

**Files:**

- Modify: `tools/portfolio/build_exports.py`
- Modify: `tools/portfolio/test_build_exports.py`

- [ ] **Step 1: Write tests for an explicit staging name**

Add these cases to `BuildExportsTests`:

```python
def test_exports_under_explicit_target_name(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        source = root / "source"
        destination = root / "exports"
        (source / "app").mkdir(parents=True)
        (source / "README.md").write_text("sample", encoding="utf-8")
        manifest = check_manifest(self._write_manifest(root, source, destination))

        target = export_repository(
            manifest, "sample-repo", target_name="sample-repo-stage"
        )

        self.assertEqual(target.name, "sample-repo-stage")
        self.assertTrue((target / "README.md").is_file())

def test_rejects_invalid_explicit_target_name(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        source = root / "source"
        destination = root / "exports"
        (source / "app").mkdir(parents=True)
        (source / "README.md").write_text("sample", encoding="utf-8")
        manifest = check_manifest(self._write_manifest(root, source, destination))

        with self.assertRaises(ExportError):
            export_repository(manifest, "sample-repo", target_name="../escape")
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run:

```powershell
python -m unittest tools.portfolio.test_build_exports -v
```

Expected: the new tests fail because `export_repository()` has no `target_name` parameter.

- [ ] **Step 3: Implement validated staging names**

Change the export function and CLI in `build_exports.py`:

```python
def export_repository(
    manifest: ExportManifest,
    repo_name: str,
    target_name: str | None = None,
) -> Path:
    try:
        repo = manifest.repositories[repo_name]
    except KeyError as error:
        raise ExportError(f"unknown repository: {repo_name}") from error
    resolved_target_name = target_name or repo.name
    if not REPOSITORY_NAME_PATTERN.fullmatch(resolved_target_name):
        raise ExportError("target name must use lowercase letters, digits, and hyphens")
    target = manifest.destination / resolved_target_name
    if target.exists():
        raise FileExistsError(f"refusing to overwrite existing target: {target}")
    copy_plan = _collect_copy_plan(repo)
    if not copy_plan:
        raise ExportError(f"allowlist produced no files for {repo.name}")
    target.mkdir(parents=True, exist_ok=False)
    for source_file, relative_destination in copy_plan:
        destination_file = target / relative_destination
        resolved_parent = destination_file.parent.resolve(strict=False)
        if not _is_within(resolved_parent, target.resolve(strict=True)):
            raise ExportError(f"destination escapes repository: {relative_destination}")
        destination_file.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_file, destination_file)
    return target
```

Add `--target-name` to the parser and pass it only when one repository is selected:

```python
parser.add_argument("--target-name", help="fresh destination directory name")
if args.target_name and not args.repo:
    raise ExportError("--target-name requires --repo")
target = export_repository(
    manifest, repo_name, target_name=args.target_name
)
```

- [ ] **Step 4: Run the exporter unit tests and confirm GREEN**

Run:

```powershell
python -m unittest tools.portfolio.test_build_exports -v
```

Expected: all exporter tests pass.

### Task 2: Expand the Full-Game Allowlist

**Files:**

- Modify: `tools/portfolio/export_manifest.json`
- Modify: `tools/portfolio/test_build_exports.py`

- [ ] **Step 1: Add a manifest contract test**

Add a test that reads the checked-in manifest without resolving private source paths:

```python
def test_greycrown_manifest_contains_complete_runtime_closure(self) -> None:
    manifest_path = Path(__file__).with_name("export_manifest.json")
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    repo = next(
        item
        for item in payload["repositories"]
        if item["name"] == "greycrown-game-ai"
    )
    includes = {
        item if isinstance(item, str) else item["source"]
        for item in repo["include"]
    }
    self.assertTrue(
        {
            "client/project.godot",
            "client/export_presets.cfg",
            "client/assets",
            "client/data",
            "client/dialogic",
            "client/scenes",
            "client/scripts",
            "client/tests",
            "server/src",
            "server/package.json",
            "server/package-lock.json",
            "server/tsconfig.json",
            "server/vitest.config.ts",
            "output/webqa/README.md",
            "output/webqa/run_webqa_regression.ps1",
            "output/webqa/webqa_playwright.spec.js",
        }.issubset(includes)
    )
    self.assertNotIn("references", includes)
    self.assertNotIn("release", includes)
    self.assertNotIn("music", includes)
```

- [ ] **Step 2: Run the contract test and confirm RED**

Run:

```powershell
python -m unittest tools.portfolio.test_build_exports.BuildExportsTests.test_greycrown_manifest_contains_complete_runtime_closure -v
```

Expected: FAIL because the current manifest contains only the AI GM slice.

- [ ] **Step 3: Replace the Greycrown include list**

Use this allowlist for `greycrown-game-ai` in `export_manifest.json`:

```json
"include": [
  "client/project.godot",
  "client/export_presets.cfg",
  "client/assets",
  "client/data",
  "client/dialogic",
  "client/scenes",
  "client/scripts",
  "client/tests",
  "server/src",
  "server/package.json",
  "server/package-lock.json",
  "server/tsconfig.json",
  "server/vitest.config.ts",
  "output/webqa/README.md",
  "output/webqa/run_webqa_regression.ps1",
  "output/webqa/webqa_playwright.spec.js"
],
"exclude": [
  "**/*.bak",
  "**/*.backup",
  "**/*.log",
  "**/*.tmp"
]
```

Do not exclude `.uid` or `.import` files.

- [ ] **Step 4: Validate the real manifest and planned file count**

Run:

```powershell
python tools/portfolio/build_exports.py --manifest tools/portfolio/export_manifest.json --repo greycrown-game-ai --check
```

Expected: `OK greycrown-game-ai` with a nonzero full-project file count.

### Task 3: Add Deterministic Export Sanitization

**Files:**

- Create: `tools/portfolio/sanitize_greycrown_export.py`
- Create: `tools/portfolio/test_sanitize_greycrown_export.py`

- [ ] **Step 1: Write tests for all required replacements**

Create a temporary staged tree containing a project config, AI GM test, server config, and WebQA script. Assert that `sanitize_export()` produces these exact outcomes:

```python
self.assertIn('config/name="Greycrown"', project_text)
self.assertIn(
    'config/description="Card RPG with ritual forging, city exploration, and AI GM"',
    project_text,
)
self.assertNotIn("newgameprogect", project_text)
self.assertIn('var secret := "test-secret-placeholder"', ai_test_text)
self.assertNotIn("sk-slice4-secret-value", ai_test_text)
self.assertIn("adminToken: process.env.M3_ADMIN_TOKEN ?? ''", server_text)
self.assertNotIn("dev-admin-token", server_text)
self.assertIn("Join-Path $PSScriptRoot '..\\..'", webqa_text)
self.assertIn('[string]$GodotExe = ""', webqa_text)
```

Also assert that a missing expected source string raises `SanitizationError`; sanitization must fail closed instead of silently producing an unknown public state.

- [ ] **Step 2: Run the sanitizer tests and confirm RED**

Run:

```powershell
python -m unittest tools.portfolio.test_sanitize_greycrown_export -v
```

Expected: FAIL because the sanitizer module does not exist.

- [ ] **Step 3: Implement `sanitize_export()`**

Implement exact file checks and transformations. Use anchored regular expressions for the two Godot application properties, exact string replacement for the simulated key and admin-token fallback, and these portable WebQA defaults:

```powershell
param(
    [switch]$SkipExport,
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$GodotExe = "",
    [string]$Preset = "Web",
    [int]$Port = 8765
)
```

After the parameter block, resolve Godot from `Get-Command godot` or `Get-Command godot4` when `-GodotExe` is omitted. If neither exists, let the existing WebQA blocker reporting record the missing executable.

The module CLI must accept exactly one staged root:

```python
parser.add_argument("root", type=Path)
sanitize_export(args.root.resolve(strict=True))
```

- [ ] **Step 4: Run the sanitizer tests and confirm GREEN**

Run:

```powershell
python -m unittest tools.portfolio.test_sanitize_greycrown_export -v
```

Expected: all sanitizer tests pass.

### Task 4: Scan Embedded Media Metadata

**Files:**

- Modify: `tools/portfolio/scan_public_repo.py`
- Modify: `tools/portfolio/test_scan_public_repo.py`

- [ ] **Step 1: Add synthetic PNG and MP3 metadata tests**

Create a minimal PNG byte stream with a `tEXt` chunk containing an OpenAI-style test secret and a minimal ID3v2 tag containing a private test email. Assert that the scanner reports only the path, rule, and line fields and never includes the matched values.

```python
self.assertIn("secret.openai_like", {item["rule"] for item in png_findings})
self.assertIn("pii.private_email", {item["rule"] for item in mp3_findings})
self.assertNotIn(secret, str(png_findings))
self.assertNotIn(email, str(mp3_findings))
```

- [ ] **Step 2: Run scanner tests and confirm RED**

Run:

```powershell
python -m unittest tools.portfolio.test_scan_public_repo -v
```

Expected: the new media metadata tests fail because binary metadata is not inspected.

- [ ] **Step 3: Implement bounded metadata extraction**

For PNG files, parse the PNG signature and bounded chunk lengths, collecting `tEXt`, `zTXt`, and `iTXt` payloads. For MP3 files, inspect only the bounded ID3v2 tag declared by the synchsafe header. Decode candidates as UTF-8, Latin-1, UTF-16LE, and UTF-16BE with replacement disabled, then pass successful text through `_iter_text_findings()`.

Do not scan compressed image pixels or MPEG audio frames. Reject metadata chunks larger than 4 MiB to keep scanning bounded.

- [ ] **Step 4: Run all publication-tool tests**

Run:

```powershell
python -m unittest discover -s tools/portfolio -p "test_*.py" -v
```

Expected: all exporter, sanitizer, scanner, and existing document-generation tests pass.

### Task 5: Build and Audit a Fresh Full-Game Stage

**Files:**

- Generate outside Git: sibling directory `greycrown-game-ai-stage/`

- [ ] **Step 1: Verify the staging path is absent**

Resolve the manifest destination and confirm `greycrown-game-ai-stage` does not exist. If it exists, stop and report the exact path; do not delete it automatically.

- [ ] **Step 2: Export the complete working tree**

Run:

```powershell
python tools/portfolio/build_exports.py --manifest tools/portfolio/export_manifest.json --repo greycrown-game-ai --target-name greycrown-game-ai-stage
```

Expected: `EXPORTED greycrown-game-ai` with the planned full-project file count.

- [ ] **Step 3: Sanitize the staged copy**

Run:

```powershell
python tools/portfolio/sanitize_greycrown_export.py github-portfolio/greycrown-game-ai-stage
```

Expected: a success summary naming only transformed relative paths, with no secret values.

- [ ] **Step 4: Verify exact runtime asset counts**

Run PowerShell counts in the staged copy and require:

```text
client/assets/**/*.png = 229
client/assets/**/*.mp3 = 7
```

Also compare every manifest-planned source/destination pair by size and SHA-256 after accounting for the four documented sanitized text files.

- [ ] **Step 5: Scan the staged copy**

Run:

```powershell
python tools/portfolio/scan_public_repo.py github-portfolio/greycrown-game-ai-stage --json output/portfolio-audit/greycrown-stage.json
```

Expected: `finding_count` is zero. The report stays outside the public repository.

### Task 6: Merge the Verified Stage and Rewrite Public Documentation

**Files:**

- Add/replace: `client/**`
- Add/replace: `server/**`
- Add: `output/webqa/README.md`
- Add: `output/webqa/run_webqa_regression.ps1`
- Add: `output/webqa/webqa_playwright.spec.js`
- Modify: `README.md`
- Modify: `.gitignore`
- Create: `.gitattributes`
- Modify: `.env.example`
- Modify: `PORTFOLIO_NOTICE.md`
- Create: `THIRD_PARTY_NOTICES.md`
- Create: `licenses/MPL-2.0.txt`
- Create: `server/README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CONFIGURATION.md`
- Modify: `docs/INTERVIEW_NOTES.md`
- Modify: `docs/VERIFICATION.md`

- [ ] **Step 1: Overlay only verified staged files**

Copy the contents of staged `client/`, `server/`, and the three staged `output/webqa` source files into the public working tree. Do not delete existing public files and do not touch `.git/`. Existing focused runner `client/tests/run_portfolio_tests.gd` may remain alongside the complete test suite.

- [ ] **Step 2: Recheck preserved security hardening**

Require these exact public values after the overlay:

```text
client/tests/unit/ai_gm/test_ai_gm_settings.gd:
  var secret := "test-secret-placeholder"

server/src/core/config.ts:
  adminToken: process.env.M3_ADMIN_TOKEN ?? ''
```

- [ ] **Step 3: Write the complete-game README**

The README must state, without unsupported claims:

- This is the complete runnable Greycrown Godot project, not a feature extract.
- Core systems are card combat, ritual forging, city exploration, NPC/commission loops, tower progression, audio routing, and bounded/offline-capable AI GM narration.
- The TypeScript server is an independently testable authoritative-system prototype and is not required for the current offline client loop.
- Requirements are Godot 4.6.x and Node.js 20+.
- Import path is `client/project.godot`.
- Full Godot and server verification commands are listed.
- Runtime art is included; seven runtime BGM tracks are included; no screenshots are bundled.
- AI-assisted development is disclosed, and the author does not claim every line was independently handwritten.
- Known boundary: real model transport remains disabled by default and no API key is required for normal offline behavior.

- [ ] **Step 4: Write portable configuration and verification docs**

Document `M3_PORT`, `M3_ADMIN_PORT`, and an empty-by-default `M3_ADMIN_TOKEN`. Document WebQA with repository-relative script paths and an optional explicit `-GodotExe` argument. Remove all private source paths and old “portfolio extract” language from public docs.

- [ ] **Step 5: Add licensing and binary attributes**

Keep project-owned code and generated media under `PORTFOLIO_NOTICE.md`. Add `THIRD_PARTY_NOTICES.md` naming `godot-phigros`, Naptie, the source URL, the modified directory, and MPL-2.0. Download the canonical MPL-2.0 text from Mozilla over HTTPS into `licenses/MPL-2.0.txt`, verify that its heading identifies Mozilla Public License Version 2.0, and record its SHA-256 in the local verification output.

Create `.gitattributes`:

```gitattributes
* text=auto
*.gd text eol=lf
*.gdshader text eol=lf
*.json text eol=lf
*.md text eol=lf
*.ts text eol=lf
*.js text eol=lf
*.ps1 text eol=crlf
*.png binary
*.mp3 binary
```

- [ ] **Step 6: Run public-document contradiction searches**

Search the public repository for `feature extract`, `portfolio extract`, `不包含完整`, `AI-only`, private absolute paths, and references to excluded `references/`, `release/`, or raw `music/` directories. Every remaining match must be an intentional historical statement inside the approved design/plan, not an active README or run command.

### Task 7: Verify the Public Repository Itself

**Files:**

- Generated and ignored: `.godot/`, `client/output/`, `server/node_modules/`, `server/dist/`, `output/webqa/artifacts/`
- Update: `docs/VERIFICATION.md` with final summarized evidence only

- [ ] **Step 1: Run the publication scanner**

Run:

```powershell
python tools/portfolio/scan_public_repo.py github-portfolio/greycrown-game-ai --json output/portfolio-audit/greycrown-final.json
```

Expected: `finding_count` is zero.

- [ ] **Step 2: Verify Godot import and project parse**

Run the installed Godot 4.6 console binary with:

```powershell
& $GodotExe --headless --editor --path github-portfolio/greycrown-game-ai/client --quit
```

Expected: exit code 0 and no parse/load error.

- [ ] **Step 3: Run the complete Godot unit suite**

Run:

```powershell
& $GodotExe --headless --path github-portfolio/greycrown-game-ai/client -s res://tests/run_unit_tests.gd
```

Expected: exit code 0 and a final summary with zero failed tests. If the documented intermittent startup hang occurs, run the focused hotfix suites and record the full-suite blocker exactly; do not label an incomplete run as passed.

- [ ] **Step 4: Build and test the TypeScript server**

Run from `server/`:

```powershell
npm ci
npm test
npm run m3:build
```

Expected: Vitest reports zero failures and TypeScript exits 0.

- [ ] **Step 5: Run WebQA from the public copy**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File output/webqa/run_webqa_regression.ps1 -ProjectRoot (Resolve-Path .) -GodotExe $GodotExe
```

Expected: `output/webqa/artifacts/webqa-regression-result.json` has `ok: true` and `webqa-summary.md` has `status: passed`. Review generated images locally, then confirm none are tracked or staged.

- [ ] **Step 6: Update verification evidence and rescan**

Record command names, versions, pass/fail totals, and WebQA status in `docs/VERIFICATION.md` without local absolute paths. Rerun the scanner after the documentation update and require zero findings.

### Task 8: Stage, Audit, Commit, and Push

**Files:**

- Stage all intended complete-game files and publication documentation.

- [ ] **Step 1: Audit tracked file policy before staging**

Require Git to report no tracked or untracked candidate matching:

```text
.env
.godot/
node_modules/
dist/
client/output/
client/saves/
output/webqa/artifacts/
*.exe
*.pck
*.zip
*.log
```

Require exactly 229 tracked PNG files and 7 tracked MP3 files under `client/assets/` after staging.

- [ ] **Step 2: Review the staged change**

Run:

```powershell
git diff --cached --check
git diff --cached --stat
git status --short
```

Expected: no whitespace errors, no generated directories, no screenshots, and only the approved full-game publication scope.

- [ ] **Step 3: Run the final security scan against the exact working tree**

Run the scanner one last time and require zero findings. Verify the Git history contains only the existing sanitized publication commit, the approved design/plan commits, and the new complete-game commit, with no private source history.

- [ ] **Step 4: Commit the complete repository**

Commit with:

```powershell
git commit -m "feat: publish complete Greycrown game"
```

Expected: one commit containing the complete sanitized game update.

- [ ] **Step 5: Push without rewriting history**

Run:

```powershell
git push origin main
```

Expected: a normal fast-forward push succeeds. Do not use `--force` and do not automatically switch to Git LFS if the remote rejects repository size.

- [ ] **Step 6: Verify the remote commit**

Compare local `HEAD` with `git ls-remote origin refs/heads/main`. They must match exactly. Report final tracked file counts, asset counts, test results, commit hash, and repository URL.
