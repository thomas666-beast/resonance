<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import VueDraggable from 'vuedraggable'
import api from '@/api/client'
import { usePlaylistsStore, type Playlist } from '@/stores/playlists'
import { usePlayerStore, type Track } from '@/stores/player'
import { useFavoritesStore } from '@/stores/favorites'
import TrackRow from '@/components/TrackRow.vue'
import SkeletonList from '@/components/SkeletonList.vue'
import EmptyState from '@/components/EmptyState.vue'

const { t } = useI18n()
const route = useRoute()
const playlists = usePlaylistsStore()
const player = usePlayerStore()
const favorites = useFavoritesStore()

const playlist = ref<Playlist | null>(null)
const tracks = ref<Track[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

const localTracks = computed({
  get: () => tracks.value,
  set: (v) => { tracks.value = v },
})

onMounted(async () => {
  try {
    const { data } = await api.get(`/playlists/${route.params.id}`)
    playlist.value = data.playlist
    tracks.value = data.tracks
    if (!favorites.loaded) favorites.load()
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
  const first = tracks.value[0]
  if (first) player.playTrack(first, tracks.value)
}
</script>

<template>
  <div class="p-8 pb-32 max-w-4xl mx-auto text-app">
    <p v-if="error" class="text-danger">{{ error }}</p>

    <div v-else-if="loading" class="space-y-6">
      <div class="space-y-3">
        <Skeleton variant="text" width="20%" height="0.75rem" />
        <Skeleton variant="text" width="50%" height="2.5rem" />
        <Skeleton variant="text" width="25%" height="1rem" />
      </div>
      <SkeletonList :count="8" />
    </div>

    <template v-else-if="playlist">
      <header class="mb-8">
        <p class="text-xs uppercase tracking-widest text-dim mb-2">
          {{ $t('playlists.label') }}
        </p>
        <h1 class="text-4xl font-semibold tracking-tight">{{ playlist.name }}</h1>
        <p v-if="playlist.description" class="text-muted mt-2">{{ playlist.description }}</p>
        <p class="text-dim text-sm mt-1">{{ $t('playlists.trackCount', { n: tracks.length }) }}</p>

        <button
          @click="playAll"
          :disabled="!tracks.length"
          class="mt-6 px-5 py-2.5 bg-accent text-white rounded-full text-sm font-medium
                 hover:opacity-90 disabled:opacity-40 transition-opacity"
        >
          ▶ {{ $t('album.playAll') }}
        </button>
      </header>

      <EmptyState
        v-if="!tracks.length"
        icon="list"
        :title="$t('playlists.noTracksTitle')"
        :description="$t('playlists.noTracksDescription')"
        :action-label="$t('nav.albums')"
        action-to="/albums"
      />

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
            <span class="drag-handle cursor-grab text-dim px-2 select-none">⋮⋮</span>
            <div class="flex-1">
              <TrackRow :track="t" :queue="tracks" :index="i + 1" show-artist>
                <template #actions>
                  <button
                    @click.stop="removeTrack(t.id)"
                    class="p-1.5 rounded-full hover-surface text-muted"
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
