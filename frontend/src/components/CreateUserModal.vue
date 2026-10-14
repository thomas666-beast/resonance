<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import api from '@/api/client'
import Modal from './Modal.vue'

const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{
  (e: 'close'): void
  (e: 'created'): void
}>()

const { t } = useI18n()

const username = ref('')
const email    = ref('')
const password = ref('')
const role     = ref<'user' | 'admin'>('user')
const error    = ref<string | null>(null)
const loading  = ref(false)

watch(() => props.open, (open) => {
  if (open) {
    username.value = ''
    email.value = ''
    password.value = ''
    role.value = 'user'
    error.value = null
    loading.value = false
  }
})

async function submit() {
  error.value = null

  if (!/^\w{3,64}$/.test(username.value)) {
    error.value = t('admin.usernameInvalid')
    return
  }
  if (password.value.length < 8) {
    error.value = t('auth.errors.passwordTooShort')
    return
  }

  loading.value = true
  try {
    await api.post('/admin/users', {
      username: username.value,
      email: email.value || undefined,
      password: password.value,
      role: role.value,
    })
    emit('created')
    emit('close')
  } catch (e: any) {
    const code = e.response?.data?.error
    error.value = code === 'username_taken'
      ? t('admin.usernameTaken')
      : t('toasts.genericError')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <Modal :open="open" :title="$t('admin.newUser')" size="sm" @close="emit('close')">
    <form @submit.prevent="submit" class="space-y-4">
      <label class="block">
        <span class="text-sm text-muted">{{ $t('auth.username') }}</span>
        <input
          v-model="username"
          type="text"
          required
          autocomplete="off"
          class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                 px-3 py-2 focus:outline-none focus:border-accent"
        />
      </label>

      <label class="block">
        <span class="text-sm text-muted">{{ $t('auth.emailOptional') }}</span>
        <input
          v-model="email"
          type="email"
          autocomplete="off"
          class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                 px-3 py-2 focus:outline-none focus:border-accent"
        />
      </label>

      <label class="block">
        <span class="text-sm text-muted">{{ $t('auth.password') }}</span>
        <input
          v-model="password"
          type="password"
          required
          autocomplete="new-password"
          class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                 px-3 py-2 focus:outline-none focus:border-accent"
        />
      </label>

      <label class="block">
        <span class="text-sm text-muted">{{ $t('admin.role') }}</span>
        <select
          v-model="role"
          class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                 px-3 py-2 focus:outline-none focus:border-accent"
        >
          <option value="user">{{ $t('admin.roleUser') }}</option>
          <option value="admin">{{ $t('admin.roleAdmin') }}</option>
        </select>
      </label>

      <p v-if="error" class="text-danger text-sm">{{ error }}</p>
    </form>

    <template #footer>
      <button
        @click="emit('close')"
        class="px-4 py-2 rounded-full text-sm font-medium border border-app
               hover-surface transition-colors"
      >
        Cancel
      </button>
      <button
        @click="submit"
        :disabled="loading"
        class="px-4 py-2 rounded-full text-sm font-medium text-white bg-accent
               hover:opacity-90 disabled:opacity-50 transition-opacity"
      >
        {{ loading ? $t('common.loading') : $t('admin.createUser') }}
      </button>
    </template>
  </Modal>
</template>
