import { defineConfig } from 'astro/config';

// Site statique : Vercel détecte Astro et sert le dossier dist/.
export default defineConfig({
  site: 'https://boomparty.vercel.app',
  trailingSlash: 'ignore',
});
