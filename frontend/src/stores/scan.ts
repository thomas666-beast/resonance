import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export interface ScanEvent {
  event: 'started' | 'progress' | 'reconciling' | 'finished'
  scan_path_id: number
  total?: number
  processed?: number
  inserted?: number
  updated?: number
  failed?: number
  missing?: number
  restored?: number
}

export const useScanStore = defineStore('scan', () => {
  const connected = ref(false)
  const scanning = ref(false)
  const reconciling = ref(false)
  const processed = ref(0)
  const total = ref(0)
  const lastResult = ref<{
    inserted: number
    updated: number
    failed: number
    missing: number
    restored: number
  } | null>(null)

  let ws: WebSocket | null = null
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null
  let backoff = 1000

  const percent = computed(() =>
    total.value > 0 ? Math.min(100, Math.round((processed.value / total.value) * 100)) : 0,
  )

  function connect() {
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
      return
    }

    const token = (window as any).__resonance_access_token
    if (!token) return

    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:'
    const url = `${proto}//${location.host}/api/ws?token=${encodeURIComponent(token)}`

    ws = new WebSocket(url)

    ws.onopen = () => {
      connected.value = true
      backoff = 1000
    }

    ws.onmessage = (e) => {
      try {
        const { data } = JSON.parse(e.data)
        handleEvent(data)
      } catch {
        // ignore malformed frames
      }
    }

    ws.onclose = () => {
      connected.value = false
      ws = null
      scheduleReconnect()
    }

    ws.onerror = () => {
      ws?.close()
    }
  }

  function scheduleReconnect() {
    if (reconnectTimer) return
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null
      backoff = Math.min(backoff * 2, 30000)
      connect()
    }, backoff)
  }

  function disconnect() {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
    ws?.close()
    ws = null
    connected.value = false
  }

  function handleEvent(ev: ScanEvent) {
    if (ev.event === 'started') {
      scanning.value = true
      reconciling.value = false
      total.value = ev.total ?? 0
      processed.value = 0
      lastResult.value = null
    } else if (ev.event === 'progress') {
      scanning.value = true
      processed.value = ev.processed ?? processed.value
      total.value = ev.total ?? total.value
    } else if (ev.event === 'reconciling') {
      scanning.value = false
      reconciling.value = true
    } else if (ev.event === 'finished') {
      scanning.value = false
      reconciling.value = false
      processed.value = ev.total ?? processed.value
      lastResult.value = {
        inserted: ev.inserted ?? 0,
        updated: ev.updated ?? 0,
        failed: ev.failed ?? 0,
        missing: ev.missing ?? 0,
        restored: ev.restored ?? 0,
      }
    }
  }

  return {
    connected, scanning, reconciling, processed, total, percent,
    lastResult, connect, disconnect,
  }
})
