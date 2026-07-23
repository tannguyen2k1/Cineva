import os from 'os';
import { statfsSync } from 'node:fs';

export type ServerStats = {
  cpu: number;
  cpuCores: number;
  ram: number;
  ramUsed: number;
  ramTotal: number;
  disk: number;
  diskUsed: number;
  diskTotal: number;
  updatedAt: string;
};

let demoCpu = 12;

function getDiskBytes(): { used: number; total: number } {
  try {
    const root = os.platform() === 'win32' ? 'C:\\' : '/';
    const stats = statfsSync(root);
    const total = Number(stats.blocks) * Number(stats.bsize);
    const free = Number(stats.bfree) * Number(stats.bsize);
    const used = Math.max(0, total - free);
    if (total > 0) return { used, total };
  } catch {
    // fall through
  }

  // Fallback demo values if statfs unavailable
  const total = 256 * 1024 * 1024 * 1024;
  const used = Math.round(total * 0.42);
  return { used, total };
}

export function getServerStats(): ServerStats {
  const ramTotal = os.totalmem();
  const ramUsed = ramTotal - os.freemem();
  const ram = Math.round((ramUsed / ramTotal) * 100);

  const cpuCores = Math.max(os.cpus().length, 1);
  const loadAvg = os.loadavg()[0] || 0;
  let cpu = Math.min(Math.round((loadAvg / cpuCores) * 100), 100);

  if (cpu === 0 && os.platform() === 'win32') {
    demoCpu = Math.min(90, Math.max(5, demoCpu + (Math.random() - 0.48) * 10));
    cpu = Math.round(demoCpu);
  }

  const disk = getDiskBytes();
  const diskPercent = disk.total > 0 ? Math.round((disk.used / disk.total) * 100) : 0;

  return {
    cpu,
    cpuCores,
    ram,
    ramUsed,
    ramTotal,
    disk: diskPercent,
    diskUsed: disk.used,
    diskTotal: disk.total,
    updatedAt: new Date().toISOString()
  };
}
