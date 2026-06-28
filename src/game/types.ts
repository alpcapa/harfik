// Harfik — paylaşılan oyun tipleri

/** Bir taşı/hamleyi yapan oyuncunun indeksi (0..3). */
export type Owner = number;

/** Bonus kare türleri: 2K/3K kelime, 2H/3H harf çarpanı. */
export type BonusType = 'dw' | 'tw' | 'dl' | 'tl';

/** Özel hücre durumu: çatlamış (yakında boşluk) veya boşluk (oynanamaz). */
export type CellState = 'crack' | 'void';

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
  rack: Tile[];
  score: number;
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
  /** Özel hücre durumları: "r,c" -> CellState. */
  cellState: Record<CellKey, CellState>;
  /** Bu turda aktif oyuncunun geçici yerleştirdiği taşlar. */
  placed: Record<CellKey, Tile>;
  /** Tüm oyuncular. */
  players: Player[];
  /** Sırası gelen oyuncunun indeksi. */
  current: number;
  /** Raftaki seçili taşın indeksi. */
  selectedTile: number | null;
  turnCount: number;
  /** Tahta evrimine kalan hamle sayısı. */
  turnsUntilEvolve: number;
  consecutivePasses: number;
  isGameOver: boolean;
  /** Durum çubuğu mesajı. */
  message: string;
  messageType: '' | 'ok' | 'err' | 'warn';
  /** Evrim bildirimi görünür mü? */
  evolveToast: boolean;
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
