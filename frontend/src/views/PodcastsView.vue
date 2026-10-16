<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { usePodcastsStore, type PodcastFeed } from '@/stores/podcasts'
import { useToastStore } from '@/stores/toast'
import PodcastCard from '@/components/PodcastCard.vue'
import SubscribePodcastDialog from '@/components/SubscribePodcastDialog.vue'
import ConfirmModal from '@/components/ConfirmModal.vue'
import EmptyState from '@/components/EmptyState.vue'
import Skeleton from '@/components/Skeleton.vue'

const { t } = useI18n()
const podcasts = usePodcastsStore()
const toast = useToastStore()

const addOpen = ref(false)
const confirmUnsubOpen = ref(false)
const unsubTarget = ref<PodcastFeed | null>(null)
const refreshingAll = ref(false)

onMounted(() => podcasts.load())

function askUnsubscribe(feed: PodcastFeed) {
  unsubTarget.value = feed
  confirmUnsubOpen.value = true
}

async function confirmUnsubscribe() {
  const f = unsubTarget.value
  if (!f) return
  try {
    await podcasts.unsubscribe(f.id)
    toast.success(t('podcasts.unsubscribed'))
  } catch {
    toast.error(t('toasts.genericError'))
  } finally {
    confirmUnsubOpen.value = false
    unsubTarget.value = null
  }
}

async function refreshFeed(feed: PodcastFeed) {
  try {
    await podcasts.refresh(feed.id)
    toast.success(t('podcasts.refreshQueued'))
    setTimeout(() => podcasts.load(), 1200)
  } catch {
    toast.error(t('toasts.genericError'))
  }
}

async function refreshAll() {
  refreshingAll.value = true
  try {
    const { queued } = await podcasts.refreshAll()
    toast.success(t('podcasts.refreshedAll', { n: queued }))
  } catch {
    toast.error(t('toasts.genericError'))
  } finally {
    refreshingAll.value = false
  }
}
</script>

<template>
  <div class="p-4 md:p-8 pb-32 max-w-5xl mx-auto text-app">
    <header class="flex items-center justify-between mb-8 flex-wrap gap-4">
      <h1 class="text-display">{{ $t('podcasts.title') }}</h1>
      <div class="flex items-center gap-2">
        <button
          v-if="podcasts.feeds.length"
          @click="refreshAll"
          :disabled="refreshingAll"
          class="px-4 py-2 rounded-full text-sm font-medium text-app
                 bg-surface-2 border border-app hover:border-hi
                 disabled:opacity-50 transition-colors"
        >
          {{ refreshingAll ? $t('common.loading') : $t('podcasts.refreshAll') }}
        </button>
        <button
          @click="addOpen = true"
          class="px-4 py-2 bg-accent text-white rounded-full text-sm font-medium
                 hover:opacity-90 transition-opacity"
        >
          + {{ $t('podcasts.subscribe') }}
        </button>
      </div>
    </header>

    <div v-if="podcasts.loading && !podcasts.loaded" class="space-y-3">
      <Skeleton v-for="i in 4" :key="i" variant="block" width="100%" height="96px" />
    </div>

    <EmptyState
      v-else-if="!podcasts.feeds.length"
      icon="radio"
      :title="$t('podcasts.emptyTitle')"
      :description="$t('podcasts.emptyDescription')"
    />

    <div v-else class="space-y-3">
      <PodcastCard
        v-for="f in podcasts.feeds"
        :key="f.id"
        :feed="f"
        @unsubscribe="askUnsubscribe(f)"
        @refresh="refreshFeed(f)"
      />
    </div>

    <SubscribePodcastDialog
      :open="addOpen"
      @close="addOpen = false"
      @subscribed="podcasts.load()"
    />

    <ConfirmModal
      :open="confirmUnsubOpen"
      :title="$t('podcasts.unsubscribe')"
      :message="unsubTarget ? $t('podcasts.confirmUnsubscribe', { name: unsubTarget.title || unsubTarget.feed_url }) : ''"
      :confirm-label="$t('podcasts.unsubscribe')"
      danger
      @close="confirmUnsubOpen = false"
      @confirm="confirmUnsubscribe"
    />
  </div>
</template>
