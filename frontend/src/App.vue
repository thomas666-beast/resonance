<script setup lang="ts">
import { RouterView, RouterLink, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()

async function logout() {
  await auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <div class="min-h-screen flex flex-col">
    <header v-if="auth.accessToken" class="border-b px-6 py-3 flex items-center gap-6 bg-white">
      <RouterLink to="/" class="font-bold">Resonance</RouterLink>
      <RouterLink to="/artists" class="text-sm hover:underline">Artists</RouterLink>
      <div class="ml-auto flex items-center gap-4 text-sm">
        <span class="text-gray-600">{{ auth.user?.username }}</span>
        <button @click="logout" class="text-red-600 hover:underline">Logout</button>
      </div>
    </header>
    <main class="flex-1 bg-gray-50">
      <RouterView />
    </main>
  </div>
</template>
