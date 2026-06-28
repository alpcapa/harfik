// Harfik — paylaşılan oyun tipleri

/** Bir taşı/hamleyi yapan oyuncunun indeksi (0..3). */
export type Owner = number;

/** Bonus kare türleri: 2K/3K kelime, 2H/3H harf çarpanı. */
export type BonusType = 'dw' | 'tw' | 'dl' | 'tl';

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

/** Yerel (aynı cihaz) oyuncu. */
export interface Player {
  name: string;
  /** Atanmış köşe bölgesi indeksi (0..3). */
  corner: number;
  /** Renk paleti indeksi (PLAYER_COLORS). */
  colorIndex: number;
  /** Bu oyuncuyu yapay zekâ mı oynuyor? */
  isAI: boolean;
  rack: Tile[];
  score: number;
  /** Bu oyuncunun toplam kaç kez pas geçtiği. */
  passes: number;
}

/** YZ'nin bulduğu hamle. */
export interface AIMove {
  word: string;
  score: number;
  placements: Placement[];
}

export interface GameState {
  /** 'setup' = oyuncu kurulum ekranı, 'play' = oyun sürüyor. */
  phase: 'setup' | 'play';
  /** SIZE x SIZE tahta; boş hücreler null. */
  board: (Tile | null)[][];
  /** Çekiliş torbası. */
  bag: Tile[];
  /** Bonus kareler: "r,c" -> BonusType. */
  bonuses: Record<CellKey, BonusType>;
  /** Bu turda aktif oyuncunun geçici yerleştirdiği taşlar. */
  placed: Record<CellKey, Tile>;
  /** Tüm oyuncular. */
  players: Player[];
  /** Sırası gelen oyuncunun indeksi. */
  current: number;
  /** Raftaki seçili taşın indeksi. */
  selectedTile: number | null;
  /** Taş değiştirme modunda mı? (Aktif oyuncu taşlarını değiştirmek istiyor.) */
  swapMode: boolean;
  /** Taş değiştirme modunda seçilen raf taşı indeksleri. */
  swapSelection: number[];
  turnCount: number;
  isGameOver: boolean;
  /** Durum çubuğu mesajı. */
  message: string;
  messageType: '' | 'ok' | 'err' | 'warn';
  /**
   * Son kabul edilen hamlede oluşan kelimeler (hücre → kelime + oynayan).
   * Bu hücrelere tıklayınca kelimenin anlamı gösterilir.
   */
  lastWords: Record<CellKey, { word: string; by: Owner }>;
}

export interface ValidationResult {
  valid: boolean;
  reason?: string;
  words?: string[];
}
