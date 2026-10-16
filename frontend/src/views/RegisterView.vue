<script setup lang="ts">
import { ref } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import api from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import { useI18n } from 'vue-i18n'
import AppLogo from '@/components/AppLogo.vue'

const { t } = useI18n()
const auth = useAuthStore()
const router = useRouter()

const username = ref('')
const email = ref('')
const password = ref('')
const confirm = ref('')
const error = ref<string | null>(null)
const loading = ref(false)

async function submit() {
  error.value = null

  if (password.value !== confirm.value) {
    error.value = t('auth.errors.passwordsMismatch')
    return
  }
  if (password.value.length < 8) {
    error.value = t('auth.errors.passwordTooShort')
    return
  }

  loading.value = true
  try {
    const { data } = await api.post('/auth/register', {
      username: username.value,
      email: email.value || undefined,
      password: password.value,
    })
    auth.setAccessToken(data.access_token)
    router.push({ name: 'home' })
  } catch (e: any) {
    error.value = e.response?.data?.error ?? t('auth.errors.registerFailed')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-app text-app">
    <div class="flex flex-col items-center w-full max-w-sm">
      <AppLogo variant="wordmark" :height="40" class="mb-8" />
      <form @submit.prevent="submit" class="bg-surface border border-app p-8 rounded-xl shadow-xl w-full max-w-sm">
        <h1 class="text-2xl font-bold mb-6">{{ $t('auth.registerTitle') }}</h1>

        <label class="block mb-4">
          <span class="text-sm text-muted">{{ $t('auth.username') }}</span>
          <input v-model="username" type="text" required autocomplete="username"
                class="mt-1 w-full border border-app bg-surface-2 text-app rounded px-3 py-2 focus:outline-none focus:border-accent" />
        </label>

        <label class="block mb-4">
          <span class="text-sm text-muted">{{ $t('auth.emailOptional') }}</span>
          <input v-model="email" type="email" autocomplete="email"
                class="mt-1 w-full border border-app bg-surface-2 text-app rounded px-3 py-2 focus:outline-none focus:border-accent" />
        </label>

        <label class="block mb-4">
          <span class="text-sm text-muted">{{ $t('auth.password') }}</span>
          <input v-model="password" type="password" required autocomplete="new-password"
                class="mt-1 w-full border border-app bg-surface-2 text-app rounded px-3 py-2 focus:outline-none focus:border-accent" />
        </label>

        <label class="block mb-6">
          <span class="text-sm text-muted">{{ $t('auth.confirmPassword') }}</span>
          <input v-model="confirm" type="password" required autocomplete="new-password"
                class="mt-1 w-full border border-app bg-surface-2 text-app rounded px-3 py-2 focus:outline-none focus:border-accent" />
        </label>

        <p v-if="error" class="text-danger text-sm mb-4">{{ error }}</p>

        <button type="submit" :disabled="loading"
                class="w-full bg-accent text-white py-2 rounded-full font-medium disabled:opacity-50 hover:opacity-90 transition-opacity">
          {{ loading ? $t('auth.registering') : $t('auth.createAccount') }}
        </button>

        <p class="text-sm text-muted mt-4 text-center">
          {{ $t('auth.hasAccount') }}
          <RouterLink to="/login" class="underline text-accent">{{ $t('auth.signInLink') }}</RouterLink>
        </p>
      </form>
    </div>
  </div>
</template>
