-- Adım 3'ün (submit_move) gerçek test oyunuyla denenmesi sırasında ortaya
-- çıkan bir hata: online_game_moves_turn_check kısıtı "turn >= 1" olarak
-- yazılmıştı, ama yerel oyunda (gameReducer.ts) turlar 0'dan başlıyor
-- (turnCount: 0 ilk hamlede) — submit_move de aynı sayacı (online_game_states
-- .turn_count) kullandığından ilk hamle her zaman bu kısıtı ihlal ediyordu.
alter table public.online_game_moves
  drop constraint online_game_moves_turn_check;

alter table public.online_game_moves
  add constraint online_game_moves_turn_check check (turn >= 0);
