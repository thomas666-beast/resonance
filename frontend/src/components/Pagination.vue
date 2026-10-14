<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  page: number
  perPage: number
  total: number
}>()

const emit = defineEmits<{
  (e: 'update:page', value: number): void
}>()

const totalPages = computed(() => Math.max(1, Math.ceil(props.total / props.perPage)))
const from = computed(() => (props.page - 1) * props.perPage + 1)
const to   = computed(() => Math.min(props.page * props.perPage, props.total))

// Up to 5 numbered links centered on the current page
const pages = computed(() => {
  const last = totalPages.value
  const cur = props.page
  const span = 2
  const start = Math.max(1, Math.min(cur - span, last - 2 * span))
  const end = Math.min(last, start + 2 * span)
  const out: number[] = []
  for (let i = start; i <= end; i++) out.push(i)
  return out
})

function go(p: number) {
  if (p < 1 || p > totalPages.value || p === props.page) return
  emit('update:page', p)
}
</script>

<template>
  <div v-if="total > 0" class="flex items-center justify-between mt-6 text-sm">
    <p class="text-muted">
      {{ from }}–{{ to }} of {{ total }}
    </p>

    <div class="flex items-center gap-1">
      <button
        @click="go(page - 1)"
        :disabled="page <= 1"
        class="px-3 py-1.5 rounded-lg border border-app hover-surface
               disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
      >
        ←
      </button>

      <button
        v-for="p in pages"
        :key="p"
        @click="go(p)"
        class="px-3 py-1.5 rounded-lg border transition-colors tabular"
        :class="p === page
          ? 'bg-accent text-white border-accent'
          : 'border-app hover-surface'"
      >
        {{ p }}
      </button>

      <button
        @click="go(page + 1)"
        :disabled="page >= totalPages"
        class="px-3 py-1.5 rounded-lg border border-app hover-surface
               disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
      >
        →
      </button>
    </div>
  </div>
</template>
