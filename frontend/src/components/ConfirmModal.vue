<script setup lang="ts">
import Modal from './Modal.vue'

defineProps<{
  open: boolean
  title: string
  message: string
  confirmLabel: string
  danger?: boolean
}>()

const emit = defineEmits<{
  (e: 'confirm'): void
  (e: 'close'): void
}>()
</script>

<template>
  <Modal :open="open" :title="title" size="sm" @close="emit('close')">
    <p class="text-muted leading-relaxed">{{ message }}</p>

    <template #footer>
      <button
        @click="emit('close')"
        class="px-4 py-2 rounded-full text-sm font-medium border border-app
               hover-surface transition-colors"
      >
        Cancel
      </button>
      <button
        @click="emit('confirm')"
        class="px-4 py-2 rounded-full text-sm font-medium text-white
               transition-opacity hover:opacity-90"
        :class="danger ? 'bg-danger' : 'bg-accent'"
      >
        {{ confirmLabel }}
      </button>
    </template>
  </Modal>
</template>
