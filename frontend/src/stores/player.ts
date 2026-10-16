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

export interface RadioStation {
  id: number
  name: string
  stream_url: string
  homepage_url: string | null
  logo_url: string | null
  genre: string | null
  bitrate: number | null
}

export interface PodcastEpisode {
  id: number
  title: string
  audio_url: string
  duration_sec: number | null
  feed_id: number
  feed_title: string | null
  image_url: string | null
  feed_image_url: string | null
}

const LOADING_TIMEOUT_MS = 15000

export const usePlayerStore = defineStore('player', () => {
  const queue      = ref<Track[]>([])
  const index      = ref(-1)
  const playing    = ref(false)
  const loading    = ref(false)
  const position   = ref(0)
  const duration   = ref(0)
  const volume     = ref(Number(localStorage.getItem('resonance_volume') ?? 1))

  const source          = ref<'library' | 'radio' | 'podcast'>('library')
  const currentRadio    = ref<RadioStation | null>(null)
  const currentEpisode  = ref<PodcastEpisode | null>(null)

  let howl: Howl | null = null
  let rafId: number | null = null
  let progressTimer: ReturnType<typeof setInterval> | null = null
  let loadingTimer: ReturnType<typeof setTimeout> | null = null
  let loggedFor: number | null = null

  const current = computed<Track | null>(() => {
    if (source.value !== 'library') return null
    const i = index.value
    if (i < 0 || i >= queue.value.length) return null
    return queue.value[i] ?? null
  })

  const upcoming = computed<Track[]>(() => {
    if (source.value !== 'library') return []
    if (index.value < 0) return []
    return queue.value.slice(index.value + 1)
  })

  const played = computed<Track[]>(() => {
    if (source.value !== 'library') return []
    if (index.value <= 0) return []
    return queue.value.slice(0, index.value)
  })

  const isLive    = computed(() => source.value === 'radio')
  const isPodcast = computed(() => source.value === 'podcast')

  function stopTicker() {
    if (rafId !== null) {
      cancelAnimationFrame(rafId)
      rafId = null
    }
  }

  function stopProgressTimer() {
    if (progressTimer) {
      clearInterval(progressTimer)
      progressTimer = null
    }
  }

  function startLoading() {
    loading.value = true
    if (loadingTimer) clearTimeout(loadingTimer)
    loadingTimer = setTimeout(() => {
      loading.value = false
      loadingTimer = null
    }, LOADING_TIMEOUT_MS)
  }

  function stopLoading() {
    loading.value = false
    if (loadingTimer) {
      clearTimeout(loadingTimer)
      loadingTimer = null
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
      // silent
    }
  }

  // ── library track ────────────────────────────────────

  function load(track: Track) {
    if (howl) { howl.unload(); howl = null }
    stopTicker()
    stopProgressTimer()

    source.value = 'library'
    currentRadio.value = null
    currentEpisode.value = null

    const token = (window as any).__resonance_access_token

    startLoading()

    howl = new Howl({
      src: [`/api/stream/${track.id}?token=${encodeURIComponent(token ?? '')}`],
      html5: true,
      volume: volume.value,
      onload: () => {
        duration.value = howl?.duration() ?? 0
        stopLoading()
      },
      onplay: () => {
        playing.value = true
        stopLoading()
        tick()
        logPlay(track.id)
      },
      onpause: () => { playing.value = false; stopTicker() },
      onstop:  () => { playing.value = false; stopTicker() },
      onloaderror: () => stopLoading(),
      onplayerror: () => stopLoading(),
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

  // ── radio ────────────────────────────────────────────

  function playRadio(station: RadioStation) {
    if (howl) { howl.unload(); howl = null }
    stopTicker()
    stopProgressTimer()

    queue.value = []
    index.value = -1
    loggedFor = null

    source.value = 'radio'
    currentRadio.value = station
    currentEpisode.value = null
    position.value = 0
    duration.value = 0

    const token = (window as any).__resonance_access_token

    startLoading()

    howl = new Howl({
      src: [`/api/radio/${station.id}/stream?token=${encodeURIComponent(token ?? '')}`],
      html5: true,
      volume: volume.value,
      onplay:  () => { playing.value = true; stopLoading() },
      onpause: () => { playing.value = false },
      onstop:  () => { playing.value = false; stopLoading() },
      onloaderror: () => stopLoading(),
      onplayerror: () => stopLoading(),
      onend:   () => { playing.value = false; stopLoading() },
    })

    howl.play()
  }

  function stopRadio() {
    if (howl) { howl.unload(); howl = null }
    playing.value = false
    stopLoading()
    source.value = 'library'
    currentRadio.value = null
  }

  // ── podcast ──────────────────────────────────────────

  async function saveEpisodeProgress(completed = false) {
    const ep = currentEpisode.value
    if (!ep || source.value !== 'podcast') return
    try {
      await api.put(`/podcast-episodes/${ep.id}/progress`, {
        position_sec: Math.floor(position.value),
        duration_sec: Math.floor(duration.value || ep.duration_sec || 0),
        completed,
      })
    } catch {
      // silent
    }
  }

  function playEpisode(ep: PodcastEpisode, startAt = 0) {
    if (howl) { howl.unload(); howl = null }
    stopTicker()
    stopProgressTimer()

    queue.value = []
    index.value = -1
    loggedFor = null

    source.value = 'podcast'
    currentRadio.value = null
    currentEpisode.value = ep
    position.value = startAt
    duration.value = ep.duration_sec ?? 0

    const token = (window as any).__resonance_access_token

    startLoading()

    howl = new Howl({
      src: [`/api/podcast-episodes/${ep.id}/stream?token=${encodeURIComponent(token ?? '')}`],
      html5: true,
      volume: volume.value,
      onload: () => {
        duration.value = howl?.duration() ?? duration.value
        stopLoading()
      },
      onplay: () => {
        playing.value = true
        stopLoading()
        tick()
        progressTimer = setInterval(() => saveEpisodeProgress(false), 15000)
        if (startAt > 0 && howl) howl.seek(startAt)
      },
      onpause: () => {
        playing.value = false
        stopTicker()
        stopProgressTimer()
        saveEpisodeProgress(false)
      },
      onstop: () => {
        playing.value = false
        stopTicker()
        stopProgressTimer()
      },
      onloaderror: () => stopLoading(),
      onplayerror: () => stopLoading(),
      onend: () => {
        playing.value = false
        stopTicker()
        stopProgressTimer()
        stopLoading()
        saveEpisodeProgress(true)
      },
    })

    howl.play()
  }

  function stopEpisode() {
    if (howl) { howl.unload(); howl = null }
    stopTicker()
    stopProgressTimer()
    stopLoading()
    playing.value = false
    source.value = 'library'
    currentEpisode.value = null
    position.value = 0
    duration.value = 0
  }

  // ── transport ────────────────────────────────────────

  function playTrack(track: Track, newQueue: Track[] = [track]) {
    if (track.id !== loggedFor) loggedFor = null
    queue.value = newQueue
    index.value = newQueue.findIndex((t) => t.id === track.id)
    load(track)
  }

  function play() {
    if (source.value === 'radio') {
      if (howl) {
        startLoading()
        howl.play()
      } else if (currentRadio.value) {
        playRadio(currentRadio.value)
      }
      return
    }
    if (source.value === 'podcast') {
      if (howl) {
        startLoading()
        howl.play()
      }
      return
    }

    const cur = current.value
    if (!howl && cur) {
      load(cur)
    } else if (howl) {
      startLoading()
      howl.play()
    }
  }

  function pause() { howl?.pause() }

  function toggle() {
    playing.value ? pause() : play()
  }

  function next() {
    if (source.value !== 'library') return
    const nextIndex = index.value + 1
    if (nextIndex >= queue.value.length) { pause(); return }
    const t = queue.value[nextIndex]
    if (!t) return
    index.value = nextIndex
    loggedFor = null
    load(t)
  }

  function prev() {
    if (source.value !== 'library') return
    if (index.value <= 0) return
    const prevIndex = index.value - 1
    const t = queue.value[prevIndex]
    if (!t) return
    index.value = prevIndex
    loggedFor = null
    load(t)
  }

  function seek(seconds: number) {
    if (source.value === 'radio') return
    if (!howl) return
    howl.seek(seconds)
    position.value = seconds
  }

  function setVolume(v: number) {
    volume.value = v
    Howler.volume(v)
    localStorage.setItem('resonance_volume', String(v))
  }

  // ── queue ops (library only) ─────────────────────────

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
    const isCurrent = targetIndex === index.value
    const currentId = current.value?.id
    queue.value.splice(targetIndex, 1)
    if (isCurrent) {
      if (index.value >= queue.value.length) index.value = queue.value.length
      return
    }
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
    if (wasCurrent) { index.value = to; return }
    if (from < index.value && to >= index.value) index.value -= 1
    else if (from > index.value && to <= index.value) index.value += 1
    else _reindexByCurrentTrackId(currentId, index.value)
  }

  function clearUpcoming() {
    if (index.value < 0) { queue.value = []; return }
    queue.value = queue.value.slice(0, index.value + 1)
  }

  function stop() {
    if (howl) { howl.stop(); howl.unload(); howl = null }
    stopTicker()
    stopProgressTimer()
    stopLoading()
    playing.value = false
    position.value = 0
    duration.value = 0
    queue.value = []
    index.value = -1
    loggedFor = null
    source.value = 'library'
    currentRadio.value = null
    currentEpisode.value = null
  }

  Howler.autoUnlock = true
  Howler.volume(volume.value)

  return {
    queue, index, playing, loading, position, duration, volume,
    source, current, currentRadio, currentEpisode,
    upcoming, played, isLive, isPodcast,
    playTrack, playRadio, stopRadio, playEpisode, stopEpisode,
    play, pause, toggle, next, prev, seek, setVolume,
    jumpTo, removeAt, move, clearUpcoming, stop,
  }
})
