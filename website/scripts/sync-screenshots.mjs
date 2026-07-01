// Copies component screenshots from the repo's top-level Screenshots/ folder into
// the site's public/ dir and emits a manifest the gallery page renders from.
//
// Runs automatically before `dev` and `build` (see package.json pre-hooks) so the
// copied images and manifest are never committed — they're regenerated from the
// canonical Screenshots/ source on every build.
import { readdirSync, mkdirSync, copyFileSync, writeFileSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..'); // website/
const srcDir = join(root, '..', 'Screenshots');
const outImgDir = join(root, 'public', 'screenshots');
const outShowcaseDir = join(root, 'public', 'showcase');
const dataDir = join(root, 'src', 'data');

// Curated "striking" hero/showcase shots used across the site (landing, theming).
// app-* are full-screen demo captures; Theme* are multi-theme showcases.
const showcaseNames = [
  'app-themes',
  'app-components',
  'app-hotel-detail',
  'app-theme-generator',
  'app-datatable',
  'app-colors',
  'app-example',
  'app-button',
  'ThemeShowcase',
  'ThemePresets',
  'ThemeInjection',
];

const files = readdirSync(srcDir);

// A "component" screenshot is `<Name>.png`, excluding dark variants, the hero
// Banner, and the app-* demo captures.
const isComponentLight = (f) =>
  f.endsWith('.png') &&
  !f.endsWith('-dark.png') &&
  !f.startsWith('app-') &&
  f !== 'Banner.png';

const has = (name) => files.includes(name);

const components = files
  .filter(isComponentLight)
  .map((f) => f.replace(/\.png$/, ''))
  .sort((a, b) => a.localeCompare(b))
  .map((name) => ({
    name,
    hasDark: has(`${name}-dark.png`),
    hasGif: has(`${name}.gif`),
  }));

// Reset and copy only the assets the gallery references.
rmSync(outImgDir, { recursive: true, force: true });
mkdirSync(outImgDir, { recursive: true });
mkdirSync(dataDir, { recursive: true });

let copied = 0;
for (const c of components) {
  copyFileSync(join(srcDir, `${c.name}.png`), join(outImgDir, `${c.name}.png`));
  copied++;
  if (c.hasDark) {
    copyFileSync(join(srcDir, `${c.name}-dark.png`), join(outImgDir, `${c.name}-dark.png`));
    copied++;
  }
  if (c.hasGif) {
    copyFileSync(join(srcDir, `${c.name}.gif`), join(outImgDir, `${c.name}.gif`));
    copied++;
  }
}

// Copy the curated showcase shots (only those that exist).
rmSync(outShowcaseDir, { recursive: true, force: true });
mkdirSync(outShowcaseDir, { recursive: true });
let showcased = 0;
for (const name of showcaseNames) {
  const file = `${name}.png`;
  if (has(file)) {
    copyFileSync(join(srcDir, file), join(outShowcaseDir, file));
    showcased++;
  }
}

writeFileSync(join(dataDir, 'components.json'), JSON.stringify(components, null, 2) + '\n');

console.log(
  `[sync-screenshots] ${components.length} components (${copied} files) + ${showcased} showcase images copied → public/`
);
