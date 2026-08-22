import type { ApiResult } from '../types/domain'
import { createMockApi } from './mock'
import type { StreetLightApi } from './types'

const mode = (import.meta.env.VITE_API_MODE as string) || 'mock'
const base = (import.meta.env.VITE_API_BASE as string) || ''
const SESSION_KEY = 'streetlight.session'

function token(): string | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY)
    return raw ? (JSON.parse(raw) as { token: string }).token : null
  } catch {
    return null
  }
}

function handleUnauthorized() {
  localStorage.removeItem(SESSION_KEY)
  const loginPath = '/login'
  if (!window.location.pathname.endsWith(loginPath)) {
    window.location.assign(`${loginPath}?expired=1`)
  }
}

async function http<T>(path: string, init: RequestInit = {}): Promise<ApiResult<T>> {
  const headers = new Headers(init.headers)
  headers.set('Content-Type', 'application/json')
  const t = token()
  if (t) headers.set('token', t)
  const res = await fetch(`${base}${path}`, { ...init, headers })
  const body = (await res.json()) as ApiResult<T>
  if (res.status === 401 || body.code === 401) {
    handleUnauthorized()
    throw new Error(body.errorMsg || '登录已过期，请重新登录')
  }
  return body
}

function createHttpApi(): StreetLightApi {
  const q = (params: Record<string, unknown>) => {
    const sp = new URLSearchParams()
    Object.entries(params).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') sp.set(k, String(v))
    })
    const s = sp.toString()
    return s ? `?${s}` : ''
  }

  return {
    register: (username, password, role) =>
      http('/users/register', {
        method: 'POST',
        body: JSON.stringify({ username, password, role }),
      }),
    login: (username, password) =>
      http('/users/login', {
        method: 'POST',
        body: JSON.stringify({ username, password }),
      }),
    listDevices: (params) => http(`/devices${q({ page: 1, pageSize: 10, ...params })}`),
    getDevice: (id) => http(`/devices/${id}`),
    addDevice: (body) => http('/devices', { method: 'POST', body: JSON.stringify(body) }),
    updateDevice: (id, body) =>
      http(`/devices/${id}`, { method: 'PUT', body: JSON.stringify(body) }),
    deleteDevice: (id) => http(`/devices/${id}`, { method: 'DELETE' }),
    deviceStatistics: () => http('/devices/statistics'),
    switchDevice: (id, status) =>
      http(`/devices/${id}/switch`, { method: 'POST', body: JSON.stringify({ status }) }),
    listLightReadings: (params) =>
      http(`/light-readings${q({ page: 1, pageSize: 10, ...params })}`),
    latestLight: (deviceId) => http(`/light-readings/latest/${deviceId}`),
    lightTrend: (deviceId, startTime, endTime) =>
      http(`/light-readings/trend${q({ deviceId, startTime, endTime })}`),
    listAlarms: (params) => http(`/alarm-logs${q({ page: 1, pageSize: 10, ...params })}`),
    resolveAlarm: (id) => http(`/alarm-logs/${id}/resolve`, { method: 'PUT' }),
    alarmStatistics: () => http('/alarm-logs/statistics'),
    getThreshold: () => http('/threshold-config'),
    updateThreshold: (body) =>
      http('/threshold-config', { method: 'PUT', body: JSON.stringify(body) }),
    listControlLogs: (params) =>
      http(`/control-logs${q({ page: 1, pageSize: 10, ...params })}`),
  }
}

export const api: StreetLightApi = mode === 'http' ? createHttpApi() : createMockApi()
export const isMockMode = mode !== 'http'
