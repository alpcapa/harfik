// `legal-plugin.js` düz JS (`landing-plugin.js` ile aynı gerekçe: projede
// `@types/node` yok). `vite.config.ts` tip denetiminden geçtiğinden yalnızca
// eklentinin dış yüzeyi burada bildiriliyor.
import type { PluginOption } from 'vite';
export declare function kelimekiLegalPages(): PluginOption;
