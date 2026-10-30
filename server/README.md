# Greycrown TypeScript Server

This directory contains an independently testable authoritative game-server prototype for Greycrown. The current Godot client can run offline without it.

## Requirements

- Node.js 20+
- npm

## Setup and Verification

```powershell
npm ci
npm test
npm run m3:build
```

Development start:

```powershell
npm run m3:dev
```

Compiled start:

```powershell
npm run m3:build
npm run m3:start
```

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `M3_PORT` | `3001` | WebSocket gateway port |
| `M3_ADMIN_PORT` | `3002` | Local admin-inspection port |
| `M3_ADMIN_TOKEN` | empty | Bearer token; empty disables admin routes |

The process reads environment variables directly. It does not automatically load a local `.env` file.

## Current Protocol Surface

Client operations include authentication, world entry, movement, world interaction, combat action and chat. Server events include login results, snapshots, deltas, movement corrections, combat locks and chat messages.

The server also contains AOI, snapshot scheduling, monster runtime/AI, combat locking, content-extension registries and an authenticated local state inspector.

## Security Boundary

- Payload validators reject malformed and out-of-range input before world systems receive it.
- Session state controls which operations are valid before and after authentication/world entry.
- Rate limits are applied per operation.
- Admin routes return `503 ADMIN_DISABLED` when `M3_ADMIN_TOKEN` is empty.
- Development tokens and in-memory storage are prototype boundaries, not production identity or persistence systems.
