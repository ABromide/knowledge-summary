<script setup lang="ts">
defineProps<{
  active: number
  items: Array<{ title: string; description: string }>
}>()
</script>

<template>
  <ol class="learning-steps" aria-label="学习路径">
    <li
      v-for="(item, index) in items"
      :key="item.title"
      :class="{ active: index === active, completed: index < active }"
    >
      <span class="step-index">{{ index + 1 }}</span>
      <span class="step-copy">
        <strong>{{ item.title }}</strong>
        <small>{{ item.description }}</small>
      </span>
    </li>
  </ol>
</template>
