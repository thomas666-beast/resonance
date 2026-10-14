<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { useRoute, RouterLink } from 'vue-router'
import { useI18n } from 'vue-i18n'
import VueDraggable from 'vuedraggable'
import api from '@/api/client'
import { usePlaylistsStore, type Playlist } from '@/stores/playlists'
import { usePlayerStore, type Track } from '@/stores/player'
import { useFavoritesStore } from '@/stores/favorites'
import TrackRow from '@/components/TrackRow.vue'

const { t } = useI18n()
const route = useRoute()
const playlists = usePlaylistsStore()
const player = usePlayerStore()
const favorites = useFavoritesStore()

const playlist = ref<Playlist | null>(null)
const tracks = ref<Track[]>([])
const loading = ref(true)
const error = ref<string | null>(null)
const editable = ref(true)

const localTracks = computed({
  get: () => tracks.value,
  set: (v) => { tracks.value = v },
})

onMounted(async () => {
  try {
    const { data } = await Promise.all([
      api.get(`/playlists/${route.params.id}`),
      favorites.loaded ? Promise.resolve() : favorites.load(),
    ]).then(([r]) => r)
    playlist.value = data.playlist
    tracks.value = data.tracks
    editable.value = playlist.value?.user_id === undefined ? true : true
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Failed to load playlist'
  } finally {
    loading.value = false
  }
})

async function onReorder() {
  if (!playlist.value) return
  await playlists.reorder(playlist.value.id, tracks.value.map((t) => t.id))
}

async function removeTrack(trackId: number) {
  if (!playlist.value) return
  if (!confirm(t('playlists.confirmRemove'))) return
  await playlists.removeTrack(playlist.value.id, trackId)
  tracks.value = tracks.value.filter((t) => t.id !== trackId)
}

function playAll() {
  if (tracks.value.length) player.playTrack(tracks.value[0], tracks.value)
}
</script>

<template>
  <div class="p-8 pb-32 max-w-4xl mx-auto">
    <p v-if="loading" class="text-stone-500">{{ $t('common.loading') }}</p>
    <p v-else-if="error" class="text-red-600">{{ error }}</p>

    <template v-else-if="playlist">
      <header class="mb-8">
        <p class="text-xs uppercase tracking-widest text-stone-400 mb-2">
          {{ $t('playlists.label') }}
        </p>
        <h1 class="text-4xl font-semibold tracking-tight">{{ playlist.name }}</h1>
        <p v-if="playlist.description" class="text-stone-600 mt-2">{{ playlist.description }}</p>
        <p class="text-stone-500 text-sm mt-1">{{ $t('playlists.trackCount', { n: tracks.length }) }}</p>

        <button
          @click="playAll"
          :disabled="!tracks.length"
          class="mt-6 px-5 py-2.5 bg-stone-900 text-white rounded-full text-sm font-medium
                 hover:bg-stone-800 disabled:opacity-40 transition-colors"
        >
          ▶ {{ $t('album.playAll') }}
        </button>
      </header>

      <p v-if="!tracks.length" class="text-stone-500">{{ $t('playlists.noTracks') }}</p>

      <VueDraggable
        v-else
        v-model="localTracks"
        item-key="id"
        handle=".drag-handle"
        :animation="150"
        @end="onReorder"
        class="space-y-0.5"
        >
          <template #item="{ element: t, index: i }">
            <div class="flex items-center">
              <span class="drag-handle cursor-grab text-stone-300 px-2 select-none">⋮⋮</span>
              <div class="flex-1">
                  <TrackRow
                  :track="t"
                  :queue="tracks"
                  :index="i + 1"
                  show-artist
                  >
                  <template #actions>
                      <button
                      @click.stop="removeTrack(t.id)"
                      class="p-1.5 rounded-full hover:bg-stone-100 text-stone-400"
                      :aria-label="$t('playlists.remove')"
                      >✕</button>
                  </template>
                  </TrackRow>
              </div>
            </div>
          </template>
        </VueDraggable>
    </template>
  </div>
</template>
