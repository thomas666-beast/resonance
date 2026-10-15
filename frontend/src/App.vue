<script setup lang="ts">
import { onMounted, onUnmounted, watch, computed, ref } from 'vue'
import { RouterView, RouterLink, useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useAppStore } from '@/stores/app'
import { useLocaleStore } from '@/stores/locale'
import { useScanStore } from '@/stores/scan'
import { useFavoritesStore } from '@/stores/favorites'
import { usePlaylistsStore } from '@/stores/playlists'
import { usePlayerStore } from '@/stores/player'
import { SUPPORTED_LOCALES } from '@/i18n'
import { useKeyboard } from '@/composables/useKeyboard'
import PlayerBar from '@/components/PlayerBar.vue'
import ScanButton from '@/components/ScanButton.vue'
import ScanProgress from '@/components/ScanProgress.vue'
import SearchBox from '@/components/SearchBox.vue'
import ToastHost from '@/components/ToastHost.vue'
import ThemeToggle from '@/components/ThemeToggle.vue'
import MobileDrawer from '@/components/MobileDrawer.vue'
import MobileSearchOverlay from '@/components/MobileSearchOverlay.vue'
import AppFooter from '@/components/AppFooter.vue'
import QueuePanel from '@/components/QueuePanel.vue'

const auth = useAuthStore()
const appStore = useAppStore()
const router = useRouter()
const route = useRoute()
const localeStore = useLocaleStore()
const scan = useScanStore()
const favorites = useFavoritesStore()
const playlistsStore = usePlaylistsStore()
const player = usePlayerStore()

const isNowPlaying = computed(() => route.name === 'now-playing')

const drawerOpen = ref(false)
const mobileSearchOpen = ref(false)
const queueOpen = ref(false)

useKeyboard()

onMounted(() => {
  appStore.load()
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

watch(() => route.fullPath, () => {
  drawerOpen.value = false
  mobileSearchOpen.value = false
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
      <!-- Desktop header -->
      <div class="hidden md:flex px-6 py-3 items-center gap-6 max-w-6xl mx-auto w-full">
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

        <div class="ml-auto flex items-center gap-2 text-sm shrink-0">
          <RouterLink
            to="/settings"
            class="w-9 h-9 rounded-full bg-surface-2 border border-app
                   flex items-center justify-center text-muted
                   hover:text-app hover:border-hi transition-colors"
            :aria-label="$t('settings.title')"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                 class="w-4 h-4 fill-none" stroke="currentColor" stroke-width="2"
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
            class="h-9 border border-app rounded-full px-3 text-sm bg-surface-2 text-app
                   hover:border-hi transition-colors"
            :aria-label="$t('nav.language')"
          >
            <option v-for="l in SUPPORTED_LOCALES" :key="l" :value="l">{{ l.toUpperCase() }}</option>
          </select>
          <span class="text-muted px-2">{{ auth.user?.username }}</span>
          <button
            @click="logout"
            class="h-9 px-4 rounded-full text-sm font-medium text-app
                   bg-surface-2 border border-app
                   hover:bg-danger hover:border-danger hover:text-white
                   transition-colors"
          >
            {{ $t('nav.logout') }}
          </button>
        </div>
      </div>

      <!-- Mobile header -->
      <div class="flex md:hidden px-3 py-2 items-center gap-3">
        <button
          @click="drawerOpen = true"
          class="w-10 h-10 rounded-full bg-surface-2 border border-app
                 flex items-center justify-center text-app
                 active:bg-surface active:scale-95 transition-all"
          :aria-label="$t('nav.menu')"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
               class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <path d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>

        <RouterLink to="/" class="text-lg font-semibold tracking-tight text-app">
          {{ $t('app.title') }}
        </RouterLink>

        <button
          @click="mobileSearchOpen = true"
          class="ml-auto w-10 h-10 rounded-full bg-surface-2 border border-app
                 flex items-center justify-center text-app
                 active:bg-surface active:scale-95 transition-all"
          :aria-label="$t('search.placeholder')"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
               class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2"
               stroke-linecap="round" stroke-linejoin="round">
            <circle cx="11" cy="11" r="8" />
            <path d="m21 21-4.3-4.3" />
          </svg>
        </button>
      </div>
    </header>

    <ScanProgress v-if="!isNowPlaying" />

    <!-- Bottom padding covers fixed footer + (optional) player bar -->
    <main
      class="flex-1 relative"
      :class="[
        !isNowPlaying && 'pb-0',
        player.current && !isNowPlaying && 'pb-24 md:pb-40',
      ]"
    >
      <RouterView v-slot="{ Component }">
        <Transition name="page" mode="out-in">
          <component :is="Component" :key="route.path" />
        </Transition>
      </RouterView>
    </main>

    <!-- Fixed bottom stack: player bar sits above the footer -->
    <div class="fixed bottom-0 left-0 right-0 z-30">
      <PlayerBar
        v-if="auth.accessToken && !isNowPlaying"
        @open-queue="queueOpen = true"
      />
      <AppFooter v-if="!isNowPlaying" />
    </div>

    <ToastHost />

    <MobileDrawer :open="drawerOpen" @close="drawerOpen = false" />
    <MobileSearchOverlay :open="mobileSearchOpen" @close="mobileSearchOpen = false" />
    <QueuePanel :open="queueOpen" @close="queueOpen = false" />
  </div>
</template>

