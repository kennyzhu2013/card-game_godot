# BGM 占位目录

## 锻造 BGM 槽位

| 文件名 | 用途 | 时长建议 | 风格 |
|--------|------|----------|------|
| `forge_ambient.wav` | 符文排列阶段背景 | 60s loop | 低音氛围，缓慢脉动 |
| `forge_rhythm.wav` | 锻造敲击阶段背景 | 120s | 节奏清晰，120-140 BPM |
| `forge_result.wav` | 锻造结果展示 | 15s | 根据品质变化（废品低沉/极品高扬） |
| `hub_ambient.wav` | 洞府背景 | 60s loop | 温暖，神秘感 |
| `tower_ambient.wav` | 爬塔背景 | 60s loop | 紧张，上升感 |

## 接入方式

1. 将 WAV 文件放入此目录
2. BgmPlayer 自动通过 `load_stream()` 加载 `res://assets/audio/bgm/<filename>`
3. 调用 `play_loop(volume_db)` 播放

## MVP 占位方案

目前使用静默（无 BGM 文件）。当 WAV 文件到位后，forge_stage.gd 的 `_ready()` 会自动尝试加载对应 BGM。
