// Harfik — paylaşılan oyun tipleri

export type Owner = 'player' | 'ai';

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
  /** Tahtaya konduğunda sahibi. */
  owner?: Owner;
}

/** "r,c" biçiminde hücre anahtarı. */
export type CellKey = string;

export interface Placement {
  r: number;
  c: number;
  tile: Tile;
}

export interface GameState {
  /** SIZE x SIZE tahta; boş hücreler null. */
  board: (Tile | null)[][];
  /** Çekiliş torbası. */
  bag: Tile[];
  /** Bonus kareler: "r,c" -> BonusType. */
  bonuses: Record<CellKey, BonusType>;
  /** Özel hücre durumları: "r,c" -> CellState. */
  cellState: Record<CellKey, CellState>;
  /** Bu turda oyuncunun geçici yerleştirdiği taşlar. */
  placed: Record<CellKey, Tile>;
  playerRack: Tile[];
  aiRack: Tile[];
  playerScore: number;
  aiScore: number;
  playerTurn: boolean;
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
  /** Aktif tur etiketi. */
  turnLabel: string;
  /** Evrim bildirimi görünür mü? */
  evolveToast: boolean;
}

export interface ValidationResult {
  valid: boolean;
  reason?: string;
  words?: string[];
}

export interface AIMove {
  word: string;
  score: number;
  placements: Placement[];
}
