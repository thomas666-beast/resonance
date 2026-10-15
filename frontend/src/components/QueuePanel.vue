<script setup lang="ts">
import { watch, onUnmounted, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import VueDraggable from 'vuedraggable'
import { usePlayerStore, type Track } from '@/stores/player'
import AlbumCover from './AlbumCover.vue'

const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{ (e: 'close'): void }>()

const { t } = useI18n()
const player = usePlayerStore()

// Local mirror for vuedraggable. On drag end we sync back to the store.
const localUpcoming = computed({
  get: () => player.upcoming,
  set: (v: Track[]) => {
    // The store's queue holds [played..., current, ...upcoming]
    // so we splice the new upcoming list back in after the current index.
    const head = player.queue.slice(0, player.index + 1)
    player.queue = [...head, ...v]
  },
})

const localPlayed = computed(() => player.played)

function fmt(ms: number | null | undefined): string {
  if (!ms) return '—'
  const s = Math.floor(ms / 1000)
  return `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, '0')}`
}

function onDragEnd(evt: { oldIndex: number; newIndex: number }) {
  if (evt.oldIndex === evt.newIndex) return
  // Convert upcoming-relative indices to queue-absolute indices
  const from = player.index + 1 + evt.oldIndex
  const to   = player.index + 1 + evt.newIndex
  player.move(from, to)
}

function jumpToUpcoming(upcomingIndex: number) {
  player.jumpTo(player.index + 1 + upcomingIndex)
}

function removeUpcoming(upcomingIndex: number) {
  player.removeAt(player.index + 1 + upcomingIndex)
}

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape' && props.open) emit('close')
}

watch(() => props.open, (open) => {
  document.body.style.overflow = open ? 'hidden' : ''
})

onUnmounted(() => {
  document.body.style.overflow = ''
  document.removeEventListener('keydown', onKey)
})

document.addEventListener('keydown', onKey)
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
        class="fixed inset-0 bg-black/60 backdrop-blur-sm z-40"
        @click="emit('close')"
      />
    </Transition>

    <Transition
      enter-active-class="transition-transform duration-200 ease-out"
      enter-from-class="translate-y-full"
      enter-to-class="translate-y-0"
      leave-active-class="transition-transform duration-150 ease-in"
      leave-from-class="translate-y-0"
      leave-to-class="translate-y-full"
    >
      <section
        v-if="open"
        class="fixed left-0 right-0 bottom-0 top-16 md:top-24 z-50
               bg-surface border-t border-app rounded-t-2xl shadow-2xl
               flex flex-col max-w-3xl mx-auto"
        role="dialog"
        aria-modal="true"
        :aria-label="t('queue.title')"
      >
        <!-- Header -->
        <header class="px-5 py-4 border-b border-app flex items-center">
          <h2 class="text-heading">{{ $t('queue.title') }}</h2>
          <button
            v-if="player.upcoming.length"
            @click="player.clearUpcoming()"
            class="ml-auto mr-3 text-sm text-muted hover:text-danger transition-colors"
          >
            {{ $t('queue.clearUpcoming') }}
          </button>
          <button
            @click="emit('close')"
            class="p-1.5 rounded-full hover:bg-surface-2 transition-colors text-muted"
            :aria-label="$t('common.close')"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                 class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
              <path d="M18 6 6 18M6 6l12 12" />
            </svg>
          </button>
        </header>

        <!-- Empty -->
        <div v-if="!player.current" class="flex-1 flex items-center justify-center text-muted text-sm px-6 text-center">
          {{ $t('queue.empty') }}
        </div>

        <!-- Content -->
        <div v-else class="flex-1 overflow-y-auto scroll-slim px-5 py-4 space-y-8">
          <!-- Now playing -->
          <div>
            <div class="text-label mb-2">{{ $t('queue.nowPlaying') }}</div>
            <div class="flex items-center gap-3 px-3 py-2 rounded-lg bg-surface-2">
              <AlbumCover
                v-if="player.current.album_id"
                :album-id="player.current.album_id"
                size="sm"
              />
              <div class="min-w-0 flex-1">
                <div class="text-sm font-medium text-accent truncate">{{ player.current.title }}</div>
                <div class="text-xs text-muted truncate">
                  {{ player.current.artist_name ?? '—' }}
                </div>
              </div>
            </div>
          </div>

          <!-- Played (collapsed info) -->
          <div v-if="localPlayed.length">
            <div class="text-label mb-2">
              {{ $t('queue.played') }} · {{ localPlayed.length }}
            </div>
            <div class="space-y-0.5 opacity-60">
              <div
                v-for="t in localPlayed.slice(-5)"
                :key="`p-${t.id}`"
                class="flex items-center gap-3 px-3 py-1.5 text-sm"
              >
                <span class="flex-1 truncate text-muted">{{ t.title }}</span>
                <span class="text-xs text-dim tabular">{{ fmt(t.duration_ms) }}</span>
              </div>
            </div>
          </div>

          <!-- Next up -->
          <div>
            <div class="text-label mb-2">
              {{ $t('queue.nextUp') }} · {{ player.upcoming.length }}
            </div>

            <p v-if="!player.upcoming.length" class="text-sm text-muted">
              {{ $t('queue.noUpcoming') }}
            </p>

            <VueDraggable
              v-else
              v-model="localUpcoming"
              item-key="id"
              handle=".drag-handle"
              :animation="150"
              @end="onDragEnd"
              class="space-y-0.5"
            >
              <template #item="{ element: t, index: i }">
                <div class="group flex items-center gap-2 px-2 py-2 rounded-lg hover:bg-surface-2 transition-colors">
                  <span class="drag-handle cursor-grab text-dim px-3 py-2 md:py-0 select-none">⋮⋮</span>

                  <button
                    @click="jumpToUpcoming(i)"
                    class="flex items-center gap-3 min-w-0 flex-1 text-left"
                  >
                    <AlbumCover
                      v-if="t.album_id"
                      :album-id="t.album_id"
                      size="sm"
                    />
                    <div class="min-w-0 flex-1">
                      <div class="text-sm font-medium text-app truncate">{{ t.title }}</div>
                      <div class="text-xs text-muted truncate">
                        {{ t.artist_name ?? '—' }}
                        <span v-if="t.album_title"> · {{ t.album_title }}</span>
                      </div>
                    </div>
                  </button>

                  <span class="text-xs text-muted tabular hidden sm:block">
                    {{ fmt(t.duration_ms) }}
                  </span>

                  <button
                    @click="removeUpcoming(i)"
                    class="p-2 md:p-1.5 rounded-full hover:bg-surface-2 text-muted hover:text-danger transition-colors"
                    :aria-label="$t('queue.remove')"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                         class="w-4 h-4 fill-none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                      <path d="M18 6 6 18M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              </template>
            </VueDraggable>
          </div>
        </div>
      </section>
    </Transition>
  </Teleport>
</template>
