<script setup lang="ts">
import { ref } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
const auth = useAuthStore()
const router = useRouter()

const username = ref('')
const password = ref('')
const error = ref<string | null>(null)
const loading = ref(false)

async function submit() {
  error.value = null
  loading.value = true
  try {
    await auth.login(username.value, password.value)
    router.push({ name: 'home' })
  } catch (e: any) {
    error.value = e.response?.data?.error ?? t('auth.errors.loginFailed')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50">
    <form @submit.prevent="submit" class="bg-white p-8 rounded-lg shadow w-full max-w-sm">
      <h1 class="text-2xl font-bold mb-6">{{ $t('auth.signInTo') }}</h1>

      <label class="block mb-4">
        <span class="text-sm text-gray-700">{{ $t('auth.username') }}</span>
        <input
          v-model="username"
          type="text"
          required
          autocomplete="username"
          class="mt-1 w-full border rounded px-3 py-2"
        />
      </label>

      <label class="block mb-6">
        <span class="text-sm text-gray-700">{{ $t('auth.password') }}</span>
        <input
          v-model="password"
          type="password"
          required
          autocomplete="current-password"
          class="mt-1 w-full border rounded px-3 py-2"
        />
      </label>

      <p v-if="error" class="text-red-600 text-sm mb-4">{{ error }}</p>

      <button
        type="submit"
        :disabled="loading"
        class="w-full bg-black text-white py-2 rounded disabled:opacity-50"
      >
        {{ loading ? $t('auth.signingIn') : $t('auth.signIn') }}
      </button>

      <p class="text-sm text-gray-600 mt-4 text-center">
        {{ $t('auth.noAccount') }}
        <RouterLink to="/register" class="underline">{{ $t('auth.registerLink') }}</RouterLink>
      </p>
    </form>
  </div>
</template>
