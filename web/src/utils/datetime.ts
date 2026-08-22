/** 后端时间格式：yyyy-MM-dd HH:mm:ss */
function pad(n: number) {
  return String(n).padStart(2, '0')
}

export function formatBackendTime(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}

/** 当天 00:00:00 — 23:59:59，供 trend / 列表筛选 */
export function todayRange(now = new Date()) {
  const start = new Date(now)
  start.setHours(0, 0, 0, 0)
  const end = new Date(now)
  end.setHours(23, 59, 59, 999)
  return { start: formatBackendTime(start), end: formatBackendTime(end) }
}
