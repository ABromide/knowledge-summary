<script setup lang="ts">
defineProps<{
  title: string
  items: Array<{ value: string; label: string }>
}>()
</script>

<template>
  <section class="stat-panel" :aria-label="title">
    <div class="stat-heading">
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4 19V9m6 10V5m6 14v-7m4 7H2" />
      </svg>
      {{ title }}
    </div>
    <div class="stat-grid">
      <article v-for="item in items" :key="item.label" class="stat-item">
        <strong>{{ item.value }}</strong>
        <span>{{ item.label }}</span>
      </article>
    </div>
  </section>
</template>
