// `landing-plugin.js` düz JS (bkz. o dosyanın başındaki gerekçe: projede
// `@types/node` yok). `vite.config.ts` tip denetiminden geçtiğinden yalnızca
// eklentinin dış yüzeyi burada bildiriliyor.
import type { PluginOption } from 'vite';
export declare function kelimekiLanding(): PluginOption;
