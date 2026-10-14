<script setup lang="ts">
import { RouterView, RouterLink, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useLocaleStore } from '@/stores/locale'
import { SUPPORTED_LOCALES } from '@/i18n'

const auth = useAuthStore()
const router = useRouter()
const localeStore = useLocaleStore()

async function logout() {
  await auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <div class="min-h-screen flex flex-col">
    <header v-if="auth.accessToken" class="border-b px-6 py-3 flex items-center gap-6 bg-white">
      <RouterLink to="/" class="font-bold">{{ $t('app.title') }}</RouterLink>
      <RouterLink to="/artists" class="text-sm hover:underline">{{ $t('nav.artists') }}</RouterLink>

      <div class="ml-auto flex items-center gap-4 text-sm">
        <select
          v-model="localeStore.current"
          @change="localeStore.set(localeStore.current)"
          class="border rounded px-2 py-1 text-sm"
          :aria-label="$t('nav.language')"
        >
          <option v-for="l in SUPPORTED_LOCALES" :key="l" :value="l">
            {{ l.toUpperCase() }}
          </option>
        </select>
        <span class="text-gray-600">{{ auth.user?.username }}</span>
        <button @click="logout" class="text-red-600 hover:underline">{{ $t('nav.logout') }}</button>
      </div>
    </header>
    <main class="flex-1 bg-gray-50">
      <RouterView />
    </main>
  </div>
</template>
