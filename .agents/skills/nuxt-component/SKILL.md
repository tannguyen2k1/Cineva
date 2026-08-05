---
name: nuxt-component
description: >-
  Template for creating reusable Vue components in the Nuxt frontend of this monorepo.
  Covers the standard structure: index.vue + CSS Modules (.module.scss),
  defineProps, Element Plus integration, and naming conventions.
  Use when creating a new component, extracting a reusable UI piece,
  or scaffolding a component directory.
  Triggers on "new component", "create component", "extract component", "add component".
---

# Creating Components

## File structure

```
frontend/components/{ComponentName}/
├── index.vue                    # Component file
└── {ComponentName}.module.scss  # Styles (CSS Modules)
```

Nuxt auto-imports from `frontend/components/` — no manual registration needed.
Use PascalCase for directory name: `StatCard`, `DataTable`, `UserProfile`.

## Component template

```vue
<template>
  <div :class="styles.root">
    <slot />
  </div>
</template>

<script setup lang="ts">
import styles from './{ComponentName}.module.scss'

withDefaults(defineProps<{
  title: string
  size?: 'small' | 'medium' | 'large'
  loading?: boolean
}>(), {
  size: 'medium',
  loading: false
})

const emit = defineEmits<{
  (e: 'update', value: string): void
}>()
</script>
```

## SCSS module template

```scss
.root {
  // base styles
}

// Variants via props → dynamic :class binding
.sizeSmall { /* ... */ }
.sizeMedium { /* ... */ }
.sizeLarge { /* ... */ }
```

Rules:
- **camelCase** for all class names (`.pageContainer`, `.cardHeader`)
- Use `:global(.el-xxx)` to override Element Plus internals
- No `<style scoped>` or `<style>` blocks in `.vue` files

## Using the component

```vue
<ComponentName title="Hello" size="small" @update="handleUpdate" />
```

No import needed — Nuxt auto-imports by directory name.

## Conventions

| Pattern | Example |
|---------|---------|
| Props typing | `defineProps<{ ... }>()` with `withDefaults` |
| Events | `defineEmits<{ ... }>()` |
| Expose | `defineExpose({ ... })` only when parent needs access |
| Slots | Use `<slot>` and named slots `<slot name="header">` |
| Icons | Import from `@element-plus/icons-vue`, pass as `Component` prop |
| i18n | Use `useI18n()` inside component if it has user-facing text |

## Checklist

- [ ] Directory: `components/{PascalName}/index.vue`
- [ ] Styles: `components/{PascalName}/{PascalName}.module.scss`
- [ ] Props typed with `defineProps<{}>()` + `withDefaults`
- [ ] No `<style>` block in the `.vue` file
- [ ] All class bindings use `:class="styles.xxx"`
- [ ] User-facing text uses `t()` from `useI18n()`
