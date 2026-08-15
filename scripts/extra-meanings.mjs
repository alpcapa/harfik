// Kelimeki — TDK'de zaten var olan bazı kelimelere günlük dilde yaygın olan
// ek bir anlam ekler (ör. "amerika" TDK'de yalnızca kıta anlamıyla geçer;
// günlük dilde Amerika Birleşik Devletleri için de kullanıldığından bu
// anlam burada eklenir). proper-nouns.mjs'in aksine burada amaç GTS'te
// zaten var olan bir kelimeyi zenginleştirmektir — "kelime zaten varsa
// dokunma" kuralı burada uygulanmaz, build-dictionary.mjs bu listeyi dict'e
// zaten var olan kelimenin meanings dizisine ekler.
export const EXTRA_MEANINGS = {
  amerika: "Amerika Birleşik Devletleri'nin günlük dilde kullanılan adı.",
  kore: "Asya'da tarihî bir bölge ve yarımada; Kuzey Kore ile Güney Kore'nin ortak adı.",
};

// DİKKAT (15 Ağustos 2026) — "is" ile "ıs" AYRI kelimelerdir:
//   is  (i ile) = dumanın bıraktığı kara leke, kurum  → GTS'te zaten var
//   ıs  (ı ile) = sahip, iye, malik ("ıssız" bundan)  → extra-words.mjs'te
// Sahip/iye anlamı bir kez yanlışlıkla buraya, "is"in anlam listesine
// eklendi; "ıs" yeni bir madde olduğundan doğru yer extra-words.mjs.
// Türkçe i/ı ayrımını gözden kaçırmak bu projede yerleşik bir risk
// (bkz. trUpper/trLower kuralı) — bir kelime eklemeden önce ölç.
