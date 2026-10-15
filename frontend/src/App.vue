<script setup lang="ts">
import { onMounted, onUnmounted, watch, computed } from 'vue'
import { RouterView, RouterLink, useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useLocaleStore } from '@/stores/locale'
import { useScanStore } from '@/stores/scan'
import { useFavoritesStore } from '@/stores/favorites'
import { usePlaylistsStore } from '@/stores/playlists'
import { SUPPORTED_LOCALES } from '@/i18n'
import { useKeyboard } from '@/composables/useKeyboard'
import PlayerBar from '@/components/PlayerBar.vue'
import ScanButton from '@/components/ScanButton.vue'
import ScanProgress from '@/components/ScanProgress.vue'
import SearchBox from '@/components/SearchBox.vue'
import ToastHost from '@/components/ToastHost.vue'
import ThemeToggle from '@/components/ThemeToggle.vue'
import { usePlayerStore } from '@/stores/player'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const localeStore = useLocaleStore()
const scan = useScanStore()
const favorites = useFavoritesStore()
const playlistsStore = usePlaylistsStore()

const isNowPlaying = computed(() => route.name === 'now-playing')

const player = usePlayerStore()

useKeyboard()

onMounted(() => {
  if (auth.accessToken) {
    scan.connect()
    favorites.load()
    playlistsStore.load()
  }
})

watch(() => auth.accessToken, (t) => {
  if (t) {
    scan.connect()
    favorites.load()
    playlistsStore.load()
  } else {
    scan.disconnect()
    player.stop()
  }
})

onUnmounted(() => scan.disconnect())

async function logout() {
  scan.disconnect()
  player.stop()
  await auth.logout()
  router.push({ name: 'login' })
}

</script>

<template>
  <div class="min-h-screen flex flex-col bg-app text-app">
    <header
      v-if="auth.accessToken && !isNowPlaying"
      class="sticky top-0 z-20 border-b border-app bg-surface/90 backdrop-blur-sm"
    >
      <div class="px-6 py-3 flex items-center gap-6 max-w-6xl mx-auto w-full">
        <RouterLink to="/" class="text-lg font-semibold tracking-tight shrink-0 text-app">
          {{ $t('app.title') }}
        </RouterLink>

        <nav class="flex items-center gap-1 text-sm shrink-0">
          <RouterLink to="/artists"
            class="px-3 py-1.5 rounded-full hover-surface transition-colors"
            active-class="bg-surface-2 font-medium">{{ $t('nav.artists') }}</RouterLink>
          <RouterLink to="/albums"
            class="px-3 py-1.5 rounded-full hover-surface transition-colors"
            active-class="bg-surface-2 font-medium">{{ $t('nav.albums') }}</RouterLink>
          <RouterLink to="/favorites"
            class="px-3 py-1.5 rounded-full hover-surface transition-colors"
            active-class="bg-surface-2 font-medium">{{ $t('nav.favorites') }}</RouterLink>
          <RouterLink to="/playlists"
            class="px-3 py-1.5 rounded-full hover-surface transition-colors"
            active-class="bg-surface-2 font-medium">{{ $t('nav.playlists') }}</RouterLink>
          <RouterLink v-if="auth.isAdmin" to="/admin"
            class="px-3 py-1.5 rounded-full hover-surface transition-colors"
            active-class="bg-surface-2 font-medium">{{ $t('nav.admin') }}</RouterLink>
        </nav>

        <SearchBox />

        <div class="ml-auto flex items-center gap-3 text-sm shrink-0">
          <RouterLink to="/settings"
            class="p-1.5 rounded-full hover-surface transition-colors text-muted"
            :aria-label="$t('settings.title')"
            :title="$t('settings.title')"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                 class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2"
                 stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="3" />
              <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
            </svg>
          </RouterLink>

          <ScanButton />
          <ThemeToggle />
          <select
            v-model="localeStore.current"
            @change="localeStore.set(localeStore.current)"
            class="border border-app rounded-full px-3 py-1 text-sm bg-surface text-app"
            :aria-label="$t('nav.language')"
          >
            <option v-for="l in SUPPORTED_LOCALES" :key="l" :value="l">{{ l.toUpperCase() }}</option>
          </select>
          <span class="text-muted">{{ auth.user?.username }}</span>
          <button @click="logout" class="text-muted hover:text-danger transition-colors">
            {{ $t('nav.logout') }}
          </button>
        </div>
      </div>
    </header>

    <ScanProgress v-if="!isNowPlaying" />

    <main class="flex-1 relative" :class="!isNowPlaying && 'pb-28'">
      <RouterView v-slot="{ Component }">
        <Transition name="page" mode="out-in">
          <component :is="Component" :key="route.path" />
        </Transition>
      </RouterView>
    </main>

    <PlayerBar v-if="auth.accessToken && !isNowPlaying" />
    <ToastHost />
  </div>
</template>
