<script setup lang="ts">
import { computed, onMounted, onUnmounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { usePlaylistsStore } from '@/stores/playlists'
import { useToastStore } from '@/stores/toast'
import { useUIStore } from '@/stores/ui'

const props = defineProps<{ trackId: number }>()
const emit = defineEmits<{ (e: 'open-change', open: boolean): void }>()

const { t } = useI18n()
const playlists = usePlaylistsStore()
const toast = useToastStore()
const ui = useUIStore()

// Our own open state is derived from the shared store.
const open = computed(() => ui.openTrackMenuId === props.trackId)

watch(open, (v) => emit('open-change', v))

function toggle(e: MouseEvent) {
  e.stopPropagation()
  ui.toggleTrackMenu(props.trackId)
  if (open.value && !playlists.loaded) playlists.load()
}

async function pick(id: number, name: string) {
  try {
    await playlists.addTrack(id, props.trackId)
    toast.success(t('toasts.addedToPlaylist', { name }))
  } catch {
    toast.error(t('toasts.genericError'))
  } finally {
    ui.closeTrackMenu()
  }
}

async function newPlaylist(e: MouseEvent) {
  e.stopPropagation()
  const name = prompt(t('playlists.newNamePrompt'))
  if (!name) return
  try {
    const pl = await playlists.create(name)
    await playlists.addTrack(pl.id, props.trackId)
    toast.success(t('toasts.createdAndAdded', { name }))
  } catch {
    toast.error(t('toasts.genericError'))
  } finally {
    ui.closeTrackMenu()
  }
}

// Close on outside click — but only if this instance is the currently open one
function onDocClick(e: MouseEvent) {
  if (!open.value) return
  const el = e.target as HTMLElement | null
  // If the click originated inside our own dropdown, ignore
  if (el && el.closest(`[data-track-menu="${props.trackId}"]`)) return
  ui.closeTrackMenu()
}

onMounted(() => document.addEventListener('click', onDocClick))
onUnmounted(() => document.removeEventListener('click', onDocClick))
</script>

<template>
  <div class="relative" :data-track-menu="trackId">
    <button
      @click="toggle"
      class="p-2 md:p-1.5 rounded-full hover:bg-surface-2 active:bg-surface-2 transition-colors text-muted"
      :aria-label="$t('playlists.addTo')"
      :aria-expanded="open"
    >
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
           class="w-4 h-4 fill-current">
        <circle cx="5" cy="12" r="1.8" />
        <circle cx="12" cy="12" r="1.8" />
        <circle cx="19" cy="12" r="1.8" />
      </svg>
    </button>

    <div
      v-if="open"
      class="absolute right-0 bottom-full mb-1 w-56 bg-surface border border-app
             rounded-lg shadow-2xl z-50 py-1 text-sm text-app origin-bottom-right"
    >
      <div v-if="playlists.items.length === 0" class="px-3 py-2 text-muted text-xs">
        {{ $t('playlists.noneYet') }}
      </div>
      <button
        v-for="p in playlists.items"
        :key="p.id"
        @click.stop="pick(p.id, p.name)"
        class="block w-full text-left px-3 py-2.5 md:py-1.5 hover:bg-surface-2 truncate transition-colors"
      >
        {{ p.name }}
        <span class="text-dim text-xs">· {{ p.track_count }}</span>
      </button>
      <div class="border-t border-app my-1" />
      <button
        @click="newPlaylist"
        class="block w-full text-left px-3 py-2.5 md:py-1.5 hover:bg-surface-2 text-accent font-medium transition-colors"
      >
        + {{ $t('playlists.newPlaylist') }}
      </button>
    </div>
  </div>
</template>
