import { onMounted, onUnmounted } from 'vue'
import { usePlayerStore } from '@/stores/player'
import { useFavoritesStore } from '@/stores/favorites'

export function useKeyboard() {
  const player = usePlayerStore()
  const favorites = useFavoritesStore()

  function isTypingTarget(el: EventTarget | null): boolean {
    if (!(el instanceof HTMLElement)) return false
    const tag = el.tagName.toLowerCase()
    return tag === 'input' || tag === 'textarea' || tag === 'select' || el.isContentEditable
  }

  function onKey(e: KeyboardEvent) {
    if (isTypingTarget(e.target)) return

    const k = e.key

    // Space — play/pause
    if (k === ' ') {
      if (!player.current) return
      e.preventDefault()
      player.toggle()
      return
    }

    // Left/Right — seek 5s
    if (k === 'ArrowLeft') {
      if (!player.current) return
      e.preventDefault()
      player.seek(Math.max(0, player.position - 5))
      return
    }
    if (k === 'ArrowRight') {
      if (!player.current) return
      e.preventDefault()
      player.seek(Math.min(player.duration, player.position + 5))
      return
    }

    // Up/Down — volume ±5%
    if (k === 'ArrowUp') {
      e.preventDefault()
      player.setVolume(Math.min(1, player.volume + 0.05))
      return
    }
    if (k === 'ArrowDown') {
      e.preventDefault()
      player.setVolume(Math.max(0, player.volume - 0.05))
      return
    }

    // f — favorite current track
    if (k === 'f' || k === 'F') {
      const cur = player.current
      if (!cur) return
      e.preventDefault()
      favorites.toggle(cur.id)
      return
    }

    // / — focus search
    if (k === '/') {
      const input = document.querySelector<HTMLInputElement>('input[type="search"]')
      if (input) {
        e.preventDefault()
        input.focus()
        input.select()
      }
      return
    }

    // Esc — close open menus (search dropdown handles its own Esc,
    // this is a catch-all for others)
    if (k === 'Escape') {
      // Blur focused inputs as a general "get out" gesture
      if (document.activeElement instanceof HTMLElement) {
        document.activeElement.blur()
      }
      return
    }
  }

  onMounted(() => document.addEventListener('keydown', onKey))
  onUnmounted(() => document.removeEventListener('keydown', onKey))
}
