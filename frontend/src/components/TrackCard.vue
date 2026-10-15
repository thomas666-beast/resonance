<script setup lang="ts">
import { usePlayerStore, type Track } from '@/stores/player'
import AlbumCover from './AlbumCover.vue'

const props = defineProps<{
  track: Track
  queue?: Track[]
}>()

const player = usePlayerStore()

function play() {
  player.playTrack(props.track, props.queue ?? [props.track])
}

function isCurrent(): boolean {
  return player.current?.id === props.track.id
}
</script>

<template>
  <button
    @click="play"
    class="group w-40 shrink-0 text-left"
  >
    <div class="relative aspect-square rounded-xl overflow-hidden shadow-lg
                group-hover:shadow-xl group-hover:-translate-y-1
                active:scale-[0.98] transition-all duration-200 ease-out">
      <AlbumCover v-if="track.album_id" :album-id="track.album_id" fill />
      <div v-else class="w-full h-full bg-surface-2 flex items-center justify-center">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-12 h-12 fill-none stroke-muted" stroke-width="1.5">
          <circle cx="12" cy="12" r="9" />
          <circle cx="12" cy="12" r="2" />
        </svg>
      </div>

      <div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100
                  transition-opacity duration-200 flex items-center justify-center">
        <div class="w-12 h-12 rounded-full bg-accent text-white flex items-center
                    justify-center text-lg shadow-2xl transform scale-90
                    group-hover:scale-100 transition-transform duration-200">
          {{ isCurrent() && player.playing ? '❚❚' : '▶' }}
        </div>
      </div>
    </div>

    <div class="mt-3">
      <div class="text-sm font-medium truncate transition-colors"
           :class="isCurrent() ? 'text-accent' : 'text-app'">
        {{ track.title }}
      </div>
      <div class="text-xs text-muted truncate">
        {{ track.artist_name ?? '—' }}
      </div>
    </div>
  </button>
</template>
