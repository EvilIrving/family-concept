export class KitchenLive {
  private sessions: Set<WebSocket> = new Set();

  async fetch(request: Request): Promise<Response> {
    const upgrade = request.headers.get('Upgrade');

    if (upgrade?.toLowerCase() === 'websocket') {
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);

      server.accept();
      this.sessions.add(server);

      server.addEventListener('close', () => {
        this.sessions.delete(server);
      });

      server.addEventListener('error', () => {
        this.sessions.delete(server);
      });

      return new Response(null, { status: 101, webSocket: client });
    }

    // Internal broadcast: POST with JSON body
    if (request.method === 'POST') {
      const event = await request.json<unknown>();
      const message = JSON.stringify(event);
      for (const ws of this.sessions) {
        try {
          ws.send(message);
        } catch {
          this.sessions.delete(ws);
        }
      }
      return new Response('ok');
    }

    return new Response('Expected WebSocket or POST', { status: 400 });
  }
}
