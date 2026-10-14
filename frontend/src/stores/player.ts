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
  const position = ref(0)      // seconds
  const duration = ref(0)      // seconds
  const volume = ref(Number(localStorage.getItem('resonance_volume') ?? 1))

  let howl: Howl | null = null
  let rafId: number | null = null

  const current = computed<Track | null>(() =>
    index.value >= 0 && index.value < queue.value.length ? queue.value[index.value] : null,
  )

  function stopTicker() {
    if (rafId !== null) {
      cancelAnimationFrame(rafId)
      rafId = null
    }
  }

  function tick() {
    if (howl && playing.value) {
      position.value = howl.seek() as number
    }
    rafId = requestAnimationFrame(tick)
  }

  function load(track: Track) {
    // Tear down previous Howl
    const token = (window as any).__resonance_access_token


    if (howl) {
      howl.unload()
      howl = null
    }
    stopTicker()

    // The stream endpoint requires the access token.
    // html5: true → streams from server, leverages our Range support.
    howl = new Howl({
      // frontend/src/stores/player.ts — inside load(), replace the src line:
      src: [`/api/stream/${track.id}?token=${encodeURIComponent(token)}`],
      html5: true,
      volume: volume.value,
      onload: () => {
        duration.value = howl?.duration() ?? 0
      },
      onplay: () => {
        playing.value = true
        tick()
      },
      onpause: () => {
        playing.value = false
        stopTicker()
      },
      onstop: () => {
        playing.value = false
        stopTicker()
      },
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
    queue.value = newQueue
    index.value = newQueue.findIndex((t) => t.id === track.id)
    load(track)
  }

  function play() {
    if (!howl && current.value) {
      load(current.value)
    } else if (howl) {
      howl.play()
    }
  }

  function pause() {
    howl?.pause()
  }

  function toggle() {
    playing.value ? pause() : play()
  }

  function next() {
    if (index.value + 1 >= queue.value.length) {
      pause()
      return
    }
    index.value += 1
    load(queue.value[index.value])
  }

  function prev() {
    if (index.value <= 0) return
    index.value -= 1
    load(queue.value[index.value])
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

  // Howler won't play without a user gesture on most browsers
  Howler.autoUnlock = true
  Howler.volume(volume.value)

  return {
    queue, index, playing, position, duration, volume, current,
    playTrack, play, pause, toggle, next, prev, seek, setVolume,
  }
})
