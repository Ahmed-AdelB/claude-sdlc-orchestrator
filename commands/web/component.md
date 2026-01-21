---
name: web:component
description: Generate production-ready web components for React, Vue, and Svelte with TypeScript, styles, stories, and tests.
version: 1.0.0
tools:
  - Read
  - Write
  - Bash
---

# Web Component Generator Skill

This skill generates production-ready web components for React, Vue, and Svelte frameworks with TypeScript support, styles, stories, and tests.

## Tri-Agent Integration
- Claude: Define architecture, component responsibilities, and shared contracts.
- Codex: Implement the component, stories, and tests in the target framework.
- Gemini: Review for correctness, edge cases, and accessibility coverage.

## Usage
`@component [framework] [name] [description/props]`

**Parameters:**
- `framework`: `react`, `vue`, or `svelte`
- `name`: Component name (PascalCase)
- `description/props`: Description of functionality and list of props

**Example:**
`@component react PrimaryButton "Primary CTA button with loading state"`

## Process
1.  **Parse Requirements**: Analyze the input to determine the component's purpose, required props, and state.
2.  **Generate Component**: Create the component file using the appropriate framework template.
3.  **Add Validation**: Implement strict prop typing (Interfaces/Zod) and validation.
4.  **Create Styles**: Generate CSS/styled-components/Tailwind classes as appropriate for the project.
5.  **Storybook**: Create a Storybook file with default and edge-case stories.
6.  **Testing**: Generate unit tests (Jest/Vitest/Testing Library) covering rendering and interactions.

---

## Error Handling
- Validate props and required inputs at the boundary (TypeScript + runtime guards where needed).
- Provide explicit error UI for async or data-driven components.
- Use framework-appropriate error boundaries or error slots when rendering can fail.
- Ensure tests cover invalid props and fallback states.

## Templates and Examples

### Example
`@component react SearchBar "Accessible search input with clear button and icons"`

### 1. React (Next.js/TS)

**Component (`[Name].tsx`):**
```tsx
import React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

// Styles
const componentVariants = cva(
  'base-styles-here',
  {
    variants: {
      variant: {
        default: 'default-styles',
        secondary: 'secondary-styles',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

// Props
export interface [Name]Props
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof componentVariants> {
  // Add custom props here
  label?: string;
}

// Component
export const [Name] = React.forwardRef<HTMLDivElement, [Name]Props>(
  ({ className, variant, size, label, ...props }, ref) => {
    return (
      <div
        ref={ref}
        className={cn(componentVariants({ variant, size, className }))}
        {...props}
      >
        {label}
        {props.children}
      </div>
    );
  }
);
[Name].displayName = '[Name]';
```

**Story (`[Name].stories.tsx`):**
```tsx
import type { Meta, StoryObj } from '@storybook/react';
import { [Name] } from './[Name]';

const meta: Meta<typeof [Name]> = {
  title: 'Components/[Name]',
  component: [Name],
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: { type: 'select' },
      options: ['default', 'secondary'],
    },
  },
};

export default meta;
type Story = StoryObj<typeof [Name]>;

export const Default: Story = {
  args: {
    label: '[Name] Content',
    variant: 'default',
  },
};
```

**Test (`[Name].test.tsx`):**
```tsx
import { render, screen } from '@testing-library/react';
import { [Name] } from './[Name]';

describe('[Name]', () => {
  it('renders correctly', () => {
    render(<[Name] label="Test Label" />);
    expect(screen.getByText('Test Label')).toBeInTheDocument();
  });
});
```

---

### 2. Vue (Nuxt/TS)

**Component (`[Name].vue`):**
```vue
<script setup lang="ts">
import { computed } from 'vue';

interface Props {
  label?: string;
  variant?: 'default' | 'secondary';
  disabled?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  label: '',
  variant: 'default',
  disabled: false,
});

const emit = defineEmits<{
  (e: 'click', event: MouseEvent): void;
}>();

const classes = computed(() => {
  return [
    'base-class',
    `variant-${props.variant}`,
    { 'is-disabled': props.disabled }
  ];
});
</script>

<template>
  <div :class="classes" @click="!disabled && emit('click', $event)">
    {{ label }}
    <slot />
  </div>
</template>

<style scoped>
.base-class {
  /* styles */
}
</style>
```

**Story (`[Name].stories.ts`):**
```ts
import type { Meta, StoryObj } from '@storybook/vue3';
import [Name] from './[Name].vue';

const meta: Meta<typeof [Name]> = {
  title: 'Components/[Name]',
  component: [Name],
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof [Name]>;

export const Default: Story = {
  args: {
    label: 'Vue Component',
    variant: 'default',
  },
};
```

**Test (`[Name].spec.ts`):**
```ts
import { mount } from '@vue/test-utils';
import { describe, it, expect } from 'vitest';
import [Name] from './[Name].vue';

describe('[Name]', () => {
  it('renders props.label when passed', () => {
    const label = 'new message';
    const wrapper = mount([Name], {
      props: { label }
    });
    expect(wrapper.text()).toMatch(label);
  });
});
```

---

### 3. Svelte (SvelteKit/TS)

**Component (`[Name].svelte`):**
```svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let label: string = '';
  export let variant: 'default' | 'secondary' = 'default';
  export let disabled: boolean = false;

  const dispatch = createEventDispatcher();
  
  $: classes = [
    'base-class',
    `variant-${variant}`,
    disabled ? 'opacity-50 cursor-not-allowed' : ''
  ].join(' ');
</script>

<!-- svelte-ignore a11y-click-events-have-key-events -->
<div 
  class={classes} 
  on:click={(e) => !disabled && dispatch('click', e)}
  role="button"
  tabindex={disabled ? -1 : 0}
>
  {label}
  <slot />
</div>

<style>
  .base-class {
    /* styles */
  }
</style>
```

**Story (`[Name].stories.ts`):**
```ts
import type { Meta, StoryObj } from '@storybook/svelte';
import [Name] from './[Name].svelte';

const meta: Meta<typeof [Name]> = {
  title: 'Components/[Name]',
  component: [Name],
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof [Name]>;

export const Default: Story = {
  args: {
    label: 'Svelte Component',
    variant: 'default',
  },
};
```

**Test (`[Name].test.ts`):**
```ts
import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import [Name] from './[Name].svelte';

describe('[Name]', () => {
  it('renders successfully', () => {
    const { getByText } = render([Name], { props: { label: 'Test Label' } });
    expect(getByText('Test Label')).toBeInTheDocument();
  });
});
```
