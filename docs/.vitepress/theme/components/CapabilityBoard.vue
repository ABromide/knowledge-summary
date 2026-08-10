<script setup lang="ts">
defineProps<{
  items: Array<{
    icon: string
    title: string
    description: string
    level: 'good' | 'human' | 'strict'
    label: string
  }>
}>()
</script>

<template>
  <section class="capability-board" aria-label="AI 编程适用范围">
    <article v-for="item in items" :key="item.title" :class="`level-${item.level}`">
      <div class="capability-head">
        <span class="capability-icon">{{ item.icon }}</span>
        <span class="capability-label">{{ item.label }}</span>
      </div>
      <strong>{{ item.title }}</strong>
      <p>{{ item.description }}</p>
    </article>
  </section>
</template>
