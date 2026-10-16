import { defineStore } from 'pinia'
import { ref } from 'vue'

type EventHandler = (channel: string, data: any) => void

export const useEventsStore = defineStore('events', () => {
  const connected = ref(false)

  let ws: WebSocket | null = null
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null
  let backoff = 1000

  const handlers = new Set<EventHandler>()

  function onMessage(fn: EventHandler) {
    handlers.add(fn)
    return () => handlers.delete(fn)
  }

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
        const { channel, data } = JSON.parse(e.data)
        let parsed = data
        if (typeof data === 'string') {
          try { parsed = JSON.parse(data) } catch { /* keep as string */ }
        }
        for (const fn of handlers) {
          try { fn(channel, parsed) } catch { /* ignore handler errors */ }
        }
      } catch {
        // ignore malformed frames
      }
    }

    ws.onclose = () => {
      connected.value = false
      ws = null
      scheduleReconnect()
    }

    ws.onerror = () => ws?.close()
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

  return { connected, connect, disconnect, onMessage }
})
