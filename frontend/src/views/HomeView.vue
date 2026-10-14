<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import { RouterLink } from 'vue-router'

const auth = useAuthStore()
</script>

<template>
  <div class="p-8">
    <h1 class="text-3xl font-bold mb-2">Welcome back, {{ auth.user?.username ?? 'friend' }}</h1>
    <p class="text-gray-600 mb-6">Your library is ready.</p>

    <div class="flex gap-4">
      <RouterLink to="/artists" class="px-4 py-2 border rounded hover:bg-gray-100">Browse artists</RouterLink>
    </div>
  </div>
</template>
