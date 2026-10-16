import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/login',        name: 'login',       component: () => import('@/views/LoginView.vue') },
    { path: '/register',     name: 'register',    component: () => import('@/views/RegisterView.vue') },
    { path: '/',             name: 'home',        component: () => import('@/views/HomeView.vue'),        meta: { requiresAuth: true } },
    { path: '/artists',      name: 'artists',     component: () => import('@/views/ArtistsView.vue'),     meta: { requiresAuth: true } },
    { path: '/artists/:id',  name: 'artist',      component: () => import('@/views/ArtistView.vue'),      meta: { requiresAuth: true } },
    { path: '/albums',       name: 'albums',      component: () => import('@/views/AlbumsView.vue'),      meta: { requiresAuth: true } },
    { path: '/albums/:id',   name: 'album',       component: () => import('@/views/AlbumView.vue'),       meta: { requiresAuth: true } },
    { path: '/favorites',    name: 'favorites',   component: () => import('@/views/FavoritesView.vue'),   meta: { requiresAuth: true } },
    { path: '/playlists',    name: 'playlists',   component: () => import('@/views/PlaylistsView.vue'),   meta: { requiresAuth: true } },
    { path: '/playlists/:id', name: 'playlist',   component: () => import('@/views/PlaylistView.vue'),    meta: { requiresAuth: true } },
    { path: '/now-playing',  name: 'now-playing', component: () => import('@/views/NowPlayingView.vue'),  meta: { requiresAuth: true } },
    { path: '/admin',        name: 'admin',       component: () => import('@/views/AdminView.vue'),       meta: { requiresAuth: true, requiresAdmin: true } },
    { path: '/settings',     name: 'settings',    component: () => import('@/views/SettingsView.vue'),    meta: { requiresAuth: true } },
    { path: '/radio', name: 'radio', component: () => import('@/views/RadioView.vue'), meta: { requiresAuth: true } },
    { path: '/podcasts/:id', name: 'podcast', component: () => import('@/views/PodcastDetailView.vue'), meta: { requiresAuth: true } },
    { path: '/podcasts',     name: 'podcasts', component: () => import('@/views/PodcastsView.vue'),    meta: { requiresAuth: true } },
    { path: '/podcasts/:id', name: 'podcast',  component: () => import('@/views/PodcastDetailView.vue'), meta: { requiresAuth: true } },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()

  if (!auth.initialized) {
    await auth.init()
  }

  if ((to.name === 'login' || to.name === 'register') && auth.accessToken) {
    return { name: 'home' }
  }
  if (to.meta.requiresAuth && !auth.accessToken) {
    return { name: 'login' }
  }
  if (to.meta.requiresAdmin && !auth.isAdmin) {
    return { name: 'home' }
  }
  return true
})

export default router
