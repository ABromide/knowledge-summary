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
    :title="collapsed ? '展开目录' : '收起目录'"
    @click.stop.prevent="toggleSidebar"
  >
    <svg viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="2" width="14" height="1.5" rx="0.75" />
      <rect x="1" y="7.25" width="14" height="1.5" rx="0.75" />
      <rect x="1" y="12.5" width="14" height="1.5" rx="0.75" />
    </svg>
  </button>
</template>
