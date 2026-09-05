# Kelimeki — Port Inventory

> **DONMUŞ ANLIK GÖRÜNTÜ — 5 Ağustos 2026 (Flutter portunun başlangıcı).**
> Bu dosya port planlaması için bir kez çıkarılmış bir envanterdir; yaşayan
> doküman DEĞİL ve kasıtlı olarak güncellenmiyor (LOC sayıları ve dosya
> listesi o günkü ağaca ait). 19 Ağustos 2026 itibarıyla `src/` altında
> burada GEÇMEYEN 19 dosya var — karşılama katmanı (`Landing.tsx`,
> `LandingLogo.tsx`, `OzellikIkonlari.tsx`, `demoBoard.ts`, `render.tsx`,
> `boot.tsx`), k-lig ödül/rütbe katmanı (`RankSeal.tsx`,
> `RankInfoModal.tsx`, `RewardBanner.tsx`, `LeagueRewardsHost.tsx`,
> `leagueRank.ts`, `useRankScores.tsx`), `cloudSaveMirror.ts`,
> `offlineNotice.ts`, `platform.ts`, `shareLink.ts`,
> `FriendModerationModal.tsx`, `RelationIcons.tsx`, `database.types.ts`.
> **Güncel yapı için `README.md` → "Proje Yapısı" ve `CLAUDE.md` →
> "Klasör Yapısı"na bak; port kararlarının yaşayan kaydı
> `mobile/CLAUDE.md`.** Buradaki hiçbir satırı bugünün gerçeği sayma;
> tarihsel bir kayıt olarak duruyor.

Accurate as of repo state on disk (commit checked out in this session). No recommendations — inventory only.

## 1. Modules

### `src/game/` — engine core

| File | LOC | Purpose |
|---|---|---|
| `constants.ts` | 151 | Board size, corner geometry, bonus-zone geometry, player colors, joker-finish bonus table |
| `gameReducer.ts` | 922 | `useReducer` state machine: all turn actions (PLACE_TILE, PLAY, PASS, AI_PLAY, SURRENDER, SYNC_ONLINE_STATE…) |
| `types.ts` | 197 | `GameState`, `Player`, `Tile`, `HistoryEntry`, `MoveStatus`, `ValidationResult` |

### `src/utils/` — mostly pure helpers

| File | LOC | Purpose |
|---|---|---|
| `ai.ts` | 304 | Opponent move search (best-scoring legal word from rack) |
| `bag.ts` | 65 | Tile bag construction, draw, "remaining tiles" breakdown |
| `board.ts` | 157 | Board primitives: empty board, cell keys, formed-word extraction |
| `boardSnapshot.ts` | 96 | Serialize/deserialize a finished board to/from compact JSON |
| `csvExport.ts` | 33 | Browser CSV-Blob download helper (admin tables) |
| `feedbackSync.ts` | 114 | Offline/guest queue for feedback-form submissions |
| `friendInvite.ts` | 27 | One-shot localStorage queue for a pending friend-invite token |
| `gameRecord.ts` | 69 | Builds a `NewGame` DB record from a finished `GameState` |
| `gameStorage.ts` | 149 | Autosave/restore in-progress local game to `localStorage`, 7-day abandonment |
| `gameSync.ts` | 145 | Offline/guest queue for finished-game records |
| `leaguePoints.ts` | 61 | League-point formula + rank computation from a game-history snapshot |
| `onboarding.ts` | 67 | "Seen quickstart" one-time-popup flag in `localStorage` |
| `outline.ts` | 180 | Cell-set → SVG outline path generator (territory borders) |
| `pendingLiveGames.ts` | 36 | Counts pending online-game invites/turns for badges |
| `profileFields.ts` | 66 | Shared gender options + ISO⇄TR date string converters |
| `random.ts` | 10 | Fisher–Yates shuffle |
| `ranking.ts` | 37 | `rankPlayers`: surrendered-last competition ranking |
| `shareBoardImage.ts` | 12 | DOM node → PNG blob via `html-to-image` |
| `turkish.ts` | 29 | `trLower`/`trUpper`/`trCompare` |
| `validator.ts` | 406 | Word/placement validation, territory computation, scoring |
| `visitTracking.ts` | 111 | Anonymous guest-visit id/ping + UTM first-touch capture |

### `src/data/` — dictionary & tile data

| File | LOC | Purpose |
|---|---|---|
| `meanings.ts` | 48 | Lazy `fetch()` loader for a 6.3 MB meanings JSON asset |
| `tiles.ts` | 48 | Turkish letter distribution/points (`TILE_DATA`, 100 tiles) |
| `wordSetLoader.ts` | 43 | Dynamic `import()` wrapper that code-splits the word list into its own chunk |
| `words.ts` | 4004 | The dictionary itself: `WORD_LIST` array + derived `WORD_SET` |

### `src/lib/` — Supabase access layer

| File | LOC | Purpose |
|---|---|---|
| `api.ts` | 2224 | Every Supabase RPC/table call the app makes (~90 exported functions) |
| `database.types.ts` | 692 | Hand-written TS types mirroring the Postgres schema (types only, no logic) |
| `pwa.ts` | 85 | Service-worker update-prompt logic (`registerType: 'prompt'`) |
| `supabase.ts` | 36 | Client construction; `null` if env vars absent (offline mode) |

### `src/hooks/`

| File | LOC | Purpose |
|---|---|---|
| `useAppIconBadge.ts` | 134 | PWA icon Badge API (pending-count on the home-screen icon) |
| `useAuth.tsx` | 137 | Auth context: session, profile fetch, sign-in/out wiring |
| `useModalA11y.ts` | 82 | Shared modal focus-trap/Escape/stacking behavior |
| `useNicknameAvailability.ts` | 42 | Debounced nickname-uniqueness check against an RPC |
| `useOnlineStatus.ts` | 19 | Wraps `navigator.onLine` + `online`/`offline` events |

### `src/components/` — React UI (51 files, all browser-coupled)

| File | LOC | Purpose |
|---|---|---|
| `AccountSettingsModal.tsx` | 359 | Profile edit form (name, nickname, gender, birth date, consents) |
| `ActionSheet.tsx` | 74 | iOS-style bottom action sheet |
| `AddToHomeScreen.tsx` | 100 | "Install PWA" banner |
| `AdminChatTranscriptModal.tsx` | 49 | Admin view of a finished game's chat |
| `AdminDashboard.tsx` | 1516 | Admin panel: members, games, growth charts, feedback, chat reports |
| `AuthModal.tsx` | 386 | Sign-in / sign-up form |
| `Avatar.tsx` | 91 | Profile photo or initials fallback |
| `Board.tsx` | 578 | 13×13 board renderer: territory tint/outline, bonus zones, drag targets |
| `ChatModal.tsx` | 168 | Live in-game chat window |
| `ChatSettingsModal.tsx` | 409 | Per-participant mute/report settings |
| `ChatThread.tsx` | 121 | Shared read-only/live message-bubble list |
| `CountBadge.tsx` | 32 | Red numeric pending-count badge |
| `ErrorBoundary.tsx` | 63 | Root React error boundary + "clear saved game" escape hatch |
| `FeedbackModal.tsx` | 207 | "Send feedback" form |
| `FriendInvitePage.tsx` | 126 | Public `/davet/:token` invite-link landing page |
| `FriendSuggestModal.tsx` | 124 | Post-accept "add these people as friends?" prompt |
| `FriendsModal.tsx` | 636 | Friends list / search / pending requests |
| `GameBoardPreview.tsx` | 25 | Read-only compact board render (history cards) |
| `GameChatHistoryModal.tsx` | 91 | Finished-game chat transcript viewer |
| `GameHeader.tsx` | 186 | Score boxes + account menu header |
| `GameHistoryModal.tsx` | 781 | "All my games" list: likes, sharing, snapshots, chat badges |
| `GameOver.tsx` | 94 | End-of-game results screen |
| `GrowthChart.tsx` | 376 | Generic admin time-series line chart |
| `HelpModal.tsx` | 387 | Rules / how-to-play |
| `KLigMark.tsx` | 35 | Auto-generated static SVG "k-lig" wordmark |
| `LandscapeHint.tsx` | 69 | Dismissible "rotate to portrait" banner |
| `Leaderboard.tsx` | 209 | Paginated league leaderboard |
| `LiveGameCreateForm.tsx` | 373 | Online-game setup: pick friends / AI seat, send invites |
| `LiveGamesTab.tsx` | 770 | Online-game lists: invites, active, waiting, recent |
| `LogoMark.tsx` | 48 | Auto-generated static SVG "kelimeki" wordmark |
| `MeaningModal.tsx` | 61 | Dictionary-definition popup for a played word |
| `MemberMessageModal.tsx` | 92 | Admin → member direct message form |
| `Modal.tsx` | 63 | Shared modal shell |
| `MoveHistoryModal.tsx` | 174 | Full move/score history list |
| `OnlineGameScreen.tsx` | 1307 | Live multiplayer game screen: sync, drag-drop, chat, timers |
| `PlayerAvatarRow.tsx` | 82 | Overlapping participant-avatar row |
| `PlayerBadge.tsx` | 23 | Colored seat-number square |
| `PlayerScoreCard.tsx` | 382 | Any player's read-only stat card |
| `PrivacyModal.tsx` | 189 | Privacy policy text |
| `Rack.tsx` | 96 | Player's letter rack |
| `RecentGamesSection.tsx` | 189 | "Recently played" compact list (Setup screen) |
| `RemainingTilesModal.tsx` | 44 | Tiles-remaining breakdown |
| `ResetPasswordModal.tsx` | 104 | "Set new password" screen (from reset link) |
| `ScoreCard.tsx` | 134 | Own stat card + tab switcher |
| `ScoreStatsSection.tsx` | 163 | Shared stat-grid used by ScoreCard/PlayerScoreCard |
| `Setup.tsx` | 792 | Game-setup screen: local vs. online tabs, player config |
| `SharedGamePage.tsx` | 106 | Public `/game/:id` shared-game page |
| `TermsModal.tsx` | 112 | Terms of use text |
| `Tile.tsx` | 88 | Single letter-tile render |
| `UserMenu.tsx` | 316 | Account dropdown menu |
| `WildcardModal.tsx` | 41 | Blank-tile letter picker |

### Root

| File | LOC | Purpose |
|---|---|---|
| `src/App.tsx` | 1491 | Top-level app: setup/play routing, drag-drop, dispatch wiring |
| `src/main.tsx` | 63 | React root mount, SPA path routing for `/game/:id` and `/davet/:token`, dictionary preload |

Non-`src` code not inventoried in detail: `scripts/` (13 build-time Node scripts, ~2200 LOC — dictionary build, logo/icon/OG-image generation), `supabase/functions/` (13 Deno Edge Functions), `supabase/migrations/` (144 SQL files), `tests/smoke.spec.ts` (59-line Playwright critical-path check).

## 2. Pure vs. browser-coupled

**Pure (no DOM/`window`/`navigator`/storage/network at runtime — verified by source inspection, not just grep):**
`game/constants.ts`, `game/gameReducer.ts`, `game/types.ts`, `utils/ai.ts`, `utils/bag.ts`, `utils/board.ts`, `utils/boardSnapshot.ts`, `utils/leaguePoints.ts`, `utils/outline.ts`, `utils/pendingLiveGames.ts`, `utils/profileFields.ts`, `utils/random.ts`, `utils/ranking.ts`, `utils/turkish.ts`, `utils/validator.ts`, `data/tiles.ts`, `data/words.ts`, `lib/database.types.ts` (types only). This is the entire scoring/validation/turn-state engine plus the raw dictionary — none of it touches `document`, `window`, `localStorage`, `fetch`, or React. `gameReducer.ts`/`types.ts` mention `localStorage` only in comments, not code.

**Browser-coupled, by API used:**
| File | API(s) |
|---|---|
| `utils/gameStorage.ts`, `gameSync.ts`, `feedbackSync.ts`, `onboarding.ts`, `friendInvite.ts` | `localStorage`, and `navigator.onLine` (gameSync/feedbackSync) |
| `utils/gameRecord.ts` | `crypto.randomUUID()`, `localStorage` (via serializeBoardSnapshot's callers) |
| `utils/visitTracking.ts` | `localStorage`, `crypto.randomUUID()`, `window` (matchMedia via caller), `navigator` |
| `utils/csvExport.ts` | `document.createElement('a')` + `Blob`/`URL.createObjectURL` |
| `utils/shareBoardImage.ts` | `HTMLElement`, `html-to-image` (canvas/DOM serialization) |
| `data/meanings.ts` | `fetch()`, Vite `?url` static-asset import |
| `data/wordSetLoader.ts` | Dynamic `import()` (bundler code-splitting; network-backed chunk fetch) |
| `lib/api.ts`, `lib/supabase.ts`, `lib/pwa.ts` | Supabase client (network), `import.meta.env`, service-worker registration |
| `hooks/*` | All five are React hooks wrapping browser state (auth session, `navigator.onLine`, Badge API, `document`/focus events) |
| `components/*` (all 51) | React/JSX, DOM refs, drag events, `Modal`/focus-trap, `localStorage`/`sessionStorage` in several (`LandscapeHint.tsx`, `AddToHomeScreen.tsx`) |
| `App.tsx`, `main.tsx` | Full DOM/React root, `window.location`, pointer/drag event wiring |

## 3. The dictionary

- **File**: `src/data/words.ts` — a single generated TypeScript module (banner comment: "ÜRETİLMİŞTİR — elle düzenlemeyin", regenerated via `scripts/build-dictionary.mjs` from a TDK-derived JSON source). Exports:
  ```ts
  export const WORD_LIST: readonly string[] = [ "ab", "aba", "abacı", ... ];
  export const WORD_SET: ReadonlySet<string> = new Set(WORD_LIST);
  ```
  63,890 entries, all lowercase, no diacritics normalized away (native Turkish chars kept: ç ğ ı i ö ş ü), word length 2–25 chars, no multi-word entries, no whitespace.
- **Size on disk**: 879,915 bytes (~860 KB) source; 4,004 lines. A companion `src/data/meanings.json` (definitions, not used for validation) is 6,506,213 bytes (~6.3 MB).
- **How it's loaded**: `words.ts` is never statically imported by game logic. `src/data/wordSetLoader.ts` dynamically `import()`s it into its own Vite chunk; `main.tsx` fire-and-forgets `preloadWordSet()` before React renders. `getWordSet()` throws if called before the chunk resolves; `isWordSetReady()` is the guard callers (`App.tsx`, `Setup.tsx`) check first. `words-*.js` chunk is included in the PWA's precache list for offline play.
- **Lookups**: `getWordSet().has(trLower(word))` — a `Set.has()`, O(1). All validation/AI code funnels through `getWordSet()`; nothing scans `WORD_LIST` linearly except `ai.ts`'s one-time `getWordPool()` filter/uppercase pass (cached after first call).
- **Turkish character handling**: dictionary is stored pre-lowercased with `trLower` semantics baked in at build time; runtime lookups re-apply `trLower()` (not native `.toLowerCase()`) before every `.has()` call, specifically to avoid the İ/I ↔ i/ı mismatch native JS case folding produces. See `src/utils/turkish.ts` in full below.

## 4. Scoring, validation, and turn-state — actual code

**Turkish case folding** (`src/utils/turkish.ts`, used by every lookup/comparison in the engine):
```ts
export function trLower(s: string): string {
  return s.replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
}
export function trUpper(s: string): string {
  return s.replace(/i/g, 'İ').replace(/ı/g, 'I').toUpperCase();
}
export function trCompare(a: string, b: string): number {
  return a.localeCompare(b, 'tr');
}
```

**Word scoring** (`src/utils/validator.ts`):
```ts
function wordRawPoints(coords: [number, number][], board: Board, placed: Placed): number {
  let sum = 0;
  for (const [r, c] of coords) {
    const k = key(r, c);
    const pts = placed[k]?.pts ?? board[r][c]?.pts ?? 0;
    sum += pts;
  }
  return sum;
}

function wordBonusFlags(coords, placed, bonuses) {
  let hasTw = false, touchesZone = false;
  for (const [r, c] of coords) {
    const k = key(r, c);
    const newTile = placed[k];
    if (newTile && bonuses[k] === 'tw') hasTw = true;
    if (newTile && inBonusZone(r, c)) touchesZone = true;
  }
  return { x2: !hasTw && touchesZone, x3: hasTw };
}

function wordPoints(coords, board, placed, bonuses): number {
  const { x2, x3 } = wordBonusFlags(coords, placed, bonuses);
  const wordMult = x3 ? 3 : x2 ? 2 : 1;
  return wordRawPoints(coords, board, placed) * wordMult;
}

export function calcScore(board: Board, placed: Placed, bonuses): number {
  let total = 0;
  for (const { coords } of getFormedWords(board, placed)) {
    total += wordPoints(coords, board, placed, bonuses);
  }
  if (Object.keys(placed).length >= RACK_SIZE) total += BINGO_BONUS;
  return total;
}
```

**Territory-invasion split** (`src/utils/validator.ts` — attacker keeps `basePts*(n+1)/(6n)`-complement, remainder split across `n` touched foreign territories):
```ts
export function computeInvasionSplit(coords, ownerIndex, players, basePts, board) {
  const territories = computeAllTerritories(board, players);
  const touchedIdx = new Set<number>();
  const addIfForeign = (r, c) => {
    const k = key(r, c);
    for (let i = 0; i < territories.length; i++) {
      if (i !== ownerIndex && territories[i].has(k)) touchedIdx.add(i);
    }
  };
  for (const [r, c] of coords) {
    addIfForeign(r, c);
    for (const [nr, nc] of [[r-1,c],[r+1,c],[r,c-1],[r,c+1]]) {
      if (nr >= 0 && nr < SIZE && nc >= 0 && nc < SIZE) addIfForeign(nr, nc);
    }
  }
  if (touchedIdx.size === 0) return { pts: basePts, shares: [] };
  const n = touchedIdx.size;
  const share = Math.round((basePts * (n + 1)) / (6 * n));
  const shares = [...touchedIdx].map((index) => ({ index, amount: share }));
  return { pts: basePts - share * n, shares };
}
```

**Placement validation** (`src/utils/validator.ts` — structural rules; dictionary check is a separate pass in `validatePlacement`):
```ts
export function validatePlacementStructural(board, placed, owner, ownCorners, isFirstMove) {
  const keys = Object.keys(placed);
  if (keys.length === 0) return { valid: false, reason: 'Harf yerleştirilmedi.' };
  const coords = keys.map((k) => k.split(',').map(Number) as [number, number]);
  const rows = [...new Set(coords.map((p) => p[0]))];
  const cols = [...new Set(coords.map((p) => p[1]))];
  const horiz = rows.length === 1, vert = cols.length === 1;
  if (!horiz && !vert) return { valid: false, reason: 'Harfler aynı satır ya da sütunda olmalı.' };
  // ... continuity check omitted (no gaps between placed/existing tiles) ...
  const fresh = freshCorners(board, ownCorners, owner);
  const startsFreshCorner = coords.some(([r, c]) =>
    fresh.some((corner) => { const [cr, cc] = cornerCell(corner); return r === cr && c === cc; }));
  if (isFirstMove) {
    if (!startsFreshCorner) return { valid: false, reason: 'İlk kelimen kendi köşe karesine değmeli.' };
  } else {
    const connects = coords.some(([r, c]) => [[r-1,c],[r+1,c],[r,c-1],[r,c+1]]
      .some(([nr, nc]) => nr >= 0 && nr < SIZE && nc >= 0 && nc < SIZE && board[nr][nc]));
    if (!connects && !startsFreshCorner) return { valid: false, reason: 'Kelime mevcut harflere bağlanmalı.' };
  }
  const formed = getFormedWords(board, placed);
  if (formed.length === 0) return { valid: false, reason: 'Geçerli kelime oluşmadı.' };
  return { valid: true, words: formed.map((f) => f.word) };
}
```

**Turn advancement / game-end** (`src/game/gameReducer.ts`):
```ts
function advanceTurn(state: GameState): GameState {
  const next = nextActiveIndex(state.players, state.current);
  const nextState: GameState = {
    ...state, turnCount: state.turnCount + 1, current: next,
    selectedTile: null, swapMode: false, swapSelection: [],
  };
  const someoneEmpty = nextState.players.some((p) => !p.surrendered && p.rack.length === 0);
  if (someoneEmpty && nextState.bag.length === 0) return endGame(nextState);
  return nextState;
}

function endGame(state: GameState, reason: GameState['endReason'] = 'normal'): GameState {
  const remaining = (p: Player) => p.rack.reduce((s, t) => s + t.pts, 0);
  const players = state.players.map((p) => ({ ...p, score: Math.max(0, p.score - remaining(p)) }));
  return { ...state, players, isGameOver: true, endReason: reason, message: 'Oyun bitti.', messageType: '' };
}
```

**PLAY action** (`gameReducer.ts`, delegates to the shared `applyPlacement` helper — both `PLAY` and `AI_PLAY` build a `placed` map and call it):
```ts
case 'PLAY': {
  if (state.phase !== 'play' || state.isGameOver) return state;
  const me = state.players[state.current];
  const check = action.skipWordCheck
    ? validatePlacementStructural(state.board, state.placed, state.current, me.corners, isFirstMove(state))
    : validatePlacement(state.board, state.placed, state.current, me.corners, isFirstMove(state));
  if (!check.valid) return { ...state, message: check.reason!, messageType: 'err' };
  const basePts = calcScore(state.board, state.placed, state.bonuses);
  const moved = applyPlacement(state, state.placed, me.rack, basePts, ({ pts, shares, finishBonus, words }) => {
    const bonusNote = shares.length > 0
      ? ` (${shares.map((s) => `${s.amount} puanı ${state.players[s.index].name} kaptı`).join(', ')})` : '';
    const finishBonusNote = finishBonus > 0 ? ` (jokerli bitiş bonusu +${finishBonus})` : '';
    return `${me.name}: +${pts} puan${bonusNote}${finishBonusNote} Kelimeler: ${words.join(', ')}`;
  });
  return advanceTurn(moved);
}
```

**End-of-game ranking** (`src/utils/ranking.ts` — surrendered players always sort after active ones, regardless of score):
```ts
export function rankPlayers(players: Player[]): RankedPlayer[] {
  const withIndex = players.map((p, index) => ({ p, index }));
  const active = withIndex.filter((x) => !x.p.surrendered).sort((a, b) => b.p.score - a.p.score);
  const surrendered = withIndex.filter((x) => x.p.surrendered).sort((a, b) => b.p.score - a.p.score);
  const ordered = [...active, ...surrendered];
  let rank = 0, prevScore: number | null = null, prevSurrendered = false;
  return ordered.map((x, pos) => {
    if (prevScore === null || x.p.score !== prevScore || x.p.surrendered !== prevSurrendered) rank = pos + 1;
    prevScore = x.p.score; prevSurrendered = x.p.surrendered;
    return { player: x.p, index: x.index, rank };
  });
}
```

League points (`src/utils/leaguePoints.ts`): `surrendered → -2`; `rank===1 → +2`; `rank===2 && playerCount!==2 → +1`; else `0`.

## 5. Persistence

**`localStorage` keys** (all guarded with try/catch, silently no-op if storage unavailable):

| Key | Written by | Holds |
|---|---|---|
| `kelimeki:game-state` | `gameStorage.ts` | Full in-progress local `GameState` + `savedAt` epoch, versioned (`STORAGE_VERSION`), 7-day abandonment (`ABANDON_TIMEOUT_MS`) |
| `kelimeki:pending-abandoned-game` | `gameStorage.ts` | One-shot queued record of a just-expired game (for a mount effect to log a surrender + penalty) |
| `kelimeki:pending-games` (+ legacy `harfik:pending-games`) | `gameSync.ts` | Array of finished-game records not yet durably saved (offline/guest), capped at 300, 7-day TTL |
| `kelimeki:pending-feedback` | `feedbackSync.ts` | Same offline-queue pattern for the feedback form |
| `kelimeki:pending-friend-invite-token` | `friendInvite.ts` | One-shot pending friend-invite token (read-then-clear) |
| `kelimeki:seen-quickstart` | `onboarding.ts` | Boolean flag, quickstart popup shown once |
| `kelimeki:seen-chat-intro` | in-game chat code | Boolean flag, chat intro popup shown once |
| `kelimeki:chat-last-read:<gameId>` | in-game chat code | Per-game last-read timestamp (unread-dot logic) |
| `kelimeki:anon-id`, `kelimeki:anon-visit-date` | `visitTracking.ts` | Anonymous guest UUID + last-ping date |
| `kelimeki:utm-source` | `visitTracking.ts` | First-touch `?ref=` campaign tag |
| `kelimeki_landscape_hint_dismissed` (`sessionStorage`) | `LandscapeHint.tsx` | Per-tab dismiss flag |
| `kelimeki_a2hs_dismissed` | `AddToHomeScreen.tsx` | Install-banner dismiss flag |

**Remote persistence (Supabase Postgres, optional — app runs fully offline without it):** `games` (finished-game records, board/message snapshots, likes), `game_finishes` (anonymous duration telemetry), `player_stats`/`player_stats_overall` (views), `profiles`, `friend_requests`, `friend_invite_links`, `online_games`/`online_game_states`/`online_game_secrets`/`online_game_moves`/`online_game_messages` (live multiplayer, secrets table never grants client access), `local_game_saves` (cross-device resume for AI games), `feedback`, `online_game_message_mutes`/`online_game_chat_reports`, `admin_ban_log`, `guest_visits`, plus a server-side `words` table used only by Edge Functions/RPCs (`is_valid_word`, `play-ai-turn`) — not the same asset as `src/data/words.ts`. All writes/reads go through `src/lib/api.ts`.

**PWA/offline cache:** `vite-plugin-pwa` (`generateSW`) precaches JS/CSS chunks including the dictionary chunk, so validation works fully offline once cached.

## 6. Third-party dependencies

| Package | Role |
|---|---|
| `react`, `react-dom` | UI framework |
| `@supabase/supabase-js` | Postgres/auth/realtime/storage client (only loaded/used if env vars present) |
| `html-to-image` | DOM node → PNG capture for shared game-board images |
| `@fontsource/nunito` (dev) | Tile-letter font. ⚠ The **package** is build-time only: the shipped `.woff2` files live in `src/fonts/files/`, and only the asset generators read `node_modules/@fontsource/…` |
| `@fontsource/space-grotesk`, `@fontsource/space-mono` (dev) | UI fonts, same story — the shipped copies are raw `.woff2` in `public/fonts/` (for `<link rel="preload">`) and `src/fonts/files/` |
| `vite`, `@vitejs/plugin-react` | Build tool / React JSX transform |
| `vite-plugin-pwa` | Service worker generation + manifest |
| `typescript` | Type checking (`tsc -b` is the entire "lint" step — no separate ESLint) |
| `tailwindcss`, `postcss`, `autoprefixer` | CSS build |
| `@playwright/test`, `playwright` | Smoke-test runner (`tests/smoke.spec.ts` only — not a full test suite) |
| `@fontsource/caveat` (dev) | Used only by build-time scripts (`generate-logo.mjs` etc.) to rasterize the logo into static SVG paths; never shipped to the browser |
| `opentype.js` (dev) | Parses Caveat font to extract glyph outlines for the static logo/K-lig SVG path generators |
| `sharp` (dev) | Image generation for icons/OG image at build time |
| `esbuild` (dev) | CLI used by 14 npm scripts (golden vectors, every `verify-*` wrapper, the reel builder) to bundle a TS entry into a runnable `.mjs` |

No state-management library (plain `useReducer`/`useContext`), no router (manual `window.location.pathname` switch in `main.tsx`), no CSS-in-JS, no test-mocking framework.

## 7. Unfinished / placeholder / known-buggy / flag-before-porting

The codebase has **zero literal `TODO`/`FIXME`/`XXX`/`HACK` markers** — grep confirms none exist anywhere in `src/`. Everything below is instead documented narratively in `CLAUDE.md` as an accepted limitation, a bug that was found-and-fixed (relevant if porting old behavior by accident), or an explicitly out-of-scope decision. Flagging for port review:

- **`games.board_snapshot`/`messages` are permanently null for two known pre-migration production games** — the online-game snapshot/chat-freeze logic was added after those games finished; there is no way to backfill them. Any port that assumes snapshot/messages are always present for `online_game_id`-linked rows will need a null path.
- **Online multiplayer (`OnlineGameScreen.tsx`, Edge Functions, RLS-based chat moderation) is explicitly stated as never end-to-end tested with two real concurrent browser sessions** — validated only via single-session SQL/RPC simulation in production, then "confirmed by the user" post-hoc. Treat all of Faz 3/3.6 and the chat-moderation RPCs as unverified for concurrent-edit races beyond what the row-level `for update` locks provide.
- **`play-ai-turn` Edge Function duplicates `ai.ts`/`validator.ts`/`board.ts`/`constants.ts`/`turkish.ts`/`tiles.ts` as hand-maintained copies** under `supabase/functions/_game/` — there are already-documented drift risks; a port must decide whether to re-derive server-side AI logic from the client copy or vice versa, since nothing currently keeps them in sync automatically.
- **`AdminDashboard`'s chat-transcript viewer only supports finished games** — viewing a live/unfinished game's chat from the admin panel is explicitly out of scope (would need a new admin-bypass RPC).
- **`guest_visits` is intentionally unlinkable to any later account** (pure anonymous UUID, no join key) — any "first visit → signup" funnel metric does not exist and cannot be added without breaking the stated privacy contract in `PrivacyModal.tsx`.
- **`pg_net` extension is stuck in the `public` Postgres schema** (linter warning) — `ALTER EXTENSION ... SET SCHEMA` fails for `pg_net` (`0A000`), a known/accepted upstream limitation, not fixed.
- **No automated test coverage beyond one Playwright smoke test** (`tests/smoke.spec.ts`, 59 lines: app loads, a 2-player local game can start, AI moves, unknown path resolves via SPA fallback). Everything else — live multiplayer, messaging, email notifications, admin panel — has zero automated coverage; a manual checklist lives in `TESTING.md` (not read for this brief) instead of tests.
- **`respond_to_game_invite` decline path historically left abandoned online games invisible to three separate client-side counters** (`LiveGamesTab`, `fetchPendingLiveGames`, default-tab logic) until a 4 Ağustos 2026 fix — flagged as a class of bug (a status filter added in one place but not mirrored to sibling counters) worth re-auditing if porting the online-game list logic, since the pattern recurred multiple times per `CLAUDE.md`.
- **Writes to `local_game_saves` and the list query that reads it race against each other, and the fix is backend-level, not React-level** — abandoning a zero-move AI game fires a `DELETE` and then, in the same tick, a `SELECT` (triggered by the resulting screen transition). PostgREST processes them concurrently, so the `SELECT` routinely returned the row the `DELETE` had not yet committed, re-showing a game the user had just discarded (fixed 5 Ağustos 2026 by funnelling *every* write to that table through one promise queue and having the list query await it). **Any client hitting this schema reproduces this**, Flutter included — it is not a React artifact. Port the invariant, not the code: one serialized write path per row-owning table, and no read issued before the pending write for that row has resolved.
- **Session-scoped UI state must be reset on account change, and the reset must key on `user.id` rather than the auth-user object** — two defects of this class shipped together (main-tab selection surviving logout, and a "apply login default once" flag never resetting for a second account), each masking the other so the existing manual checklist passed for the wrong reason. The React-specific cause (components staying mounted across logout) will not carry over, but the rule does: in a Flutter port any provider/notifier that outlives sign-out (selected tab, one-shot flags, cached per-user lists) needs an explicit account-change reset. Keying it on the auth object is a live trap in Dart too — `supabase_flutter`'s `onAuthStateChange` emits `tokenRefreshed` roughly hourly with a fresh user object, so an identity-based check turns a once-per-session action into an hourly one.
- **`ErrorBoundary.tsx` offers a manual "clear saved game and reload" escape hatch** for corrupt `localStorage` state causing a crash loop — implies the local-save deserialization path (`gameStorage.ts`) is not considered fully crash-proof against malformed/future-shaped JSON.
- **Two components are marked `AUTO-GENERATED — do not hand-edit`** (`LogoMark.tsx`, `KLigMark.tsx`): their real source of truth is `scripts/generate-logo-paths.mjs`/`generate-klig-paths.mjs`, which are not part of the runtime app but must be ported/rerun to regenerate these files if the wordmark ever needs to change.
- **`src/lib/database.types.ts` is hand-written**, not generated from the live schema via the Supabase CLI/MCP type generator despite that tooling being available in this environment — its accuracy versus the actual 144-migration schema history is unverified by tooling, only by manual cross-referencing.
