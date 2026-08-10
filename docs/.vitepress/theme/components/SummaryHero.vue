<script setup lang="ts">
defineProps<{
  goals: string[]
  duration: string
  output: string
}>()
</script>

<template>
  <section class="summary-hero" aria-label="本章导读">
    <div class="summary-goals">
      <span class="eyebrow">🎯 本章学习目标</span>
      <div class="goal-list">
        <span v-for="goal in goals" :key="goal">{{ goal }}</span>
      </div>
      <slot />
    </div>
    <div class="summary-meta">
      <article>
        <span class="meta-icon">⏱️</span>
        <div><strong>预计耗时</strong><p>{{ duration }}</p></div>
      </article>
      <article>
        <span class="meta-icon">📦</span>
        <div><strong>预期产出</strong><p>{{ output }}</p></div>
      </article>
    </div>
  </section>
</template>
