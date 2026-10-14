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

  Howler.autoUnlock = true
  Howler.volume(volume.value)

  return {
    queue, index, playing, position, duration, volume, current,
    playTrack, play, pause, toggle, next, prev, seek, setVolume,
  }
})
