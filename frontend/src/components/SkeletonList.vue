<script setup lang="ts">
import Skeleton from './Skeleton.vue'

withDefaults(defineProps<{ count?: number }>(), { count: 8 })
</script>

<template>
  <div class="space-y-1">
    <div v-for="i in count" :key="i" class="flex items-center gap-4 px-3 py-2">
      <Skeleton variant="text" width="1.5rem" height="0.875rem" />
      <div class="flex-1 space-y-1.5">
        <Skeleton variant="text" width="45%" height="0.875rem" />
        <Skeleton variant="text" width="30%" height="0.75rem" />
      </div>
      <Skeleton variant="text" width="3rem" height="0.75rem" />
    </div>
  </div>
</template>
