<script setup lang="ts">
import { useToastStore } from '@/stores/toast'

const toast = useToastStore()

const styles = {
  success: 'bg-stone-900 text-white',
  error:   'bg-red-600 text-white',
  info:    'bg-stone-700 text-white',
}
</script>

<template>
  <div class="fixed bottom-24 right-6 z-50 flex flex-col-reverse gap-2 pointer-events-none">
    <TransitionGroup
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0 translate-y-2"
      enter-to-class="opacity-100 translate-y-0"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0 translate-x-2"
    >
      <div
        v-for="t in toast.items"
        :key="t.id"
        :class="[
          styles[t.type],
          'pointer-events-auto rounded-lg shadow-lg px-4 py-2.5 text-sm max-w-sm flex items-center gap-3',
        ]"
      >
        <span class="flex-1">{{ t.message }}</span>
        <button
          @click="toast.dismiss(t.id)"
          class="opacity-60 hover:opacity-100 transition-opacity"
          aria-label="Dismiss"
        >✕</button>
      </div>
    </TransitionGroup>
  </div>
</template>
