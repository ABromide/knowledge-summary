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
      <div class="summary-header">
        <span class="summary-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="8" />
            <circle cx="12" cy="12" r="3" />
            <path d="M18 6 21 3m-3 3h3V3" />
          </svg>
        </span>
        <span>
          <span class="eyebrow">本章学习目标</span>
          <span class="eyebrow-caption">阅读前先建立清晰预期</span>
        </span>
      </div>
      <div class="goal-list">
        <span v-for="goal in goals" :key="goal">{{ goal }}</span>
      </div>
      <slot />
    </div>
    <div class="summary-meta">
      <article>
        <span class="meta-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24">
            <circle cx="12" cy="13" r="8" />
            <path d="M12 9v4l2.5 1.5M9 3h6" />
          </svg>
        </span>
        <div><strong>预计耗时</strong><p>{{ duration }}</p></div>
      </article>
      <article>
        <span class="meta-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24">
            <path d="m4 7 8-4 8 4-8 4-8-4Z" />
            <path d="M4 7v10l8 4 8-4V7M12 11v10" />
          </svg>
        </span>
        <div><strong>预期产出</strong><p>{{ output }}</p></div>
      </article>
    </div>
  </section>
</template>
