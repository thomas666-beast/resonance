<script setup lang="ts">
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import { usePlayerStore, type Track } from '@/stores/player'
import FavoriteButton from './FavoriteButton.vue'
import AddToPlaylistMenu from './AddToPlaylistMenu.vue'

const props = defineProps<{
  track: Track
  queue?: Track[]
  showArtist?: boolean
  showAlbum?: boolean
  index?: number
}>()

const player = usePlayerStore()

const menuOpen = ref(false)

function play() {
  player.playTrack(props.track, props.queue ?? [props.track])
}

function fmt(ms: number | null | undefined): string {
  if (!ms) return '—'
  const s = Math.floor(ms / 1000)
  return `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, '0')}`
}

function isCurrent(): boolean {
  return player.current?.id === props.track.id
}
</script>

<template>
  <div
    @click="play"
    class="group flex items-center gap-4 px-3 py-2 rounded-lg cursor-pointer
           hover:bg-surface-2 transition-colors relative"
    :class="[
      isCurrent() ? 'bg-surface-2' : '',
      menuOpen ? 'z-30' : ''
    ]"
  >
    <div class="w-6 text-right text-sm tabular"
         :class="isCurrent() ? 'text-accent font-semibold' : 'text-dim'">
      {{ index ?? track.track_number ?? '·' }}
    </div>

    <div class="min-w-0 flex-1">
      <div class="truncate text-sm font-medium"
           :class="isCurrent() ? 'text-accent' : 'text-app'">
        {{ track.title }}
      </div>
      <div v-if="showArtist || showAlbum" class="truncate text-xs text-muted mt-0.5">
        <template v-if="showArtist && track.artist_id">
          <RouterLink :to="`/artists/${track.artist_id}`" @click.stop
                      class="hover:underline">{{ track.artist_name }}</RouterLink>
        </template>
        <template v-if="showArtist && showAlbum && track.album_id"> · </template>
        <template v-if="showAlbum && track.album_id">
          <RouterLink :to="`/albums/${track.album_id}`" @click.stop
                      class="hover:underline">{{ track.album_title }}</RouterLink>
        </template>
      </div>
    </div>

    <slot name="actions" />

    <div class="flex items-center gap-1 text-muted group-hover:text-app transition-colors">
      <FavoriteButton :track-id="track.id" />
      <AddToPlaylistMenu :track-id="track.id" @open-change="menuOpen = $event" />
    </div>

    <div class="text-xs text-muted tabular w-12 text-right">
      {{ fmt(track.duration_ms) }}
    </div>
  </div>
</template>
