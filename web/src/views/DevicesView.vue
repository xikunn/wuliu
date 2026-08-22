<script setup lang="ts">
import { onMounted, reactive, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { api } from '../api/client'
import { useRealtimeStore } from '../stores/realtime'
import type { Device } from '../types/domain'

const route = useRoute()
const realtime = useRealtimeStore()
const records = ref<Device[]>([])
const total = ref(0)
const msg = ref('')
const form = reactive({ deviceName: '', deviceSn: '' })
const filter = reactive({ deviceName: '', status: '', onlineStatus: '' })

function applyRouteFilter() {
  filter.status = typeof route.query.status === 'string' ? route.query.status : ''
  filter.onlineStatus =
    typeof route.query.onlineStatus === 'string' ? route.query.onlineStatus : ''
}

async function load() {
  const res = await api.listDevices({ page: 1, pageSize: 50, ...filter })
  if (res.code === 200) {
    records.value = res.data.records
    total.value = res.data.total
  }
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
  () => realtime.deviceSyncTick,
  async () => {
    await load()
  },
)

async function add() {
  const res = await api.addDevice({ ...form })
  msg.value = res.code === 200 ? res.data : res.errorMsg || '失败'
  if (res.code === 200) {
    form.deviceName = ''
    form.deviceSn = ''
    await load()
  }
}

async function toggle(d: Device) {
  const next = d.status === 'ON' ? 'OFF' : 'ON'
  const res = await api.switchDevice(d.id, next)
  msg.value = res.code === 200 ? `已下发 ${res.data.command}` : res.errorMsg || '失败'
  await load()
}

async function remove(id: number) {
  await api.deleteDevice(id)
  await load()
}
</script>

<template>
  <div class="page">
    <section class="card">
      <h2>添加设备</h2>
      <div class="row">
        <input v-model="form.deviceName" placeholder="设备名称" />
        <input v-model="form.deviceSn" placeholder="deviceSn / MQTT 标识" class="mono" />
        <button type="button" @click="add">添加</button>
      </div>
      <p v-if="msg" class="msg">{{ msg }}</p>
    </section>

    <section class="card">
      <h2>设备列表 <span class="mono">({{ total }})</span></h2>
      <div class="row">
        <input v-model="filter.deviceName" placeholder="名称筛选" @keyup.enter="load" />
        <select v-model="filter.status" @change="load">
          <option value="">开关·全部</option>
          <option value="ON">ON</option>
          <option value="OFF">OFF</option>
        </select>
        <select v-model="filter.onlineStatus" @change="load">
          <option value="">在线·全部</option>
          <option value="ONLINE">ONLINE</option>
          <option value="OFFLINE">OFFLINE</option>
        </select>
        <button type="button" class="ghost" @click="load">刷新</button>
      </div>
      <table>
        <thead>
          <tr>
            <th>名称</th>
            <th>SN</th>
            <th>开关</th>
            <th>在线</th>
            <th>心跳</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="d in records" :key="d.id">
            <td>{{ d.deviceName }}</td>
            <td class="mono">{{ d.deviceSn }}</td>
            <td>
              <span class="pill" :data-on="d.status === 'ON'">{{ d.status }}</span>
            </td>
            <td>{{ d.onlineStatus }}</td>
            <td class="mono">{{ d.lastHeartbeatTime || '—' }}</td>
            <td class="actions">
              <button type="button" @click="toggle(d)">
                {{ d.status === 'ON' ? '关灯' : '开灯' }}
              </button>
              <button type="button" class="danger" @click="remove(d.id)">删除</button>
            </td>
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
.card {
  background: var(--panel);
  border: 1px solid var(--line);
  padding: 18px;
  border-radius: var(--radius);
}
h2 {
  font-size: 24px;
  margin-bottom: 12px;
}
.row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 10px;
}
input,
select,
button {
  font: inherit;
  padding: 8px 10px;
  border: 1px solid var(--line);
  border-radius: var(--radius);
  background: #fff;
}
button {
  background: var(--steel);
  color: #fff;
  border-color: var(--steel);
  cursor: pointer;
}
.ghost {
  background: #fff;
  color: var(--ink);
}
.danger {
  background: transparent;
  color: var(--danger);
  border-color: var(--danger);
}
.msg {
  color: var(--online);
  font-size: 13px;
}
table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}
th,
td {
  text-align: left;
  padding: 10px 6px;
  border-bottom: 1px solid var(--line);
}
.pill {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 999px;
  background: #dde;
  font-family: var(--font-mono);
  font-size: 12px;
}
.pill[data-on='true'] {
  background: rgba(240, 162, 2, 0.28);
  color: var(--sodium-deep);
}
.actions {
  display: flex;
  gap: 6px;
}
</style>
