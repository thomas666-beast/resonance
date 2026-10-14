<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import api from '@/api/client'
import { useToastStore } from '@/stores/toast'

const { t } = useI18n()
const toast = useToastStore()

interface User {
  id: number
  username: string
  email: string | null
  role: 'user' | 'admin'
  is_active: boolean
  created_at: string
  last_login_at: string | null
}

interface Stats {
  counts: {
    users: number
    artists: number
    albums: number
    tracks: number
    playlists: number
  }
  recent_plays: Array<{
    id: number
    played_at: string
    username: string
    track_title: string
    artist_name: string | null
  }>
  scan_paths: Array<{
    id: number
    path: string
    last_scan_at: string | null
  }>
}

const users = ref<User[]>([])
const stats = ref<Stats | null>(null)
const loading = ref(true)

async function load() {
  loading.value = true
  try {
    const [u, s] = await Promise.all([
      api.get('/admin/users'),
      api.get('/admin/stats'),
    ])
    users.value = u.data.users
    stats.value = s.data
  } finally {
    loading.value = false
  }
}

async function createUser() {
  const username = prompt(t('admin.newUserPrompt'))
  if (!username) return
  const password = prompt(t('admin.newPasswordPrompt'))
  if (!password) return
  try {
    await api.post('/admin/users', { username, password })
    toast.success(t('admin.userCreated', { name: username }))
    load()
  } catch (e: any) {
    toast.error(e.response?.data?.error ?? t('toasts.genericError'))
  }
}

async function toggleRole(u: User) {
  const nextRole = u.role === 'admin' ? 'user' : 'admin'
  try {
    await api.patch(`/admin/users/${u.id}`, { role: nextRole })
    toast.success(t('admin.roleChanged', { name: u.username, role: nextRole }))
    load()
  } catch (e: any) {
    toast.error(e.response?.data?.error ?? t('toasts.genericError'))
  }
}

async function toggleActive(u: User) {
  try {
    await api.patch(`/admin/users/${u.id}`, { is_active: !u.is_active })
    toast.success(t('admin.statusChanged', { name: u.username }))
    load()
  } catch (e: any) {
    toast.error(e.response?.data?.error ?? t('toasts.genericError'))
  }
}

async function deleteUser(u: User) {
  if (!confirm(t('admin.confirmDelete', { name: u.username }))) return
  try {
    await api.delete(`/admin/users/${u.id}`)
    toast.success(t('admin.userDeleted', { name: u.username }))
    load()
  } catch (e: any) {
    toast.error(e.response?.data?.error ?? t('toasts.genericError'))
  }
}

function fmtDate(s: string | null): string {
  if (!s) return '—'
  return new Date(s).toLocaleString()
}

onMounted(load)
</script>

<template>
  <div class="p-8 pb-32 max-w-5xl mx-auto text-app">
    <header class="flex items-center justify-between mb-8">
      <h1 class="text-display">{{ $t('admin.title') }}</h1>
      <button
        @click="createUser"
        class="px-4 py-2 bg-accent text-white rounded-full text-sm font-medium
               hover:opacity-90 transition-opacity"
      >
        + {{ $t('admin.newUser') }}
      </button>
    </header>

    <p v-if="loading" class="text-muted">{{ $t('common.loading') }}</p>

    <template v-else>
      <!-- Stats cards -->
      <section v-if="stats" class="grid grid-cols-2 sm:grid-cols-5 gap-4 mb-10">
        <div v-for="(v, k) in stats.counts" :key="k"
             class="bg-surface border border-app rounded-xl p-4">
          <div class="text-3xl font-semibold tabular">{{ v }}</div>
          <div class="text-label mt-1">{{ k }}</div>
        </div>
      </section>

      <!-- Users table -->
      <section class="mb-10">
        <h2 class="text-heading mb-4">{{ $t('admin.users') }}</h2>
        <div class="bg-surface border border-app rounded-xl overflow-hidden">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-app text-left text-muted">
                <th class="px-4 py-3 font-medium">{{ $t('auth.username') }}</th>
                <th class="px-4 py-3 font-medium hidden sm:table-cell">{{ $t('admin.email') }}</th>
                <th class="px-4 py-3 font-medium">{{ $t('admin.role') }}</th>
                <th class="px-4 py-3 font-medium hidden md:table-cell">{{ $t('admin.lastLogin') }}</th>
                <th class="px-4 py-3 font-medium text-right">{{ $t('admin.actions') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="u in users" :key="u.id"
                  class="border-b border-app last:border-0 hover-surface">
                <td class="px-4 py-3">
                  <span :class="!u.is_active && 'opacity-50'">{{ u.username }}</span>
                  <span v-if="!u.is_active"
                        class="ml-2 text-xs text-danger">{{ $t('admin.disabled') }}</span>
                </td>
                <td class="px-4 py-3 text-muted hidden sm:table-cell">{{ u.email ?? '—' }}</td>
                <td class="px-4 py-3">
                  <span class="text-xs px-2 py-0.5 rounded-full"
                        :class="u.role === 'admin'
                          ? 'bg-accent/20 text-accent'
                          : 'bg-surface-2 text-muted'">
                    {{ u.role }}
                  </span>
                </td>
                <td class="px-4 py-3 text-muted text-xs hidden md:table-cell">
                  {{ fmtDate(u.last_login_at) }}
                </td>
                <td class="px-4 py-3 text-right space-x-2">
                  <button @click="toggleRole(u)"
                          class="text-xs text-muted hover:text-accent transition-colors">
                    {{ u.role === 'admin' ? $t('admin.demote') : $t('admin.promote') }}
                  </button>
                  <button @click="toggleActive(u)"
                          class="text-xs text-muted hover:text-accent transition-colors">
                    {{ u.is_active ? $t('admin.disable') : $t('admin.enable') }}
                  </button>
                  <button @click="deleteUser(u)"
                          class="text-xs text-muted hover:text-danger transition-colors">
                    {{ $t('admin.delete') }}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <!-- Recent activity -->
      <section v-if="stats?.recent_plays.length" class="mb-10">
        <h2 class="text-heading mb-4">{{ $t('admin.recentActivity') }}</h2>
        <div class="bg-surface border border-app rounded-xl divide-y divide-[var(--border)]">
          <div v-for="p in stats.recent_plays" :key="p.id"
               class="px-4 py-3 text-sm flex items-center gap-3">
            <span class="text-muted text-xs w-40 shrink-0 tabular">
              {{ fmtDate(p.played_at) }}
            </span>
            <span class="text-muted w-32 shrink-0 truncate">{{ p.username }}</span>
            <span class="flex-1 truncate">
              {{ p.track_title }}
              <span v-if="p.artist_name" class="text-muted"> · {{ p.artist_name }}</span>
            </span>
          </div>
        </div>
      </section>
    </template>
  </div>
</template>
