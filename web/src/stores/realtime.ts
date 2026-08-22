import { Client } from '@stomp/stompjs'
import { defineStore } from 'pinia'
import { onScopeDispose, ref } from 'vue'
import { isMockMode } from '../api/client'
import { mockTickLight } from '../api/mock'
import type { AlarmLog, LatestLight } from '../types/domain'
import { useAuthStore } from './auth'

/** 后端部分路径将 deviceId 序列化为 string，前端统一为 number */
function normalizeLatestLight(raw: LatestLight & { deviceId?: number | string }): LatestLight {
  return {
    ...raw,
    deviceId: typeof raw.deviceId === 'string' ? Number(raw.deviceId) : raw.deviceId,
  }
}

/**
 * Seam: STOMP `/ws?token=` → topics。
 * Mock 模式用定时器模拟光照推送。
 */
export const useRealtimeStore = defineStore('realtime', () => {
  const connected = ref(false)
  const latestLight = ref<LatestLight | null>(null)
  const latestAlarm = ref<AlarmLog | null>(null)
  /** 设备开关/在线状态变更时递增，供总览与设备页 watch 刷新 */
  const deviceSyncTick = ref(0)
  /** 新告警时递增，供告警页 watch 刷新 */
  const alarmSyncTick = ref(0)
  let client: Client | null = null
  let timer: number | undefined

  function bumpDeviceSync() {
    deviceSyncTick.value += 1
  }

  function connect() {
    disconnect()
    if (isMockMode) {
      connected.value = true
      timer = window.setInterval(() => {
        latestLight.value = mockTickLight()
        bumpDeviceSync()
      }, 3000)
      return
    }

    const auth = useAuthStore()
    const token = auth.session?.token
    if (!token) return

    const wsBase = (import.meta.env.VITE_WS_BASE as string) || `ws://${location.hostname}:8080`
    client = new Client({
      brokerURL: `${wsBase}/ws?token=${encodeURIComponent(token)}`,
      reconnectDelay: 4000,
      onConnect: () => {
        connected.value = true
        client?.subscribe('/topic/light-readings', (msg) => {
          const body = JSON.parse(msg.body) as { data: LatestLight & { deviceId?: number | string } }
          latestLight.value = normalizeLatestLight(body.data)
        })
        client?.subscribe('/topic/alarms', (msg) => {
          const body = JSON.parse(msg.body) as { data: AlarmLog }
          latestAlarm.value = body.data
          alarmSyncTick.value += 1
        })
        client?.subscribe('/topic/device-status', () => {
          bumpDeviceSync()
        })
        client?.subscribe('/topic/device-online', () => {
          bumpDeviceSync()
        })
      },
      onDisconnect: () => {
        connected.value = false
      },
      onStompError: () => {
        connected.value = false
      },
    })
    client.activate()
  }

  function disconnect() {
    if (timer) window.clearInterval(timer)
    timer = undefined
    client?.deactivate()
    client = null
    connected.value = false
  }

  function clearAlarmToast() {
    latestAlarm.value = null
  }

  onScopeDispose(disconnect)

  return {
    connected,
    latestLight,
    latestAlarm,
    deviceSyncTick,
    alarmSyncTick,
    connect,
    disconnect,
    clearAlarmToast,
  }
})
