// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// GitHub Pages project site: served under https://isamercan.github.io/ThemeKit/
// `base` MUST match the repo name so assets resolve. The Swift DocC API reference
// is deployed alongside this site under /ThemeKit/api/ by the Pages workflow.
export default defineConfig({
  site: 'https://isamercan.github.io',
  base: '/ThemeKit',
  trailingSlash: 'always',
  integrations: [
    starlight({
      title: 'ThemeKit',
      description:
        'A themeable SwiftUI component library — 80+ accessible components, design tokens, light/dark, and RTL.',
      tagline: 'Themeable SwiftUI components, built to ship.',
      logo: {
        light: './src/assets/banner.png',
        dark: './src/assets/banner-dark.png',
        replacesTitle: true,
      },
      favicon: '/favicon.svg',
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/isamercan/ThemeKit',
        },
      ],
      editLink: {
        baseUrl: 'https://github.com/isamercan/ThemeKit/edit/main/website/',
      },
      customCss: ['./src/styles/theme.css'],
      sidebar: [
        {
          label: 'Start Here',
          items: [
            { label: 'Introduction', link: '/' },
            { label: 'Getting Started', link: '/guides/getting-started/' },
            { label: 'Installation', link: '/guides/installation/' },
          ],
        },
        {
          label: 'Guides',
          items: [
            { label: 'Theming', link: '/guides/theming/' },
            { label: 'Accessibility', link: '/guides/accessibility/' },
            { label: 'Form Validation', link: '/guides/form-validation/' },
            { label: 'RTL Support', link: '/guides/rtl/' },
            { label: 'Motion', link: '/guides/motion/' },
          ],
        },
        {
          label: 'Components',
          items: [{ label: 'Gallery', link: '/components/' }],
        },
        {
          label: 'Design',
          items: [
            { label: 'Design Principles', link: '/design/principles/' },
            { label: 'Feedback Patterns', link: '/design/feedback-patterns/' },
          ],
        },
        {
          label: 'API Reference',
          items: [
            {
              label: 'DocC Reference ↗',
              link: '/ThemeKit/api/documentation/themekit/',
              attrs: { target: '_blank' },
              badge: { text: 'Swift', variant: 'note' },
            },
          ],
        },
      ],
    }),
  ],
});
