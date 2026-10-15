<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRadioStore, type RadioStation } from '@/stores/radio'
import { useToastStore } from '@/stores/toast'
import RadioCard from '@/components/RadioCard.vue'
import RadioEditDialog from '@/components/RadioEditDialog.vue'
import ConfirmModal from '@/components/ConfirmModal.vue'
import EmptyState from '@/components/EmptyState.vue'
import Skeleton from '@/components/Skeleton.vue'

const { t } = useI18n()
const radio = useRadioStore()
const toast = useToastStore()

const dialogOpen = ref(false)
const editTarget = ref<RadioStation | null>(null)

const confirmDeleteOpen = ref(false)
const deleteTarget = ref<RadioStation | null>(null)

onMounted(() => radio.load())

function openAdd() {
  editTarget.value = null
  dialogOpen.value = true
}

function openEdit(station: RadioStation) {
  editTarget.value = station
  dialogOpen.value = true
}

function askDelete(station: RadioStation) {
  deleteTarget.value = station
  confirmDeleteOpen.value = true
}

async function confirmDelete() {
  const s = deleteTarget.value
  if (!s) return
  try {
    await radio.remove(s.id)
    toast.success(t('radio.deleted'))
  } catch {
    toast.error(t('toasts.genericError'))
  } finally {
    confirmDeleteOpen.value = false
    deleteTarget.value = null
  }
}
</script>

<template>
  <div class="p-4 md:p-8 pb-32 max-w-6xl mx-auto text-app">
    <header class="flex items-center justify-between mb-8">
      <h1 class="text-display">{{ $t('radio.title') }}</h1>
      <button
        v-if="radio.isAdmin"
        @click="openAdd"
        class="px-4 py-2 bg-accent text-white rounded-full text-sm font-medium
               hover:opacity-90 transition-opacity"
      >
        + {{ $t('radio.add') }}
      </button>
    </header>

    <!-- Loading -->
    <div v-if="radio.loading && !radio.loaded" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <Skeleton v-for="i in 6" :key="i" variant="block" width="100%" height="120px" />
    </div>

    <!-- Empty -->
    <EmptyState
      v-else-if="!radio.stations.length"
      icon="radio"
      :title="$t('radio.emptyTitle')"
      :description="radio.isAdmin ? $t('radio.emptyAdminHint') : $t('radio.emptyDescription')"
    />

    <!-- List -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <RadioCard
        v-for="s in radio.stations"
        :key="s.id"
        :station="s"
        @edit="openEdit(s)"
        @delete="askDelete(s)"
      />
    </div>

    <RadioEditDialog
      :open="dialogOpen"
      :station="editTarget"
      @close="dialogOpen = false"
      @saved="() => {}"
    />

    <ConfirmModal
      :open="confirmDeleteOpen"
      :title="$t('radio.delete')"
      :message="deleteTarget ? $t('radio.confirmDelete', { name: deleteTarget.name }) : ''"
      :confirm-label="$t('radio.delete')"
      danger
      @close="confirmDeleteOpen = false"
      @confirm="confirmDelete"
    />
  </div>
</template>
