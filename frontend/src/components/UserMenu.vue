<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { useLocaleStore } from '@/stores/locale'
import { useThemeStore } from '@/stores/theme'
import { useScanStore } from '@/stores/scan'
import { usePlayerStore } from '@/stores/player'
import { SUPPORTED_LOCALES } from '@/i18n'

const { t } = useI18n()
const router = useRouter()
const auth = useAuthStore()
const localeStore = useLocaleStore()
const theme = useThemeStore()
const scan = useScanStore()
const player = usePlayerStore()

const open = ref(false)
const root = ref<HTMLElement | null>(null)

function toggle(e: MouseEvent) {
  e.stopPropagation()
  open.value = !open.value
}

function close() {
  open.value = false
}

function onDocClick(e: MouseEvent) {
  if (root.value && !root.value.contains(e.target as Node)) close()
}

onMounted(() => document.addEventListener('click', onDocClick))
onUnmounted(() => document.removeEventListener('click', onDocClick))

async function logout() {
  close()
  scan.disconnect()
  player.stop()
  await auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <div ref="root" class="relative">
    <button
      @click="toggle"
      class="flex items-center gap-2 px-2 py-1 rounded-full bg-surface-2 border border-app
             hover:border-hi transition-colors"
      :aria-expanded="open"
    >
      <span class="w-7 h-7 rounded-full bg-accent text-white text-xs font-medium
                   flex items-center justify-center">
        {{ auth.user?.username?.[0]?.toUpperCase() ?? '?' }}
      </span>
    </button>

    <Transition
      enter-active-class="transition duration-100 ease-out"
      enter-from-class="opacity-0 scale-95"
      enter-to-class="opacity-100 scale-100"
      leave-active-class="transition duration-75 ease-in"
      leave-from-class="opacity-100 scale-100"
      leave-to-class="opacity-0 scale-95"
    >
      <div
        v-if="open"
        class="absolute right-0 mt-1 w-56 bg-surface border border-app rounded-xl
               shadow-2xl z-40 py-1 text-sm text-app origin-top-right"
      >
        <div class="px-4 py-2 border-b border-app">
          <div class="font-medium truncate">{{ auth.user?.username }}</div>
          <div v-if="auth.isAdmin" class="text-xs text-accent">{{ $t('admin.roleAdmin') }}</div>
        </div>

        <!-- Theme -->
        <div class="px-4 py-2 flex items-center justify-between">
          <span class="text-muted">{{ $t('nav.theme') }}</span>
          <select
            :value="theme.theme"
            @change="theme.set(($event.target as HTMLSelectElement).value as any)"
            class="border border-app rounded-full px-2 py-0.5 text-xs bg-surface-2 text-app"
          >
            <option value="dark">{{ $t('theme.dark') }}</option>
            <option value="light">{{ $t('theme.light') }}</option>
            <option value="system">{{ $t('theme.system') }}</option>
          </select>
        </div>

        <!-- Language -->
        <div class="px-4 py-2 flex items-center justify-between">
          <span class="text-muted">{{ $t('nav.language') }}</span>
          <select
            v-model="localeStore.current"
            @change="localeStore.set(localeStore.current)"
            class="border border-app rounded-full px-2 py-0.5 text-xs bg-surface-2 text-app"
          >
            <option v-for="l in SUPPORTED_LOCALES" :key="l" :value="l">{{ l.toUpperCase() }}</option>
          </select>
        </div>

        <RouterLink
          to="/settings"
          @click="close"
          class="block px-4 py-2 hover:bg-surface-2 transition-colors"
        >
          {{ $t('nav.settings') }}
        </RouterLink>

        <div class="border-t border-app my-1" />

        <button
          @click="logout"
          class="block w-full text-left px-4 py-2 text-danger hover:bg-surface-2 transition-colors"
        >
          {{ $t('nav.logout') }}
        </button>
      </div>
    </Transition>
  </div>
</template>
