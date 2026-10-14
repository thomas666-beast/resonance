<script setup lang="ts">
import Skeleton from './Skeleton.vue'

withDefaults(defineProps<{ count?: number }>(), { count: 12 })
</script>

<template>
  <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
    <div v-for="i in count" :key="i" class="space-y-3">
      <Skeleton variant="block" width="100%" height="0" class="!aspect-square" />
      <Skeleton variant="text" width="80%" height="0.875rem" />
      <Skeleton variant="text" width="60%" height="0.75rem" />
    </div>
  </div>
</template>
