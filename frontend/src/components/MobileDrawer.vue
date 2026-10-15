<script setup lang="ts">
import { watch, onUnmounted } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { useLocaleStore } from '@/stores/locale'
import { useThemeStore } from '@/stores/theme'
import { useScanStore } from '@/stores/scan'
import { usePlayerStore } from '@/stores/player'
import { SUPPORTED_LOCALES } from '@/i18n'
import ThemeToggle from './ThemeToggle.vue'
import ScanButton from './ScanButton.vue'

const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{ (e: 'close'): void }>()

const { t } = useI18n()
const router = useRouter()
const auth = useAuthStore()
const localeStore = useLocaleStore()
const theme = useThemeStore()
const scan = useScanStore()
const player = usePlayerStore()

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape' && props.open) emit('close')
}

watch(() => props.open, (open) => {
  document.body.style.overflow = open ? 'hidden' : ''
})

onUnmounted(() => {
  document.body.style.overflow = ''
})

document.addEventListener('keydown', onKey)
onUnmounted(() => document.removeEventListener('keydown', onKey))

async function logout() {
  emit('close')
  scan.disconnect()
  player.stop()
  await auth.logout()
  router.push({ name: 'login' })
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
      enter-from-class="-translate-x-full"
      enter-to-class="translate-x-0"
      leave-active-class="transition-transform duration-150 ease-in"
      leave-from-class="translate-x-0"
      leave-to-class="-translate-x-full"
    >
      <aside
        v-if="open"
        class="fixed top-0 left-0 bottom-0 w-72 max-w-[85vw] z-50 bg-surface border-r border-app
               flex flex-col md:hidden"
        role="dialog"
        aria-modal="true"
        :aria-label="t('nav.menu')"
      >
        <!-- Header -->
        <div class="px-5 py-4 border-b border-app flex items-center">
          <RouterLink to="/" class="text-lg font-semibold tracking-tight text-app" @click="emit('close')">
            {{ $t('app.title') }}
          </RouterLink>
          <button
            @click="emit('close')"
            class="ml-auto p-2 rounded-full hover-surface text-muted transition-colors"
            :aria-label="t('common.close')"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                 class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
              <path d="M18 6 6 18M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Nav -->
        <nav class="flex-1 overflow-y-auto scroll-slim py-3">
          <RouterLink
            v-for="item in [
              { to: '/',          label: t('nav.home') },
              { to: '/artists',   label: t('nav.artists') },
              { to: '/albums',    label: t('nav.albums') },
              { to: '/favorites', label: t('nav.favorites') },
              { to: '/playlists', label: t('nav.playlists') },
              ...(auth.isAdmin ? [{ to: '/admin', label: t('nav.admin') }] : []),
            ]"
            :key="item.to"
            :to="item.to"
            @click="emit('close')"
            class="block px-5 py-3 text-sm font-medium text-app hover-surface transition-colors"
            active-class="bg-surface-2 text-accent"
          >
            {{ item.label }}
          </RouterLink>

          <div class="border-t border-app my-3" />

          <!-- Theme -->
          <div class="px-5 py-3 flex items-center gap-3 text-sm text-app">
            <span class="flex-1">{{ $t('nav.theme') }}</span>
            <ThemeToggle />
          </div>

          <!-- Language -->
          <div class="px-5 py-3 flex items-center gap-3 text-sm text-app">
            <span class="flex-1">{{ $t('nav.language') }}</span>
            <select
              v-model="localeStore.current"
              @change="localeStore.set(localeStore.current)"
              class="border border-app rounded-full px-3 py-1 text-sm bg-surface text-app"
            >
              <option v-for="l in SUPPORTED_LOCALES" :key="l" :value="l">{{ l.toUpperCase() }}</option>
            </select>
          </div>

          <div class="border-t border-app my-3" />

          <!-- Scan -->
          <div class="px-5 py-3">
            <ScanButton class="w-full justify-center" />
          </div>

          <!-- Settings -->
          <RouterLink
            to="/settings"
            @click="emit('close')"
            class="block px-5 py-3 text-sm font-medium text-app hover-surface transition-colors"
            active-class="bg-surface-2 text-accent"
          >
            {{ $t('nav.settings') }}
          </RouterLink>
        </nav>

        <!-- User -->
        <div class="border-t border-app px-5 py-4">
          <div class="text-sm text-app font-medium">{{ auth.user?.username }}</div>
          <div v-if="auth.isAdmin" class="text-xs text-dim mt-0.5">{{ $t('admin.roleAdmin') }}</div>

          <button
            @click="logout"
            class="mt-3 w-full text-left px-3 py-2 rounded-lg text-sm text-muted
                   hover-surface hover:text-danger transition-colors"
          >
            {{ $t('nav.logout') }}
          </button>
        </div>
      </aside>
    </Transition>
  </Teleport>
</template>