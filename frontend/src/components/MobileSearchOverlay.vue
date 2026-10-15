<script setup lang="ts">
import { ref, watch, nextTick, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useSearchStore } from '@/stores/search'

const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{ (e: 'close'): void }>()

const { t } = useI18n()
const router = useRouter()
const search = useSearchStore()
const input = ref<HTMLInputElement | null>(null)

watch(() => props.open, async (open) => {
  if (open) {
    search.open = true
    await nextTick()
    input.value?.focus()
  } else {
    search.clear()
  }
})

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape' && props.open) emit('close')
}

document.addEventListener('keydown', onKey)
onUnmounted(() => document.removeEventListener('keydown', onKey))

function onInput(e: Event) {
  const q = (e.target as HTMLInputElement).value
  search.open = true
  search.runDebounced(q)
}

function go(path: string) {
  emit('close')
  router.push(path)
}

function hasResults() {
  return search.artists.length + search.albums.length + search.tracks.length > 0
}
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition-opacity duration-150"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity duration-150"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="open"
        class="fixed inset-0 bg-black/60 backdrop-blur-sm z-40 md:hidden"
        @click="emit('close')"
      />
    </Transition>

    <Transition
      enter-active-class="transition-transform duration-200 ease-out"
      enter-from-class="-translate-y-full"
      enter-to-class="translate-y-0"
      leave-active-class="transition-transform duration-150 ease-in"
      leave-from-class="translate-y-0"
      leave-to-class="-translate-y-full"
    >
      <div
        v-if="open"
        class="fixed top-0 left-0 right-0 z-50 bg-surface border-b border-app
               md:hidden max-h-[80vh] flex flex-col"
      >
        <div class="px-4 py-3 flex items-center gap-2">
          <input
            ref="input"
            type="search"
            :value="search.query"
            @input="onInput"
            :placeholder="$t('search.placeholder')"
            class="flex-1 border border-app rounded-full px-4 py-2 text-sm
                   bg-surface-2 text-app placeholder:text-dim
                   focus:outline-none focus:border-accent"
          />
          <button
            @click="emit('close')"
            class="px-3 py-2 text-sm text-muted hover:text-app transition-colors"
          >
            {{ $t('common.cancel') }}
          </button>
        </div>

        <div v-if="search.query.length >= 2" class="overflow-y-auto scroll-slim border-t border-app">
          <p v-if="search.loading" class="px-4 py-3 text-sm text-muted">
            {{ $t('common.loading') }}
          </p>
          <p v-else-if="!hasResults()" class="px-4 py-3 text-sm text-muted">
            {{ $t('search.noResults') }}
          </p>

          <template v-else>
            <div v-if="search.artists.length" class="py-2">
              <div class="px-4 py-1 text-xs uppercase tracking-widest text-dim">
                {{ $t('nav.artists') }}
              </div>
              <button
                v-for="a in search.artists"
                :key="`a${a.id}`"
                @click="go(`/artists/${a.id}`)"
                class="block w-full text-left px-4 py-2 hover-surface text-sm text-app"
              >{{ a.name }}</button>
            </div>

            <div v-if="search.albums.length" class="py-2 border-t border-app">
              <div class="px-4 py-1 text-xs uppercase tracking-widest text-dim">
                {{ $t('albums.label') }}
              </div>
              <button
                v-for="a in search.albums"
                :key="`al${a.id}`"
                @click="go(`/albums/${a.id}`)"
                class="block w-full text-left px-4 py-2 hover-surface text-sm text-app"
              >
                <span class="font-medium">{{ a.title }}</span>
                <span v-if="a.artist_name" class="text-muted"> · {{ a.artist_name }}</span>
              </button>
            </div>

            <div v-if="search.tracks.length" class="py-2 border-t border-app">
              <div class="px-4 py-1 text-xs uppercase tracking-widest text-dim">
                {{ $t('search.tracks') }}
              </div>
              <button
                v-for="t in search.tracks"
                :key="`t${t.id}`"
                @click="go(`/albums/${t.album_id}`)"
                class="block w-full text-left px-4 py-2 hover-surface text-sm text-app"
              >
                <span class="font-medium">{{ t.title }}</span>
                <span v-if="t.artist_name" class="text-muted"> · {{ t.artist_name }}</span>
              </button>
            </div>
          </template>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
