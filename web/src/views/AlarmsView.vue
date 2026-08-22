<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { api } from '../api/client'
import { useRealtimeStore } from '../stores/realtime'
import type { AlarmLog } from '../types/domain'

const route = useRoute()
const realtime = useRealtimeStore()
const records = ref<AlarmLog[]>([])
const status = ref('')

function applyRouteFilter() {
  status.value = typeof route.query.status === 'string' ? route.query.status : ''
}

async function load() {
  const res = await api.listAlarms({ page: 1, pageSize: 50, status: status.value || undefined })
  if (res.code === 200) records.value = res.data.records
}

onMounted(async () => {
  applyRouteFilter()
  await load()
})

watch(
  () => route.query,
  async () => {
    applyRouteFilter()
    await load()
  },
)

watch(
  () => realtime.alarmSyncTick,
  async () => {
    await load()
  },
)

async function resolve(id: number) {
  await api.resolveAlarm(id)
  await load()
}
</script>

<template>
  <div class="card">
    <div class="head">
      <h2>告警日志</h2>
      <select v-model="status" @change="load">
        <option value="">全部状态</option>
        <option value="ACTIVE">ACTIVE</option>
        <option value="RESOLVED">RESOLVED</option>
      </select>
    </div>
    <table>
      <thead>
        <tr>
          <th>时间</th>
          <th>设备</th>
          <th>类型</th>
          <th>内容</th>
          <th>状态</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="a in records" :key="a.id">
          <td class="mono">{{ a.createdAt }}</td>
          <td>{{ a.deviceName }}</td>
          <td class="mono">{{ a.alarmType }}</td>
          <td>{{ a.message }}</td>
          <td>{{ a.status }}</td>
          <td>
            <button v-if="a.status === 'ACTIVE'" type="button" @click="resolve(a.id)">解决</button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.card {
  background: var(--panel);
  border: 1px solid var(--line);
  padding: 18px;
  border-radius: var(--radius);
}
.head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}
h2 {
  font-size: 24px;
}
select,
button {
  font: inherit;
  padding: 8px 10px;
  border: 1px solid var(--line);
  border-radius: var(--radius);
  background: #fff;
  cursor: pointer;
}
button {
  background: var(--steel);
  color: #fff;
  border-color: var(--steel);
}
table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}
th,
td {
  text-align: left;
  padding: 9px 6px;
  border-bottom: 1px solid var(--line);
}
</style>
