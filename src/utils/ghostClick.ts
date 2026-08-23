// Kelimeki — bir pointer jestinin ardından gelen "hayalet" click'i yutar.
//
// NEDEN VAR (22 Ağustos 2026): dokunmatik tarayıcılar bir jestin pointer
// olaylarından SONRA uyumluluk (compat) `mousedown`/`mouseup`/`click`
// üretir ve bu üçü hit-test'i **O ANDAKİ DOM** üzerinde yapar. Yani jestin
// İÇİNDE ekranı değiştiren her kod (yeni bir pencere açmak, bir balonu
// kapatmak, bir taşı bırakmak) o click'i artık BAŞKA bir öğenin üstünde
// karşılar. Somut vakalar:
//  - Konmuş bir jokere dokunmak: pencere `pointerup` içinde açılıyordu,
//    compat click harf ızgarasına düşüp jokeri sessizce başka harfe
//    çeviriyor ya da zemine düşüp pencereyi anında kapatıyordu (bir
//    kullanıcı bildirdi: "tablo açılmadı ve A harfi C'ye döndü").
//  - Bir sürüklemenin bittiği hücrenin altındaki `onClick`in tetiklenmesi.
//  - Açık bir balonu/menüyü kapatmak için dışarı dokunmak: aynı jestin
//    click'i ALTTAKİ öğeyi de çalıştırıyordu (k-lig satırı → oyuncu kartı;
//    hesap menüsü açıkken tahtaya dokunmak → taş yerleştirme).
//
// Tek bir modül düzeyi bayrak ve tek bir capture dinleyicisi yeterli:
// aynı anda yalnızca BİR jest yaşıyor. Dinleyiciler ilk kullanımda kurulur
// ve uygulama ömrü boyunca kalır (sökülecek bir sahibi yok).
let armed = false;
let installed = false;

function install(): void {
  if (installed || typeof document === 'undefined') return;
  installed = true;

  document.addEventListener(
    'click',
    (e) => {
      // Klavyeyle tetiklenen click'ler (Enter/Space) `detail: 0` taşır ve bir
      // pointer jestinin parçası DEĞİLDİR — yutulacak hayalet her zaman
      // pointer kaynaklı, klavye erişilebilirliği bozulmamalı.
      if (e.detail === 0) return;
      if (!armed) return;
      armed = false;
      e.stopPropagation();
      e.preventDefault();
    },
    true,
  );

  // Beklenen hayalet click hiç gelmezse (dokunmatikte belirgin bir
  // hareketten sonra tarayıcı genelde click üretmiyor) bayrak bir sonraki
  // jestin BAŞINDA temizlenir — yoksa ilgisiz bir dokunuşu sessizce yutardı.
  // Zamanlayıcı yerine `pointerdown`: compat olayları AYNI jestin parçası ve
  // kendileri pointerdown ÜRETMEZ (ölçüldü), yani bu temizleme olay
  // SIRASINA bağlı, zamanlayıcı sırasına değil. Bir `setTimeout(0)` bu
  // Chromium'da da işe yarıyor (ölçüldü) ama o sıra hiçbir yerde garanti
  // edilmiyor ve hatanın kendisi zaten tarayıcılar arası olay zamanlaması
  // farkından doğuyor.
  document.addEventListener(
    'pointerdown',
    () => {
      armed = false;
    },
    true,
  );
}

/**
 * Bu jestin ardından gelecek TEK bir click'i yutar. Jestin İÇİNDE (pointer
 * ya da compat mouse olayında) ekranı değiştiren her yerden çağrılmalı.
 */
export function swallowNextClick(): void {
  install();
  armed = true;
}
