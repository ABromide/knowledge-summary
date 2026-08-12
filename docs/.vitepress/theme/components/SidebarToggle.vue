<script setup lang="ts">
import { onMounted, ref } from 'vue'

const collapsed = ref(false)

function applyState() {
  document.documentElement.classList.toggle('sidebar-collapsed', collapsed.value)
  localStorage.setItem('knowledge-sidebar-collapsed', String(collapsed.value))
}

function toggleSidebar() {
  collapsed.value = !collapsed.value
  applyState()
}

onMounted(() => {
  collapsed.value = localStorage.getItem('knowledge-sidebar-collapsed') === 'true'
  applyState()
})
</script>

<template>
  <button
    class="knowledge-sidebar-toggle"
    type="button"
    :aria-label="collapsed ? '展开目录' : '收起目录'"
    :aria-expanded="!collapsed"
    :title="collapsed ? '展开目录' : '收起目录'"
    @click.stop.prevent="toggleSidebar"
  >
    <svg viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1.5" y="2" width="13" height="12" rx="2" />
      <path d="M6 2v12" />
      <path v-if="collapsed" d="m9 5.5 2.5 2.5L9 10.5" />
      <path v-else d="m11.5 5.5-2.5 2.5 2.5 2.5" />
    </svg>
  </button>
</template>
