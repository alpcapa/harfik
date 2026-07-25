-- games tablosuna, oyunun bittiği andaki tahtanın kompakt bir JSON anlık
-- görüntüsünü saklamak için board_snapshot sütunu eklenir. Yalnızca dolu
-- hücreler tutulur (bkz. src/utils/boardSnapshot.ts — serializeBoardSnapshot);
-- bonus bölgesi/köşe düzeni sabitlerden türetildiğinden ayrıca saklanmaz.
-- GameHistoryModal, kullanıcı bir oyuna tıklayınca bu sütunu ayrı bir
-- sorguyla (fetchGameBoardSnapshot) lazy çeker — liste sorgusuna (fetchMyGames)
-- dahil edilmez, satır başına birkaç KB'a varabildiğinden sayfa yükünü
-- şişirmesin diye. Bu sütun eklenmeden önceki kayıtlarda null.

alter table public.games
  add column if not exists board_snapshot jsonb;
