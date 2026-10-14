<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  user: { id: number; username: string; role: 'user' | 'admin'; is_active: boolean }
  self: boolean
}>()

const emit = defineEmits<{
  (e: 'promote'): void
  (e: 'demote'): void
  (e: 'disable'): void
  (e: 'enable'): void
  (e: 'delete'): void
}>()

const { t } = useI18n()
const open = ref(false)
const root = ref<HTMLElement | null>(null)

function toggle(e: MouseEvent) {
  e.stopPropagation()
  open.value = !open.value
}

function pick(fn: () => void) {
  open.value = false
  fn()
}

function onDocClick(e: MouseEvent) {
  if (root.value && !root.value.contains(e.target as Node)) open.value = false
}

onMounted(() => document.addEventListener('click', onDocClick))
onUnmounted(() => document.removeEventListener('click', onDocClick))
</script>

<template>
  <div ref="root" class="relative inline-block">
    <button
      @click="toggle"
      :disabled="self"
      class="p-1.5 rounded-full hover-surface transition-colors text-muted
             disabled:opacity-30 disabled:cursor-not-allowed"
      :aria-label="$t('admin.actions')"
    >
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
           class="w-4 h-4 fill-current">
        <circle cx="12" cy="5" r="1.5" />
        <circle cx="12" cy="12" r="1.5" />
        <circle cx="12" cy="19" r="1.5" />
      </svg>
    </button>

    <Transition
      enter-active-class="transition duration-100 ease-out"
      enter-from-class="opacity-0 scale-95"
      enter-to-class="opacity-100 scale-100"
      leave-active-class="transition duration-75 ease-in"
      leave-from-class="opacity-100 scale-100"
      leave-to-class="opacity-0 scale-95"
    >
      <div
        v-if="open"
        class="absolute right-0 bottom-full mb-1 w-48 bg-surface border border-app rounded-lg
               shadow-2xl z-50 py-1 text-sm origin-bottom-right"
      >
        <button
          v-if="user.role === 'user'"
          @click.stop="pick(() => emit('promote'))"
          class="block w-full text-left px-3 py-2 hover-surface transition-colors"
        >
          {{ $t('admin.promote') }}
        </button>
        <button
          v-else
          @click.stop="pick(() => emit('demote'))"
          class="block w-full text-left px-3 py-2 hover-surface transition-colors"
        >
          {{ $t('admin.demote') }}
        </button>

        <button
          v-if="user.is_active"
          @click.stop="pick(() => emit('disable'))"
          class="block w-full text-left px-3 py-2 hover-surface transition-colors"
        >
          {{ $t('admin.disable') }}
        </button>
        <button
          v-else
          @click.stop="pick(() => emit('enable'))"
          class="block w-full text-left px-3 py-2 hover-surface transition-colors"
        >
          {{ $t('admin.enable') }}
        </button>

        <div class="border-t border-app my-1" />

        <button
          @click.stop="pick(() => emit('delete'))"
          class="block w-full text-left px-3 py-2 hover-surface text-danger transition-colors"
        >
          {{ $t('admin.delete') }}
        </button>
      </div>
    </Transition>
  </div>
</template>
