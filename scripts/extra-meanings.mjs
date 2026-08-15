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
  is: 'Eski Türkçede ve halk ağzında sahip, iye, malik ("ıssız" sözcüğü bu kökten türemiştir).',
};
