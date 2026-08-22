<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { api } from '../api/client'
import type { Device, LightReading, TrendPoint } from '../types/domain'
import { todayRange } from '../utils/datetime'

const devices = ref<Device[]>([])
const deviceId = ref<number>(1)
const records = ref<LightReading[]>([])
const trend = ref<TrendPoint[]>([])

const maxVal = computed(() => Math.max(1, ...trend.value.map((t) => t.value)))

async function loadDevices() {
  const res = await api.listDevices({ page: 1, pageSize: 100 })
  if (res.code === 200) {
    devices.value = res.data.records
    deviceId.value = devices.value[0]?.id ?? 1
  }
}

async function load() {
  const { start, end } = todayRange()
  const [list, tr] = await Promise.all([
    api.listLightReadings({ page: 1, pageSize: 20, deviceId: deviceId.value }),
    api.lightTrend(deviceId.value, start, end),
  ])
  if (list.code === 200) records.value = list.data.records
  if (tr.code === 200) trend.value = tr.data
}

onMounted(async () => {
  await loadDevices()
  await load()
})
</script>

<template>
  <div class="page">
    <label>
      设备
      <select v-model.number="deviceId" @change="load">
        <option v-for="d in devices" :key="d.id" :value="d.id">{{ d.deviceName }}</option>
      </select>
    </label>

    <section class="card">
      <h2>光照趋势</h2>
      <div class="chart">
        <div
          v-for="(p, i) in trend"
          :key="i"
          class="bar"
          :style="{ height: `${(p.value / maxVal) * 100}%` }"
          :title="`${p.time} · ${p.value.toFixed(1)}`"
        />
      </div>
    </section>

    <section class="card">
      <h2>最近记录</h2>
      <table>
        <thead>
          <tr>
            <th>时间</th>
            <th>设备</th>
            <th>光照</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in records" :key="r.id">
            <td class="mono">{{ r.createdAt }}</td>
            <td>{{ r.deviceName }}</td>
            <td class="mono">{{ r.lightIntensity.toFixed(1) }}</td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>

<style scoped>
.page {
  display: grid;
  gap: 14px;
}
label {
  display: grid;
  gap: 6px;
  max-width: 280px;
  font-size: 13px;
  color: var(--ink-soft);
}
select {
  font: inherit;
  padding: 8px 10px;
  border: 1px solid var(--line);
  border-radius: var(--radius);
}
.card {
  background: var(--panel);
  border: 1px solid var(--line);
  padding: 18px;
  border-radius: var(--radius);
}
h2 {
  font-size: 22px;
  margin-bottom: 12px;
}
.chart {
  display: flex;
  align-items: end;
  gap: 4px;
  height: 160px;
  padding: 8px;
  background: #121820;
  border-radius: var(--radius);
}
.bar {
  flex: 1;
  min-width: 6px;
  background: linear-gradient(180deg, var(--sodium), #7a5200);
  border-radius: 2px 2px 0 0;
  transition: height 0.25s ease;
}
table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}
th,
td {
  text-align: left;
  padding: 8px 6px;
  border-bottom: 1px solid var(--line);
}
</style>
