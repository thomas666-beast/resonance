<script setup lang="ts">
import { onMounted, ref, watch, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import api from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import CreateUserModal from '@/components/CreateUserModal.vue'
import ConfirmModal from '@/components/ConfirmModal.vue'
import Pagination from '@/components/Pagination.vue'
import UserRowMenu from '@/components/UserRowMenu.vue'
import Skeleton from '@/components/Skeleton.vue'

const { t } = useI18n()
const auth = useAuthStore()
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
  counts: { users: number; artists: number; albums: number; tracks: number; playlists: number }
  recent_plays: Array<{
    id: number; played_at: string; username: string
    track_title: string; artist_name: string | null
  }>
  scan_paths: Array<{ id: number; path: string; last_scan_at: string | null }>
}

const users   = ref<User[]>([])
const total   = ref(0)
const page    = ref(1)
const perPage = 25
const query   = ref('')
const sort    = ref('created_at')
const dir     = ref<'asc' | 'desc'>('desc')
const loading = ref(true)

const stats = ref<Stats | null>(null)

const showCreateModal = ref(false)
const deleteTarget    = ref<User | null>(null)

let searchTimer: ReturnType<typeof setTimeout> | null = null

const totalPages = computed(() => Math.max(1, Math.ceil(total.value / perPage)))

async function loadUsers() {
  loading.value = true
  try {
    const params: any = {
      page: page.value,
      per_page: perPage,
      sort: sort.value,
      dir: dir.value,
    }
    if (query.value) params.q = query.value
    const { data } = await api.get('/admin/users', { params })
    users.value = data.users
    total.value = data.total
  } finally {
    loading.value = false
  }
}

async function loadStats() {
  const { data } = await api.get('/admin/stats')
  stats.value = data
}

function onSearch(e: Event) {
  query.value = (e.target as HTMLInputElement).value
  page.value = 1
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(loadUsers, 250)
}

function changeSort(field: string) {
  if (sort.value === field) {
    dir.value = dir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sort.value = field
    dir.value = 'asc'
  }
  loadUsers()
}

function sortIndicator(field: string): string {
  if (sort.value !== field) return ''
  return dir.value === 'asc' ? '↑' : '↓'
}

watch(page, loadUsers)

async function updateUser(u: User, patch: Record<string, any>, message: string) {
  try {
    await api.patch(`/admin/users/${u.id}`, patch)
    toast.success(message)
    await loadUsers()
  } catch (e: any) {
    toast.error(e.response?.data?.error ?? t('toasts.genericError'))
  }
}

function promote(u: User) {
  updateUser(u, { role: 'admin' }, t('admin.roleChanged', { name: u.username, role: 'admin' }))
}
function demote(u: User) {
  updateUser(u, { role: 'user' }, t('admin.roleChanged', { name: u.username, role: 'user' }))
}
function disable(u: User) {
  updateUser(u, { is_active: false }, t('admin.statusChanged', { name: u.username }))
}
function enable(u: User) {
  updateUser(u, { is_active: true }, t('admin.statusChanged', { name: u.username }))
}

async function confirmDelete() {
  const u = deleteTarget.value
  if (!u) return
  try {
    await api.delete(`/admin/users/${u.id}`)
    toast.success(t('admin.userDeleted', { name: u.username }))
    deleteTarget.value = null
    await loadUsers()
  } catch (e: any) {
    toast.error(e.response?.data?.error ?? t('toasts.genericError'))
  }
}

async function onCreated() {
  toast.success(t('admin.userCreated'))
  page.value = 1
  await loadUsers()
  await loadStats()
}

function fmtDate(s: string | null): string {
  if (!s) return '—'
  return new Date(s).toLocaleString()
}

onMounted(() => {
  loadUsers()
  loadStats()
})
</script>

<template>
  <div class="p-8 pb-32 max-w-6xl mx-auto text-app">
    <header class="flex items-center justify-between mb-10">
      <h1 class="text-display">{{ $t('admin.title') }}</h1>
      <button
        @click="showCreateModal = true"
        class="px-4 py-2 bg-accent text-white rounded-full text-sm font-medium
               hover:opacity-90 transition-opacity"
      >
        + {{ $t('admin.newUser') }}
      </button>
    </header>

    <!-- Stats -->
    <section v-if="stats" class="grid grid-cols-2 sm:grid-cols-5 gap-4 mb-10">
      <div v-for="(v, k) in stats.counts" :key="k"
           class="bg-surface border border-app rounded-xl p-4 anim-fade-slide">
        <div class="text-3xl font-semibold tabular">{{ v }}</div>
        <div class="text-label mt-1">{{ k }}</div>
      </div>
    </section>

    <!-- Users -->
    <section class="mb-10">
      <div class="flex items-center justify-between mb-4 gap-4">
        <h2 class="text-heading">{{ $t('admin.users') }}</h2>
        <div class="relative max-w-xs flex-1">
          <input
            type="search"
            :placeholder="$t('admin.searchPlaceholder')"
            @input="onSearch"
            class="w-full border border-app rounded-full px-4 py-1.5 text-sm
                   bg-surface text-app placeholder:text-dim
                   focus:outline-none focus:border-accent"
          />
        </div>
      </div>

    <div class="bg-surface border border-app rounded-xl">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-app text-left text-muted">
              <th
                @click="changeSort('username')"
                class="px-4 py-3 font-medium cursor-pointer hover:text-app transition-colors select-none"
              >
                {{ $t('auth.username') }} {{ sortIndicator('username') }}
              </th>
              <th class="px-4 py-3 font-medium hidden sm:table-cell">{{ $t('admin.email') }}</th>
              <th
                @click="changeSort('role')"
                class="px-4 py-3 font-medium cursor-pointer hover:text-app transition-colors select-none"
              >
                {{ $t('admin.role') }} {{ sortIndicator('role') }}
              </th>
              <th
                @click="changeSort('last_login_at')"
                class="px-4 py-3 font-medium hidden md:table-cell cursor-pointer hover:text-app transition-colors select-none"
              >
                {{ $t('admin.lastLogin') }} {{ sortIndicator('last_login_at') }}
              </th>
              <th class="px-4 py-3 font-medium text-right w-16"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="loading">
              <td colspan="5" class="px-4 py-8">
                <div class="space-y-3">
                  <Skeleton v-for="i in 5" :key="i" variant="text" height="1.25rem" />
                </div>
              </td>
            </tr>
            <tr v-else-if="!users.length">
              <td colspan="5" class="px-4 py-12 text-center text-muted">
                {{ query ? $t('admin.noResults') : $t('admin.noUsers') }}
              </td>
            </tr>
            <tr
              v-for="u in users"
              v-else
              :key="u.id"
              class="relative border-b border-app last:border-0 hover-surface transition-colors"
            >
              <td class="px-4 py-3">
                <span :class="!u.is_active && 'opacity-50'">{{ u.username }}</span>
                <span v-if="u.id === auth.user?.id" class="ml-2 text-xs text-accent">
                  ({{ $t('admin.you') }})
                </span>
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
              <td class="px-4 py-3 text-muted text-xs hidden md:table-cell tabular">
                {{ fmtDate(u.last_login_at) }}
              </td>
              <td class="px-4 py-3 text-right">
                <UserRowMenu
                  :user="u"
                  :self="u.id === auth.user?.id"
                  @promote="promote(u)"
                  @demote="demote(u)"
                  @disable="disable(u)"
                  @enable="enable(u)"
                  @delete="deleteTarget = u"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <Pagination
        :page="page"
        :per-page="perPage"
        :total="total"
        @update:page="(p) => page = p"
      />
    </section>

    <!-- Recent activity -->
    <section v-if="stats?.recent_plays.length">
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

    <!-- Modals -->
    <CreateUserModal
      :open="showCreateModal"
      @close="showCreateModal = false"
      @created="onCreated"
    />

    <ConfirmModal
      :open="!!deleteTarget"
      :title="$t('admin.delete')"
      :message="deleteTarget
        ? $t('admin.confirmDelete', { name: deleteTarget.username })
        : ''"
      :confirm-label="$t('admin.delete')"
      danger
      @close="deleteTarget = null"
      @confirm="confirmDelete"
    />
  </div>
</template>
