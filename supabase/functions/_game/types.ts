// Kelimeki — paylaşılan oyun tipleri
//
// src/game/types.ts'in KOPYASI — bu Edge Function kendi bağımsız paketi
// olarak deploy edildiğinden (bkz. play-ai-turn/index.ts başındaki not),
// tarayıcı koduyla otomatik senkronize olmaz. src/game/types.ts değişirse
// (Player/Tile/AIMove alanları) burası da elle güncellenmeli.

/** Bir taşı/hamleyi yapan oyuncunun indeksi (0..3). */
export type Owner = number;

/** Bonus kare türü: yalnızca tahtanın tam ortasındaki tek X3 (üç kat kelime) hücresi kullanır. */
export type BonusType = 'tw';

export interface Tile {
  /** Raftaki/torbadaki ham harf ('?' joker olabilir). */
  letter: string;
  pts: number;
  /** Joker mi? */
  wild?: boolean;
  /** Joker oynandığında seçilen harf. */
  wildLetter?: string;
  /** Tahtaya konduğunda sahibi (oyuncu indeksi). */
  owner?: Owner;
}

/** "r,c" biçiminde hücre anahtarı. */
export type CellKey = string;

export interface Placement {
  r: number;
  c: number;
  tile: Tile;
}

/** Bir oyuncu (yerel oyunla aynı şekil — bkz. src/game/types.ts). */
export interface Player {
  name: string;
  corners: number[];
  colorIndex: number;
  isAI: boolean;
  surrendered: boolean;
  rack: Tile[];
  score: number;
  bestMoveScore: number;
  longestWord: string;
  moveCount: number;
  moveScoreSum: number;
}

/** YZ'nin bulduğu hamle. */
export interface AIMove {
  word: string;
  score: number;
  placements: Placement[];
}

export interface ValidationResult {
  valid: boolean;
  reason?: string;
  words?: string[];
}
