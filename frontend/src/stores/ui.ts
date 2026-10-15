import { defineStore } from 'pinia'
import { ref } from 'vue'

// Tracks which ephemeral popup/menu is currently open across the app.
// Only one at a time. Components read and write this to coordinate.
export const useUIStore = defineStore('ui', () => {
  const openTrackMenuId = ref<number | null>(null)

  function openTrackMenu(trackId: number) {
    openTrackMenuId.value = trackId
  }

  function closeTrackMenu() {
    openTrackMenuId.value = null
  }

  function toggleTrackMenu(trackId: number) {
    openTrackMenuId.value = openTrackMenuId.value === trackId ? null : trackId
  }

  function isTrackMenuOpen(trackId: number): boolean {
    return openTrackMenuId.value === trackId
  }

  return {
    openTrackMenuId,
    openTrackMenu,
    closeTrackMenu,
    toggleTrackMenu,
    isTrackMenuOpen,
  }
})
