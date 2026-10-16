<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { usePlayerStore, type RadioStation } from '@/stores/player'
import { useRadioStore } from '@/stores/radio'

const props = defineProps<{ station: RadioStation }>()
const emit = defineEmits<{ (e: 'edit'): void; (e: 'delete'): void }>()

const { t } = useI18n()
const player = usePlayerStore()
const radio  = useRadioStore()

function play(e?: MouseEvent) {
  e?.stopPropagation()
  player.playRadio(props.station)
}

function isCurrent(): boolean {
  return player.isLive && player.currentRadio?.id === props.station.id
}
</script>

<template>
  <div
    class="group relative bg-surface border border-app rounded-xl p-4
           hover:shadow-xl hover:-translate-y-0.5 transition-all cursor-pointer"
    :class="{ 'border-accent': isCurrent() }"
    @click="play"
  >
    <!-- Admin menu (always visible for admins) -->
    <div v-if="radio.isAdmin" class="absolute top-3 right-3 z-10">
      <button
        @click.stop="emit('edit')"
        class="p-1.5 rounded-full hover:bg-surface-2 text-muted transition-colors"
        :aria-label="t('radio.edit')"
        :title="t('radio.edit')"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-4 h-4 fill-none" stroke="currentColor" stroke-width="2"
             stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 20h9M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4Z"/>
        </svg>
      </button>
      <button
        @click.stop="emit('delete')"
        class="p-1.5 rounded-full hover:bg-surface-2 text-muted hover:text-danger transition-colors"
        :aria-label="t('radio.delete')"
        :title="t('radio.delete')"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-4 h-4 fill-none" stroke="currentColor" stroke-width="2"
             stroke-linecap="round" stroke-linejoin="round">
          <path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>
        </svg>
      </button>
    </div>

    <div class="flex items-start gap-4">
      <div class="w-14 h-14 rounded-lg bg-surface-2 flex items-center justify-center overflow-hidden shrink-0">
        <img v-if="station.logo_url" :src="station.logo_url" class="w-full h-full object-cover" alt="" />
        <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-7 h-7 fill-none stroke-muted" stroke-width="1.5">
          <circle cx="12" cy="12" r="3" />
          <path d="M4.22 4.22a12 12 0 0 0 0 15.56M19.78 4.22a12 12 0 0 1 0 15.56M7.76 7.76a6 6 0 0 0 0 8.48M16.24 7.76a6 6 0 0 1 0 8.48" />
        </svg>
      </div>

      <div class="min-w-0 flex-1 pt-1">
        <div class="text-sm font-medium text-app truncate">{{ station.name }}</div>
        <div class="text-xs text-muted truncate mt-1">
          <template v-if="isCurrent() && radio.nowPlaying[station.id]">
            <span class="text-accent">{{ radio.nowPlaying[station.id] }}</span>
          </template>
          <template v-else>
            <template v-if="station.genre">{{ station.genre }}</template>
            <template v-if="station.genre && station.bitrate"> · </template>
            <template v-if="station.bitrate">{{ station.bitrate }} kbps</template>
          </template>
        </div>

        <div class="mt-4 flex items-center gap-3">
          <button
            @click.stop="play"
            class="px-3 py-1.5 rounded-full text-xs font-medium
                   bg-accent text-white hover:opacity-90 active:scale-95
                   transition-all flex items-center gap-1.5"
          >
            <svg v-if="isCurrent() && player.playing" xmlns="http://www.w3.org/2000/svg"
                 viewBox="0 0 24 24" class="w-3 h-3 fill-current">
              <path d="M6 5h4v14H6zM14 5h4v14h-4z" />
            </svg>
            <svg v-else xmlns="http://www.w3.org/2000/svg"
                 viewBox="0 0 24 24" class="w-3 h-3 fill-current">
              <path d="M8 5v14l11-7z" />
            </svg>
            {{ isCurrent() && player.playing ? t('radio.stop') : t('radio.play') }}
          </button>

          <a
            v-if="station.homepage_url"
            :href="station.homepage_url"
            target="_blank"
            rel="noopener noreferrer"
            @click.stop
            class="text-xs text-muted hover:text-accent transition-colors"
          >
            {{ t('radio.homepage') }} ↗
          </a>
        </div>
      </div>
    </div>
  </div>
</template>
