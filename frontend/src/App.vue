<script setup lang="ts">
import { onMounted, onUnmounted, watch } from 'vue'
import { RouterView, RouterLink, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useLocaleStore } from '@/stores/locale'
import { useScanStore } from '@/stores/scan'
import { useFavoritesStore } from '@/stores/favorites'
import { SUPPORTED_LOCALES } from '@/i18n'
import PlayerBar from '@/components/PlayerBar.vue'
import ScanButton from '@/components/ScanButton.vue'
import ScanProgress from '@/components/ScanProgress.vue'

const auth = useAuthStore()
const router = useRouter()
const localeStore = useLocaleStore()
const scan = useScanStore()
const favorites = useFavoritesStore()

onMounted(() => {
  if (auth.accessToken) {
    scan.connect()
    favorites.load()
  }
})

watch(() => auth.accessToken, (t) => {
  if (t) {
    scan.connect()
    favorites.load()
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
  <div class="min-h-screen flex flex-col">
    <header
      v-if="auth.accessToken"
      class="sticky top-0 z-20 border-b border-stone-200 bg-white/90 backdrop-blur-sm"
    >
      <div class="px-6 py-3 flex items-center gap-6 max-w-6xl mx-auto w-full">
        <RouterLink to="/" class="text-lg font-semibold tracking-tight">
          {{ $t('app.title') }}
        </RouterLink>
        <nav class="flex items-center gap-1 text-sm">
          <RouterLink to="/artists"
            class="px-3 py-1.5 rounded-full hover:bg-stone-100 transition-colors"
            active-class="bg-stone-100 font-medium">{{ $t('nav.artists') }}</RouterLink>
          <RouterLink to="/favorites"
            class="px-3 py-1.5 rounded-full hover:bg-stone-100 transition-colors"
            active-class="bg-stone-100 font-medium">{{ $t('nav.favorites') }}</RouterLink>
        </nav>

        <div class="ml-auto flex items-center gap-3 text-sm">
          <ScanButton />
          <select
            v-model="localeStore.current"
            @change="localeStore.set(localeStore.current)"
            class="border border-stone-200 rounded-full px-3 py-1 text-sm bg-white"
            :aria-label="$t('nav.language')"
          >
            <option v-for="l in SUPPORTED_LOCALES" :key="l" :value="l">{{ l.toUpperCase() }}</option>
          </select>
          <span class="text-stone-600">{{ auth.user?.username }}</span>
          <button @click="logout" class="text-stone-500 hover:text-red-600 transition-colors">
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
  </div>
</template>
