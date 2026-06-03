---
name: website-design-recreation
description: Recreates a reference screenshot as a production Next.js app with themes, i18n, and SEO. Use when the user provides a design image, screenshot, or mockup and wants it implemented as a Next.js page or component. Triggers on "recreate this design", "implement this screenshot", "build this UI", "match this mockup", or any reference image provided alongside a build request.
---

# Website Design Recreation

## Workflow

### 1. Analyse the reference image

- Identify layout regions: header, hero, sections, footer
- Note typography scale, spacing rhythm, color palette
- List interactive elements (buttons, forms, nav)
- Identify repeating components

### 2. Plan the file structure

Follow `.claude/rules` and `AGENTS.md`. Typical output:

```
src/
  app/
    [locale]/
      page.tsx          # main page
      layout.tsx        # locale layout
  components/
    <Section>.tsx       # one file per distinct section
  lib/
    themes.ts           # theme definitions
  messages/
    en.json             # English strings
    [locale].json       # additional locales
  styles/
    themes.css          # CSS custom properties per theme
```

### 3. Theme system

Define themes as CSS custom property sets in `src/styles/themes.css`:

```css
[data-theme="light"] {
  --color-bg: #ffffff;
  --color-fg: #111827;
  --color-primary: #2563eb;
  --color-primary-hover: #1d4ed8;
}

[data-theme="dark"] {
  --color-bg: #0f172a;
  --color-fg: #f8fafc;
  --color-primary: #3b82f6;
  --color-primary-hover: #60a5fa;
}
```

Apply themes via `data-theme` on `<html>`. Use Tailwind's `bg-[var(--color-bg)]` syntax to consume them.

### 4. Internationalisation

Use `next-intl`. Install: `npm install next-intl`.

```
src/messages/en.json        # { "hero": { "title": "...", "cta": "..." } }
src/messages/ar.json        # same keys, translated values
src/i18n/routing.ts         # locales: ['en', 'ar'], defaultLocale: 'en'
```

Wrap the app in `NextIntlClientProvider`. Use `useTranslations('hero')` in components. All user-visible strings go in message files — no hardcoded copy in components.

### 5. SEO

Use Next.js Metadata API in every `page.tsx`:

```ts
export const metadata: Metadata = {
  title: t('meta.title'),
  description: t('meta.description'),
  openGraph: { title: ..., description: ..., images: [...] },
  alternates: { canonical: '/', languages: { en: '/en', ar: '/ar' } },
}
```

Add `robots.ts` and `sitemap.ts` at `src/app/`.

### 6. Screenshot and compare (iterate until match)

```bash
# Start dev server
npm run dev &
sleep 5

# Screenshot full page
npx puppeteer screenshot http://localhost:3000 --full-page -o screenshot.png
```

- Place `screenshot.png` next to the reference image
- Compare side-by-side: layout, spacing, typography, colors, alignment
- List every visible difference
- Edit the components to fix each one
- Re-screenshot and compare — **minimum 2 rounds**
- Stop only when no visible differences remain or the user says stop

### 7. Cleanup

```bash
rm screenshot.png
pkill -f "next dev"
git add -A
git commit -m "feat: implement <page-name> design"
```

## Technical defaults

- Tailwind CSS for all styling — no inline styles
- `next/image` for all images; use `https://placehold.co/WxH` when source images aren't available
- Mobile-first responsive (`sm:` → `md:` → `lg:`)
- No hardcoded colors — always via CSS custom properties
- No hardcoded strings — always via translation keys
- TypeScript strict mode
