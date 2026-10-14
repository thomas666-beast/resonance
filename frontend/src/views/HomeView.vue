<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import { RouterLink } from 'vue-router'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
const auth = useAuthStore()
</script>

<template>
  <div class="p-8">
    <h1 class="text-3xl font-bold mb-2">
      {{ $t('app.welcome', { name: auth.user?.username ?? $t('app.friend') }) }}
    </h1>
    <p class="text-gray-600 mb-6">{{ $t('app.libraryReady') }}</p>

    <div class="flex gap-4">
      <RouterLink to="/artists" class="px-4 py-2 border rounded hover:bg-gray-100">
        {{ $t('artists.browse') }}
      </RouterLink>
    </div>
  </div>
</template>
