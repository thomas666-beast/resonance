import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { Howl, Howler } from 'howler'
import api from '@/api/client'

export interface Track {
  id: number
  title: string
  track_number: number | null
  disc_number: number | null
  duration_ms: number | null
  album_id: number | null
  album_title: string | null
  artist_id: number | null
  artist_name: string | null
}

export const usePlayerStore = defineStore('player', () => {
  const queue = ref<Track[]>([])
  const index = ref(-1)
  const playing = ref(false)
  const position = ref(0)
  const duration = ref(0)
  const volume = ref(Number(localStorage.getItem('resonance_volume') ?? 1))

  let howl: Howl | null = null
  let rafId: number | null = null
  let loggedFor: number | null = null

  const current = computed<Track | null>(() => {
    const i = index.value
    if (i < 0 || i >= queue.value.length) return null
    return queue.value[i] ?? null
  })

  const upcoming = computed<Track[]>(() => {
    if (index.value < 0) return []
    return queue.value.slice(index.value + 1)
  })

  const played = computed<Track[]>(() => {
    if (index.value <= 0) return []
    return queue.value.slice(0, index.value)
  })

  function stopTicker() {
    if (rafId !== null) {
      cancelAnimationFrame(rafId)
      rafId = null
    }
  }

  function tick() {
    if (howl && playing.value) {
      const s = howl.seek()
      if (typeof s === 'number') position.value = s
    }
    rafId = requestAnimationFrame(tick)
  }

  async function logPlay(trackId: number) {
    if (loggedFor === trackId) return
    loggedFor = trackId
    try {
      await api.post(`/plays/${trackId}`)
    } catch {
      // silent — play logging is best-effort
    }
  }

  function load(track: Track) {
    if (howl) {
      howl.unload()
      howl = null
    }
    stopTicker()

    const token = (window as any).__resonance_access_token

    howl = new Howl({
      src: [`/api/stream/${track.id}?token=${encodeURIComponent(token ?? '')}`],
      html5: true,
      volume: volume.value,
      onload: () => { duration.value = howl?.duration() ?? 0 },
      onplay: () => {
        playing.value = true
        tick()
        logPlay(track.id)
      },
      onpause: () => { playing.value = false; stopTicker() },
      onstop: () => { playing.value = false; stopTicker() },
      onend: () => {
        playing.value = false
        stopTicker()
        next()
      },
    })

    position.value = 0
    duration.value = 0
    howl.play()
  }

  function playTrack(track: Track, newQueue: Track[] = [track]) {
    if (track.id !== loggedFor) loggedFor = null
    queue.value = newQueue
    index.value = newQueue.findIndex((t) => t.id === track.id)
    load(track)
  }

  function play() {
    const cur = current.value
    if (!howl && cur) {
      load(cur)
    } else if (howl) {
      howl.play()
    }
  }

  function pause() { howl?.pause() }

  function toggle() {
    playing.value ? pause() : play()
  }

  function next() {
    const nextIndex = index.value + 1
    if (nextIndex >= queue.value.length) {
      pause()
      return
    }
    const t = queue.value[nextIndex]
    if (!t) return
    index.value = nextIndex
    loggedFor = null
    load(t)
  }

  function prev() {
    if (index.value <= 0) return
    const prevIndex = index.value - 1
    const t = queue.value[prevIndex]
    if (!t) return
    index.value = prevIndex
    loggedFor = null
    load(t)
  }

  function seek(seconds: number) {
    if (!howl) return
    howl.seek(seconds)
    position.value = seconds
  }

  function setVolume(v: number) {
    volume.value = v
    Howler.volume(v)
    localStorage.setItem('resonance_volume', String(v))
  }

  // ── queue operations ───────────────────────────────────

  function _reindexByCurrentTrackId(currentId: number | undefined, fallbackIndex: number) {
    if (currentId === undefined) {
      index.value = Math.min(fallbackIndex, queue.value.length - 1)
      return
    }
    const found = queue.value.findIndex((t) => t.id === currentId)
    index.value = found
  }

  function jumpTo(targetIndex: number) {
    const t = queue.value[targetIndex]
    if (!t) return
    index.value = targetIndex
    loggedFor = null
    load(t)
  }

  function removeAt(targetIndex: number) {
    if (targetIndex < 0 || targetIndex >= queue.value.length) return

    // If removing the current track, keep playing it but detach from the queue list
    const isCurrent = targetIndex === index.value
    const currentId = current.value?.id

    queue.value.splice(targetIndex, 1)

    if (isCurrent) {
      // The current track is no longer in the queue.
      // Leave playback going, position the index at the "next" slot.
      if (index.value >= queue.value.length) {
        // was last — keep playing but nothing else queued
        index.value = queue.value.length
      }
      // else: index stays put, now points to what was next
      return
    }

    // Recompute index for the still-playing current track
    if (targetIndex < index.value) {
      index.value -= 1
    } else {
      _reindexByCurrentTrackId(currentId, index.value)
    }
  }

  function move(from: number, to: number) {
    if (from === to) return
    if (from < 0 || from >= queue.value.length) return
    if (to < 0 || to >= queue.value.length) return

    const currentId = current.value?.id
    const wasCurrent = from === index.value

    const [item] = queue.value.splice(from, 1)
    if (!item) return
    queue.value.splice(to, 0, item)

    if (wasCurrent) {
      index.value = to
      return
    }

    // Adjust index for the still-playing current track
    if (from < index.value && to >= index.value) {
      index.value -= 1
    } else if (from > index.value && to <= index.value) {
      index.value += 1
    } else {
      _reindexByCurrentTrackId(currentId, index.value)
    }
  }

  function clearUpcoming() {
    if (index.value < 0) {
      queue.value = []
      return
    }
    queue.value = queue.value.slice(0, index.value + 1)
  }

  function stop() {
    if (howl) {
      howl.stop()
      howl.unload()
      howl = null
    }
    stopTicker()
    playing.value = false
    position.value = 0
    duration.value = 0
    queue.value = []
    index.value = -1
    loggedFor = null
  }

  Howler.autoUnlock = true
  Howler.volume(volume.value)

  return {
    queue, index, playing, position, duration, volume,
    current, upcoming, played,
    playTrack, play, pause, toggle, next, prev, seek, setVolume,
    jumpTo, removeAt, move, clearUpcoming, stop,
  }
})
