<script setup lang="ts">
import { onMounted, onUnmounted, watch, computed, ref } from 'vue'
import { RouterView, RouterLink, useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useAppStore } from '@/stores/app'
import { useScanStore } from '@/stores/scan'
import { useFavoritesStore } from '@/stores/favorites'
import { usePlaylistsStore } from '@/stores/playlists'
import { usePlayerStore } from '@/stores/player'
import { useRadioStore } from '@/stores/radio'
import { usePodcastsStore } from '@/stores/podcasts'
import { useKeyboard } from '@/composables/useKeyboard'
import PlayerBar from '@/components/PlayerBar.vue'
import ScanButton from '@/components/ScanButton.vue'
import ScanProgress from '@/components/ScanProgress.vue'
import SearchBox from '@/components/SearchBox.vue'
import ToastHost from '@/components/ToastHost.vue'
import MobileDrawer from '@/components/MobileDrawer.vue'
import MobileSearchOverlay from '@/components/MobileSearchOverlay.vue'
import AppFooter from '@/components/AppFooter.vue'
import AppSidebar from '@/components/AppSidebar.vue'
import AppLogo from '@/components/AppLogo.vue'
import UserMenu from '@/components/UserMenu.vue'
import QueuePanel from '@/components/QueuePanel.vue'

const auth = useAuthStore()
const appStore = useAppStore()
const router = useRouter()
const route = useRoute()
const scan = useScanStore()
const favorites = useFavoritesStore()
const playlistsStore = usePlaylistsStore()
const radioStore = useRadioStore()
const podcastsStore = usePodcastsStore()
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
    radioStore.load()
    radioStore.connect()
    podcastsStore.connect()
  }
})

watch(() => auth.accessToken, (t) => {
  if (t) {
    scan.connect()
    favorites.load()
    playlistsStore.load()
    radioStore.load()
    radioStore.connect()
    podcastsStore.connect()
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
  <!-- Login / register / now-playing: no sidebar, no top nav -->
  <div v-if="!auth.accessToken || isNowPlaying" class="min-h-screen flex flex-col bg-app text-app">
    <ScanProgress v-if="!isNowPlaying && auth.accessToken" />
    <main class="flex-1" :class="!isNowPlaying && 'pb-12'">
      <RouterView v-slot="{ Component }">
        <Transition name="page" mode="out-in">
          <component :is="Component" :key="route.path" />
        </Transition>
      </RouterView>
    </main>
    <AppFooter v-if="!isNowPlaying" />
    <ToastHost />
  </div>

  <!-- Authenticated shell -->
  <div v-else class="min-h-screen flex bg-app text-app">
    <AppSidebar />

    <div class="flex-1 flex flex-col min-w-0">
      <header class="sticky top-0 z-20 border-b border-app bg-surface/80 backdrop-blur-sm">
        <!-- Desktop top bar (lg+) -->
        <div class="hidden lg:flex px-6 h-16 items-center gap-4">
          <SearchBox />
          <div class="ml-auto flex items-center gap-2 text-sm shrink-0">
            <ScanButton />
            <UserMenu />
          </div>
        </div>

        <!-- Tablet and mobile top bar (< lg) -->
        <div class="flex lg:hidden px-3 py-2 items-center gap-3">
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

          <RouterLink to="/" class="flex items-center" :title="$t('app.title')">
            <AppLogo variant="wordmark" :height="50" />
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

      <ScanProgress />

      <main
        class="flex-1"
        :class="(player.current || player.currentRadio || player.currentEpisode) ? 'pb-24' : 'pb-12'"
      >
        <RouterView v-slot="{ Component }">
          <Transition name="page" mode="out-in">
            <component :is="Component" :key="route.path" />
          </Transition>
        </RouterView>
      </main>

      <div class="fixed bottom-0 left-0 right-0 lg:left-[var(--sidebar-width,15rem)] z-30 pointer-events-none">
        <div class="pointer-events-auto">
          <PlayerBar @open-queue="queueOpen = true" />
          <AppFooter />
        </div>
      </div>
    </div>

    <ToastHost />

    <MobileDrawer :open="drawerOpen" @close="drawerOpen = false" />
    <MobileSearchOverlay :open="mobileSearchOpen" @close="mobileSearchOpen = false" />
    <QueuePanel :open="queueOpen" @close="queueOpen = false" />
  </div>
</template>
