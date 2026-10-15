<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import api from '@/api/client'
import { useToastStore } from '@/stores/toast'

const { t } = useI18n()
const toast = useToastStore()

// ── change password ─────────────────────────────────────

const currentPassword = ref('')
const newPassword     = ref('')
const confirmPassword = ref('')
const changing        = ref(false)

async function changePassword() {
  if (newPassword.value !== confirmPassword.value) {
    toast.error(t('auth.errors.passwordsMismatch'))
    return
  }
  if (newPassword.value.length < 8) {
    toast.error(t('auth.errors.passwordTooShort'))
    return
  }
  if (newPassword.value === currentPassword.value) {
    toast.error(t('settings.passwordUnchanged'))
    return
  }

  changing.value = true
  try {
    await api.post('/auth/change-password', {
      current_password: currentPassword.value,
      new_password:     newPassword.value,
    })
    currentPassword.value = ''
    newPassword.value = ''
    confirmPassword.value = ''
    toast.success(t('settings.passwordChanged'))
  } catch (e: any) {
    const code = e.response?.data?.error
    if (code === 'invalid_password') {
      toast.error(t('settings.wrongCurrentPassword'))
    } else {
      toast.error(t('toasts.genericError'))
    }
  } finally {
    changing.value = false
  }
}

// ── subsonic password ───────────────────────────────────

const configured = ref(false)
const password   = ref('')
const confirm    = ref('')
const loading    = ref(false)

async function load() {
  const { data } = await api.get('/me/subsonic')
  configured.value = data.configured
}

async function save() {
  if (password.value !== confirm.value) {
    toast.error(t('auth.errors.passwordsMismatch'))
    return
  }
  if (password.value && password.value.length < 8) {
    toast.error(t('auth.errors.passwordTooShort'))
    return
  }
  loading.value = true
  try {
    const { data } = await api.post('/me/subsonic-password', {
      subsonic_password: password.value,
    })
    configured.value = data.configured
    password.value = ''
    confirm.value = ''
    toast.success(configured.value
      ? t('settings.subsonicSet')
      : t('settings.subsonicCleared'))
  } catch {
    toast.error(t('toasts.genericError'))
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="p-4 md:p-8 pb-32 max-w-2xl mx-auto text-app">
    <h1 class="text-display mb-8">{{ $t('settings.title') }}</h1>

    <!-- Change password -->
    <section class="bg-surface border border-app rounded-xl p-6 mb-6 anim-fade-slide">
      <h2 class="text-heading mb-2">{{ $t('settings.changePasswordTitle') }}</h2>
      <p class="text-muted text-sm leading-relaxed mb-4">
        {{ $t('settings.changePasswordDescription') }}
      </p>

      <form @submit.prevent="changePassword" class="space-y-4">
        <label class="block">
          <span class="text-sm text-muted">{{ $t('settings.currentPassword') }}</span>
          <input
            v-model="currentPassword"
            type="password"
            required
            autocomplete="current-password"
            class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                   px-3 py-2 focus:outline-none focus:border-accent"
          />
        </label>

        <label class="block">
          <span class="text-sm text-muted">{{ $t('settings.newPassword') }}</span>
          <input
            v-model="newPassword"
            type="password"
            required
            autocomplete="new-password"
            class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                   px-3 py-2 focus:outline-none focus:border-accent"
          />
        </label>

        <label class="block">
          <span class="text-sm text-muted">{{ $t('auth.confirmPassword') }}</span>
          <input
            v-model="confirmPassword"
            type="password"
            required
            autocomplete="new-password"
            class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                   px-3 py-2 focus:outline-none focus:border-accent"
          />
        </label>

        <button
          type="submit"
          :disabled="changing"
          class="px-4 py-2 bg-accent text-white rounded-full text-sm font-medium
                 hover:opacity-90 disabled:opacity-50 transition-opacity"
        >
          {{ changing ? $t('common.loading') : $t('settings.changePassword') }}
        </button>
      </form>
    </section>

    <!-- Subsonic password -->
    <section class="bg-surface border border-app rounded-xl p-6 anim-fade-slide">
      <h2 class="text-heading mb-2">{{ $t('settings.subsonicTitle') }}</h2>
      <p class="text-muted text-sm leading-relaxed mb-4">
        {{ $t('settings.subsonicDescription') }}
      </p>

      <div class="text-sm mb-5">
        <span class="text-muted">{{ $t('settings.status') }}:</span>
        <span class="ml-2 px-2 py-0.5 rounded-full text-xs"
              :class="configured
                ? 'bg-accent/20 text-accent'
                : 'bg-surface-2 text-muted'">
          {{ configured ? $t('settings.configured') : $t('settings.notConfigured') }}
        </span>
      </div>

      <form @submit.prevent="save" class="space-y-4">
        <label class="block">
          <span class="text-sm text-muted">{{ $t('settings.subsonicPassword') }}</span>
          <input
            v-model="password"
            type="password"
            autocomplete="new-password"
            class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                   px-3 py-2 focus:outline-none focus:border-accent"
          />
        </label>

        <label class="block">
          <span class="text-sm text-muted">{{ $t('auth.confirmPassword') }}</span>
          <input
            v-model="confirm"
            type="password"
            autocomplete="new-password"
            class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                   px-3 py-2 focus:outline-none focus:border-accent"
          />
        </label>

        <p class="text-xs text-dim">{{ $t('settings.subsonicClear') }}</p>

        <button
          type="submit"
          :disabled="loading"
          class="px-4 py-2 bg-accent text-white rounded-full text-sm font-medium
                 hover:opacity-90 disabled:opacity-50 transition-opacity"
        >
          {{ loading ? $t('common.loading') : $t('settings.save') }}
        </button>
      </form>
    </section>
  </div>
</template>
