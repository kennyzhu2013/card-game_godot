import { createM3App } from './app.js';

void main();

async function main(): Promise<void> {
  const app = await createM3App();

  console.log(`M3 WebSocket listening on ws://127.0.0.1:${app.wsPort}`);
  console.log(`M3 admin listening on http://127.0.0.1:${app.adminPort}`);

  async function shutdown(): Promise<void> {
    await app.stop();
    process.exit(0);
  }

  process.once('SIGINT', () => {
    void shutdown();
  });
  process.once('SIGTERM', () => {
    void shutdown();
  });
}
