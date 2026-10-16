<script setup lang="ts">
import { computed, ref, watch, nextTick } from 'vue'
import { usePlayerStore } from '@/stores/player'

interface LyricLine {
  start_ms?: number
  value: string
}

const props = defineProps<{
  content: string | null
  synced: boolean
  lines: LyricLine[] | null
}>()

const player = usePlayerStore()
const container = ref<HTMLElement | null>(null)

// Current line index for synced lyrics
const currentIndex = computed(() => {
  if (!props.synced || !props.lines?.length) return -1
  const posMs = player.position * 1000
  let idx = -1
  for (let i = 0; i < props.lines.length; i++) {
    const start = props.lines[i].start_ms ?? 0
    if (posMs >= start) idx = i
    else break
  }
  return idx
})

// Scroll only the lyrics container, never the page.
watch(currentIndex, async (idx) => {
  if (idx < 0 || !container.value) return
  await nextTick()
  const el = container.value.querySelector<HTMLElement>(`[data-line="${idx}"]`)
  if (!el) return

  const c = container.value
  const elTop = el.offsetTop
  const elHeight = el.offsetHeight
  const cHeight = c.clientHeight

  // Target: line vertically centered in the container
  const target = elTop - (cHeight / 2) + (elHeight / 2)

  c.scrollTo({ top: Math.max(0, target), behavior: 'smooth' })
})

const plainLines = computed(() => {
  if (!props.content) return []
  return props.content.split(/\r?\n/).filter((l) => l.length > 0)
})
</script>

<template>
  <div
    ref="container"
    class="h-full overflow-y-auto scroll-slim px-6 py-8 text-center
           text-muted leading-relaxed"
  >
    <div v-if="!content && (!lines || !lines.length)" class="pt-16 text-sm">
      {{ $t('lyrics.none') }}
    </div>

    <template v-else-if="synced && lines?.length">
      <div
        v-for="(line, i) in lines"
        :key="i"
        :data-line="i"
        class="py-1.5 transition-all duration-300"
        :class="i === currentIndex
          ? 'text-app font-medium scale-[1.03]'
          : i < currentIndex
            ? 'opacity-40'
            : 'opacity-70'"
      >
        {{ line.value }}
      </div>
    </template>

    <template v-else>
      <div v-for="(line, i) in plainLines" :key="i" class="py-0.5">
        {{ line }}
      </div>
    </template>
  </div>
</template>
