<script setup lang="ts">
import { onMounted, onUnmounted, ref, watch, nextTick } from 'vue'

const props = withDefaults(defineProps<{
  open: boolean
  title?: string
  size?: 'sm' | 'md' | 'lg'
}>(), {
  size: 'md',
})

const emit = defineEmits<{
  (e: 'close'): void
}>()

const panel = ref<HTMLElement | null>(null)
const previousActive = ref<HTMLElement | null>(null)

const sizeClass = {
  sm: 'max-w-sm',
  md: 'max-w-md',
  lg: 'max-w-2xl',
}[props.size]

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape' && props.open) {
    e.preventDefault()
    emit('close')
  }
  if (e.key === 'Tab' && props.open) {
    trapFocus(e)
  }
}

function trapFocus(e: KeyboardEvent) {
  const el = panel.value
  if (!el) return
  const focusable = el.querySelectorAll<HTMLElement>(
    'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])'
  )
  if (!focusable.length) return

  const first = focusable[0]!
  const last = focusable[focusable.length - 1]!

  if (e.shiftKey && document.activeElement === first) {
    e.preventDefault()
    last.focus()
  } else if (!e.shiftKey && document.activeElement === last) {
    e.preventDefault()
    first.focus()
  }
}

watch(() => props.open, async (isOpen) => {
  if (isOpen) {
    previousActive.value = document.activeElement as HTMLElement
    await nextTick()
    const first = panel.value?.querySelector<HTMLElement>(
      'input, button, textarea, select, [tabindex]:not([tabindex="-1"])'
    )
    first?.focus()
  } else {
    previousActive.value?.focus()
  }
})

onMounted(() => document.addEventListener('keydown', onKey))
onUnmounted(() => document.removeEventListener('keydown', onKey))
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-150 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-100 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="open"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
        role="dialog"
        aria-modal="true"
        :aria-label="title"
      >
        <div
          class="absolute inset-0 bg-black/60 backdrop-blur-sm"
          @click="emit('close')"
        />

        <div
          ref="panel"
          class="relative bg-surface border border-app rounded-2xl shadow-2xl
                 w-full text-app anim-fade-slide"
          :class="sizeClass"
        >
          <header
            v-if="title"
            class="px-6 py-4 border-b border-app flex items-center"
          >
            <h2 class="text-heading">{{ title }}</h2>
            <button
              @click="emit('close')"
              class="ml-auto p-1 rounded-full hover-surface text-muted transition-colors"
              aria-label="Close"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                   class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2"
                   stroke-linecap="round">
                <path d="M18 6 6 18M6 6l12 12" />
              </svg>
            </button>
          </header>

          <div class="px-6 py-5">
            <slot />
          </div>

          <footer v-if="$slots.footer" class="px-6 py-4 border-t border-app flex justify-end gap-3">
            <slot name="footer" />
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
