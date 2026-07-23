import { getServerStats } from '../../utils/serverStats';

const INTERVAL_MS = 2000;
const timers = new Map<string, ReturnType<typeof setInterval>>();

function pushStats(peer: { id: string; send: (data: string) => void }) {
  peer.send(
    JSON.stringify({
      type: 'server-stats',
      data: getServerStats()
    })
  );
}

export default defineWebSocketHandler({
  open(peer) {
    pushStats(peer);

    const timer = setInterval(() => {
      try {
        pushStats(peer);
      } catch {
        clearInterval(timer);
        timers.delete(peer.id);
      }
    }, INTERVAL_MS);

    timers.set(peer.id, timer);
  },

  close(peer) {
    const timer = timers.get(peer.id);
    if (timer) {
      clearInterval(timer);
      timers.delete(peer.id);
    }
  },

  error(peer) {
    const timer = timers.get(peer.id);
    if (timer) {
      clearInterval(timer);
      timers.delete(peer.id);
    }
  }
});
