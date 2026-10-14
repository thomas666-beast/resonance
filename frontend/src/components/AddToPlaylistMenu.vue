<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { usePlaylistsStore } from '@/stores/playlists'
import { useToastStore } from '@/stores/toast'

const props = defineProps<{ trackId: number }>()
const { t } = useI18n()
const playlists = usePlaylistsStore()
const toast = useToastStore()

const open = ref(false)
const root = ref<HTMLElement | null>(null)

function toggle(e: MouseEvent) {
  e.stopPropagation()
  open.value = !open.value
  if (open.value && !playlists.loaded) playlists.load()
}

async function pick(id: number, name: string) {
  try {
    await playlists.addTrack(id, props.trackId)
    toast.success(t('toasts.addedToPlaylist', { name }))
  } catch {
    toast.error(t('toasts.genericError'))
  } finally {
    open.value = false
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
    open.value = false
  }
}

function onDocClick(e: MouseEvent) {
  if (root.value && !root.value.contains(e.target as Node)) open.value = false
}

onMounted(() => document.addEventListener('click', onDocClick))
onUnmounted(() => document.removeEventListener('click', onDocClick))
</script>

<template>
  <div ref="root" class="relative">
    <button
      @click="toggle"
      class="p-1.5 rounded-full hover-surface transition-colors text-muted"
      :aria-label="$t('playlists.addTo')"
    >⋯</button>

    <div
      v-if="open"
      class="absolute right-0 mt-1 w-56 bg-surface border border-app rounded-lg
             shadow-xl z-30 py-1 text-sm text-app"
    >
      <div v-if="playlists.items.length === 0" class="px-3 py-2 text-muted text-xs">
        {{ $t('playlists.noneYet') }}
      </div>
      <button
        v-for="p in playlists.items"
        :key="p.id"
        @click.stop="pick(p.id, p.name)"
        class="block w-full text-left px-3 py-1.5 hover-surface truncate"
      >
        {{ p.name }}
        <span class="text-dim text-xs">· {{ p.track_count }}</span>
      </button>
      <div class="border-t border-app my-1" />
      <button
        @click="newPlaylist"
        class="block w-full text-left px-3 py-1.5 hover-surface text-accent font-medium"
      >
        + {{ $t('playlists.newPlaylist') }}
      </button>
    </div>
  </div>
</template>
