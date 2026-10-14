<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useSearchStore } from '@/stores/search'

const { t } = useI18n()
const router = useRouter()
const search = useSearchStore()

const root = ref<HTMLElement | null>(null)
const input = ref<HTMLInputElement | null>(null)

const hasResults = computed(() =>
  search.artists.length + search.albums.length + search.tracks.length > 0,
)

function onInput(e: Event) {
  const q = (e.target as HTMLInputElement).value
  search.open = true
  search.runDebounced(q)
}

function onFocus() {
  search.open = true
  input.value?.select()
}

function go(path: string) {
  search.clear()
  router.push(path)
}

function onDocClick(e: MouseEvent) {
  if (root.value && !root.value.contains(e.target as Node)) search.open = false
}

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') {
    search.open = false
    input.value?.blur()
  }
}

onMounted(() => {
  document.addEventListener('click', onDocClick)
  document.addEventListener('keydown', onKey)
})
onUnmounted(() => {
  document.removeEventListener('click', onDocClick)
  document.removeEventListener('keydown', onKey)
})
</script>

<template>
  <div ref="root" class="relative flex-1 max-w-md">
    <input
      ref="input"
      :value="search.query"
      @input="onInput"
      @focus="onFocus"
      type="search"
      :placeholder="$t('search.placeholder')"
      class="w-full border border-stone-200 rounded-full px-4 py-1.5 text-sm
             bg-white focus:outline-none focus:ring-2 focus:ring-stone-300"
    />

    <div
      v-if="search.open && (search.query.length >= 2)"
      class="absolute top-full left-0 right-0 mt-2 bg-white border border-stone-200
             rounded-xl shadow-lg z-40 max-h-[70vh] overflow-y-auto scroll-slim"
    >
      <p v-if="search.loading" class="px-4 py-3 text-sm text-stone-500">
        {{ $t('common.loading') }}
      </p>
      <p v-else-if="!hasResults" class="px-4 py-3 text-sm text-stone-500">
        {{ $t('search.noResults') }}
      </p>

      <template v-else>
        <div v-if="search.artists.length" class="py-2">
          <div class="px-4 py-1 text-xs uppercase tracking-widest text-stone-400">
            {{ $t('nav.artists') }}
          </div>
          <button
            v-for="a in search.artists"
            :key="`a${a.id}`"
            @click="go(`/artists/${a.id}`)"
            class="block w-full text-left px-4 py-1.5 hover:bg-stone-100 text-sm"
          >{{ a.name }}</button>
        </div>

        <div v-if="search.albums.length" class="py-2 border-t border-stone-100">
          <div class="px-4 py-1 text-xs uppercase tracking-widest text-stone-400">
            {{ $t('albums.label') }}
          </div>
          <button
            v-for="a in search.albums"
            :key="`al${a.id}`"
            @click="go(`/albums/${a.id}`)"
            class="block w-full text-left px-4 py-1.5 hover:bg-stone-100 text-sm"
          >
            <span class="font-medium">{{ a.title }}</span>
            <span v-if="a.artist_name" class="text-stone-500"> · {{ a.artist_name }}</span>
          </button>
        </div>

        <div v-if="search.tracks.length" class="py-2 border-t border-stone-100">
          <div class="px-4 py-1 text-xs uppercase tracking-widest text-stone-400">
            {{ $t('search.tracks') }}
          </div>
          <button
            v-for="t in search.tracks"
            :key="`t${t.id}`"
            @click="go(`/albums/${t.album_id}`)"
            class="block w-full text-left px-4 py-1.5 hover:bg-stone-100 text-sm"
          >
            <span class="font-medium">{{ t.title }}</span>
            <span v-if="t.artist_name" class="text-stone-500"> · {{ t.artist_name }}</span>
          </button>
        </div>
      </template>
    </div>
  </div>
</template>
