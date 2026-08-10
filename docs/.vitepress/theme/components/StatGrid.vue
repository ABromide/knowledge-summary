<script setup lang="ts">
defineProps<{
  title: string
  items: Array<{ value: string; label: string }>
}>()
</script>

<template>
  <section class="stat-panel" :aria-label="title">
    <div class="stat-heading">🚀 {{ title }}</div>
    <div class="stat-grid">
      <div v-for="item in items" :key="item.label" class="stat-item">
        <strong>{{ item.value }}</strong>
        <span>{{ item.label }}</span>
      </div>
    </div>
  </section>
</template>
