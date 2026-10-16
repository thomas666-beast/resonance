<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { useScanStore } from '@/stores/scan'
import { usePlayerStore } from '@/stores/player'
import ScanButton from './ScanButton.vue'
import AppLogo from './AppLogo.vue'

const { t } = useI18n()
const router = useRouter()
const auth = useAuthStore()
const scan = useScanStore()
const player = usePlayerStore()

const STORAGE_KEY = 'resonance_sidebar_collapsed'
const collapsed = ref(false)

onMounted(() => {
  collapsed.value = localStorage.getItem(STORAGE_KEY) === '1'
})

function toggle() {
  collapsed.value = !collapsed.value
  localStorage.setItem(STORAGE_KEY, collapsed.value ? '1' : '0')
}

const navGroups = computed(() => [
  {
    label: t('nav.groupLibrary'),
    items: [
      { to: '/',          label: t('nav.home'),      icon: 'home' },
      { to: '/artists',   label: t('nav.artists'),   icon: 'artist' },
      { to: '/albums',    label: t('nav.albums'),    icon: 'album' },
      { to: '/favorites', label: t('nav.favorites'), icon: 'heart' },
      { to: '/playlists', label: t('nav.playlists'), icon: 'list' },
    ],
  },
  {
    label: t('nav.groupMedia'),
    items: [
      { to: '/radio',     label: t('nav.radio'),     icon: 'radio' },
      { to: '/podcasts',  label: t('nav.podcasts'),  icon: 'mic' },
    ],
  },
  {
    label: t('nav.groupSystem'),
    items: [
      ...(auth.isAdmin
        ? [{ to: '/admin', label: t('nav.admin'), icon: 'shield' }]
        : []),
      { to: '/settings', label: t('nav.settings'), icon: 'cog' },
    ],
  },
])

const ICONS: Record<string, string> = {
  home:   'M3 12l9-9 9 9M5 10v10a1 1 0 0 0 1 1h4v-6h4v6h4a1 1 0 0 0 1-1V10',
  artist: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  album:  'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zM12 14a2 2 0 1 1 0-4 2 2 0 0 1 0 4z',
  heart:  'M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z',
  list:   'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01',
  radio:  'M4.22 4.22a12 12 0 0 0 0 15.56M19.78 4.22a12 12 0 0 1 0 15.56M7.76 7.76a6 6 0 0 0 0 8.48M16.24 7.76a6 6 0 0 1 0 8.48M12 12a.5.5 0 1 0 0 1 .5.5 0 0 0 0-1z',
  mic:    'M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3zM19 10v2a7 7 0 0 1-14 0v-2M12 19v4M8 23h8',
  shield: 'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z',
  cog:    'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z',
}

async function logout() {
  scan.disconnect()
  player.stop()
  await auth.logout()
  router.push({ name: 'login' })
}

import { watchEffect } from 'vue'

watchEffect(() => {
  document.documentElement.style.setProperty(
    '--sidebar-width',
    collapsed.value ? '4rem' : '15rem',
  )
})
</script>

<template>
  <aside
    class="hidden lg:flex flex-col border-r border-app bg-surface/60 backdrop-blur-sm
           sticky top-0 h-screen shrink-0 transition-[width] duration-200"
    :class="collapsed ? 'w-16' : 'w-60'"
  >
    <!-- Header -->
    <div class="h-16 border-b border-app flex items-center px-4 shrink-0">
      <RouterLink to="/" class="flex items-center" :title="$t('app.title')">
        <AppLogo v-if="!collapsed" variant="wordmark" :height="26" />
        <AppLogo v-else              variant="icon"     :height="32" />
      </RouterLink>
    </div>

    <!-- Nav -->
    <nav class="flex-1 overflow-y-auto scroll-slim py-3">
      <div v-for="group in navGroups" :key="group.label" class="mb-3">
        <div
          v-if="!collapsed"
          class="px-4 py-1 text-[10px] font-semibold uppercase tracking-widest text-dim"
        >
          {{ group.label }}
        </div>
        <div class="space-y-0.5 px-2">
          <RouterLink
            v-for="item in group.items"
            :key="item.to"
            :to="item.to"
            class="flex items-center gap-3 px-3 py-2 rounded-lg text-sm
                   text-app hover:bg-surface-2 transition-colors"
            active-class="bg-surface-2 text-accent font-medium"
            :title="collapsed ? item.label : undefined"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                 class="w-5 h-5 fill-none shrink-0"
                 stroke="currentColor" stroke-width="1.75"
                 stroke-linecap="round" stroke-linejoin="round">
              <path :d="ICONS[item.icon]" />
            </svg>
            <span v-if="!collapsed" class="truncate">{{ item.label }}</span>
          </RouterLink>
        </div>
      </div>
    </nav>

    <!-- Footer: scan + collapse + user -->
    <div class="border-t border-app p-2 space-y-1">
      <div v-if="!collapsed" class="px-1 pb-1">
        <ScanButton class="w-full justify-center" />
      </div>

      <button
        @click="toggle"
        class="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm
               text-muted hover:bg-surface-2 hover:text-app transition-colors"
        :title="collapsed ? $t('nav.expand') : $t('nav.collapse')"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-5 h-5 fill-none shrink-0 transition-transform"
             :class="collapsed ? 'rotate-180' : ''"
             stroke="currentColor" stroke-width="1.75"
             stroke-linecap="round" stroke-linejoin="round">
          <path d="M15 18l-6-6 6-6" />
        </svg>
        <span v-if="!collapsed">{{ $t('nav.collapse') }}</span>
      </button>

      <button
        @click="logout"
        class="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm
               text-muted hover:bg-surface-2 hover:text-danger transition-colors"
        :title="collapsed ? $t('nav.logout') : undefined"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-5 h-5 fill-none shrink-0"
             stroke="currentColor" stroke-width="1.75"
             stroke-linecap="round" stroke-linejoin="round">
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
        </svg>
        <span v-if="!collapsed" class="truncate">{{ $t('nav.logout') }}</span>
      </button>
    </div>
  </aside>
</template>
