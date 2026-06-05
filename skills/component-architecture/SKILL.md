---
name: component-architecture
description: Defines the three-tier component architecture — Primitive, Pattern, Section — including placement rules, translation boundaries, and "use client" guidance. Use when creating, moving, or reviewing components, deciding which layer a component belongs to, or applying the cva/cn variant pattern.
---

Three tiers. Full rationale: `docs/adr/0001-three-tier-component-architecture.md`.

## Layers

**Primitive** (`src/components/ui`): Domain-agnostic presentational UI building block (Button, Chip, FieldRow). Receives everything as plain props — no translations, no context, no data fetching. _Avoid_: Atom, widget, dumb component.

**Pattern** (`src/components/patterns`): Reusable composite from Primitives that captures a recurring interaction shape (SelectorSheet, Accordion, SummaryChips). Still domain-agnostic. _Avoid_: Molecule, organism, shared component.

**Section** (colocated with feature): Feature-level component that owns domain meaning, translations, and state. Composes Patterns and Primitives. _Avoid_: Block, module, organism, container.

## Rules

- **Translation boundary**: Only Sections call `useTranslations`. Primitives and Patterns receive resolved strings as props.
- **Server by default**: Add `"use client"` only for state, effects, event handlers (beyond `Link`), browser APIs, or React context. `useTranslations` alone does NOT require client.
- **Variants**: Use `cva` + `cn()` helper (`clsx` + `tailwind-merge`).
- **Tests colocated**: Primitives/Patterns: provider-free render + interaction. Sections: provider-wrapped integration.
