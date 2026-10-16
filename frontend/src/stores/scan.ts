import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { useEventsStore } from './events'
import { useToastStore } from './toast'
import { i18n } from '@/i18n'

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
  const events = useEventsStore()

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

  const percent = computed(() =>
    total.value > 0 ? Math.min(100, Math.round((processed.value / total.value) * 100)) : 0,
  )

  function notifyResult() {
    const r = lastResult.value
    if (!r) return
    const toast = useToastStore()
    const t = i18n.global.t

    if (r.missing > 0) {
      toast.info(t('scan.doneWithMissing', {
        inserted: r.inserted,
        missing:  r.missing,
      }))
    } else {
      toast.success(t('scan.done', {
        inserted: r.inserted,
        updated:  r.updated,
      }))
    }
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
      notifyResult()
    }
  }

  let registered = false

  function connect() {
    if (!registered) {
      events.onMessage((channel, data) => {
        if (channel === 'resonance:scan') handleEvent(data)
      })
      registered = true
    }
    events.connect()
  }

  function disconnect() {
    // The events store is shared; nothing to do here
  }

  return {
    connected, scanning, reconciling, processed, total, percent,
    lastResult, connect, disconnect,
  }
})
