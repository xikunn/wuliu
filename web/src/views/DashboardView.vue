<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink } from 'vue-router'
import { api, isMockMode } from '../api/client'
import { useRealtimeStore } from '../stores/realtime'
import type { AlarmStatistics, DeviceStatistics } from '../types/domain'

const realtime = useRealtimeStore()
const stats = ref<DeviceStatistics | null>(null)
const alarmStats = ref<AlarmStatistics | null>(null)

async function load() {
  const [d, a] = await Promise.all([api.deviceStatistics(), api.alarmStatistics()])
  if (d.code === 200) stats.value = d.data
  if (a.code === 200) alarmStats.value = a.data
}

onMounted(load)

watch(
  () => [realtime.deviceSyncTick, realtime.alarmSyncTick],
  () => {
    load()
  },
)

const tiles = computed(() => {
  if (!stats.value) return []
  return [
    { label: '设备总数', value: stats.value.totalCount, to: '/devices' },
    {
      label: '在线',
      value: stats.value.onlineCount,
      to: '/devices',
      query: { onlineStatus: 'ONLINE' },
      tone: 'ok',
    },
    {
      label: '离线',
      value: stats.value.offlineCount,
      to: '/devices',
      query: { onlineStatus: 'OFFLINE' },
    },
    {
      label: '已开灯',
      value: stats.value.onCount,
      to: '/devices',
      query: { status: 'ON' },
      tone: 'on',
    },
    {
      label: '已关灯',
      value: stats.value.offCount,
      to: '/devices',
      query: { status: 'OFF' },
    },
  ]
})

const alarmTile = computed(() => ({
  label: '待处理告警',
  value: alarmStats.value?.activeCount ?? 0,
}))
</script>

<template>
  <div class="page">
    <RouterLink to="/lights" class="hero-strip link-card">
      <div>
        <p class="label">实时光照 · 点击查看趋势</p>
        <p class="big mono">
          {{ realtime.latestLight ? realtime.latestLight.lightIntensity.toFixed(1) : '—' }}
          <span>lux</span>
        </p>
        <p class="mode mono">{{ isMockMode ? 'Mock' : 'WebSocket' }}</p>
      </div>
      <p class="hint">低于开灯阈值自动开灯；高于关灯阈值自动关灯（后端判定）。</p>
    </RouterLink>

    <div class="grid" v-if="stats">
      <RouterLink
        v-for="tile in tiles"
        :key="tile.label"
        :to="{ path: tile.to, query: tile.query }"
        class="stat link-card"
      >
        <p>{{ tile.label }}</p>
        <strong :class="tile.tone">{{ tile.value }}</strong>
      </RouterLink>

      <RouterLink
        :to="{ path: '/alarms', query: { status: 'ACTIVE' } }"
        class="stat link-card"
      >
        <p>{{ alarmTile.label }}</p>
        <strong class="bad">{{ alarmTile.value }}</strong>
      </RouterLink>
    </div>
  </div>
</template>

<style scoped>
.page {
  display: grid;
  gap: 16px;
}
.link-card {
  text-decoration: none;
  color: inherit;
  transition: border-color 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
}
.link-card:hover {
  border-color: var(--sodium);
  box-shadow: var(--shadow);
}
.link-card:active {
  transform: translateY(1px);
}
.hero-strip {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: end;
  padding: 22px;
  background: #121820;
  color: #f2f4f7;
  border-radius: var(--radius);
  box-shadow: var(--shadow);
  border: 1px solid transparent;
}
.label {
  margin: 0;
  font-size: 12px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  opacity: 0.65;
}
.mode {
  margin: 8px 0 0;
  font-size: 11px;
  opacity: 0.45;
}
.big {
  margin: 6px 0 0;
  font-size: 56px;
  font-family: var(--font-display);
  color: var(--sodium);
  line-height: 1;
}
.big span {
  font-size: 18px;
  margin-left: 6px;
  opacity: 0.7;
}
.hint {
  margin: 0;
  max-width: 28ch;
  font-size: 14px;
  opacity: 0.75;
  line-height: 1.45;
}
.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
}
.stat {
  background: var(--panel);
  border: 1px solid var(--line);
  padding: 16px;
  border-radius: var(--radius);
  display: block;
}
.stat p {
  margin: 0;
  color: var(--ink-soft);
  font-size: 13px;
}
.stat strong {
  display: block;
  margin-top: 8px;
  font-family: var(--font-display);
  font-size: 36px;
}
.ok {
  color: var(--online);
}
.on {
  color: var(--sodium-deep);
}
.bad {
  color: var(--danger);
}
@media (max-width: 800px) {
  .grid {
    grid-template-columns: 1fr 1fr;
  }
  .hero-strip {
    flex-direction: column;
    align-items: start;
  }
}
</style>
