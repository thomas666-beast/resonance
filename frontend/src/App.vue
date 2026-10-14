<script setup lang="ts">
import { onMounted, onUnmounted, watch } from 'vue'
import { RouterView, RouterLink, useRouter } from 'vue-router'
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

const auth = useAuthStore()
const router = useRouter()
const localeStore = useLocaleStore()
const scan = useScanStore()
const favorites = useFavoritesStore()
const playlistsStore = usePlaylistsStore()

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
  }
})

onUnmounted(() => scan.disconnect())

async function logout() {
  scan.disconnect()
  await auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <div class="min-h-screen flex flex-col bg-app text-app">
    <header
      v-if="auth.accessToken"
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
        </nav>

        <SearchBox />

        <div class="ml-auto flex items-center gap-3 text-sm shrink-0">
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

    <ScanProgress />

    <main class="flex-1 pb-28">
      <RouterView />
    </main>

    <PlayerBar v-if="auth.accessToken" />
    <ToastHost />
  </div>
</template>
