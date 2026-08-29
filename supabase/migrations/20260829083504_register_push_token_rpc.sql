-- Kelimeki — push token DEVRİ artık RPC üzerinden (RLS onu sessizce reddediyordu)
--
-- BULUNUŞ (29 Ağustos 2026, gerçek cihaz testi, kontrol listesi adım 2.5):
-- Aynı telefonda Alp Çapa çıkıp kelimekitest2 girdi; `push_tokens` satırı
-- ESKİ kullanıcıda KALDI. Uygulamanın yaptığı upsert'ün birebir aynısı T2
-- kimliğiyle koşturulup kanıtlandı (işlem içinde, rollback ile):
--
--   ERROR 42501: new row violates row-level security policy
--                (USING expression) for table "push_tokens"
--
-- MEKANİZMA: birincil anahtar `token`. İkinci kullanıcı aynı token'ı upsert
-- edince çakışma UPDATE dalına düşüyor; `push_tokens_update_own` politikası
-- `USING (auth.uid() = user_id)` diyor ve bu MEVCUT satıra bakıyor — satır
-- hâlâ eski kullanıcının, dolayısıyla yeni kullanıcı için görünmez.
--
-- BEDELİ boşa gönderim DEĞİL, YANLIŞ KİŞİYE gönderim: eski hesaba gidecek
-- bildirim, yeni hesabın girişli olduğu telefona düşer.
--
-- ⚠ `push_gateways.dart`taki yorum "satır B'ye DEVREDİLİR" diyordu — yani
-- KAĞIT ÜZERİNDE doğru, üretimde yanlış bir değişmez daha (Parça 159'un
-- aynısı). Birim testi göremedi çünkü sahte depoda RLS yok: test çağrının
-- yapıldığını kanıtlıyor, yazmanın TUTTUĞUNU değil.
--
-- ÇÖZÜM: devri sunucu üstlensin. Politikalar SIKI kalıyor (istemci hâlâ
-- başkasının satırını doğrudan güncelleyemez); devir yalnızca bu
-- SECURITY DEFINER fonksiyonundan geçiyor.
--
-- GÜVENLİK: `user_id` İSTEMCİDEN ALINMIYOR, `auth.uid()`ten geliyor — yani
-- çağıran, token'ı başkasının üstüne yazamaz. Kalan tek yüzey, 155 karakterlik
-- bir FCM token'ını BİLEN birinin o satırı kendi üstüne alması; bu, tahmin
-- edilemez bir değere sahip olmayı gerektiriyor ve etkisi kendi bildirimini
-- başkasının telefonuna düşürmek (veri sızması değil).

create or replace function public.register_push_token (
  p_token text,
  p_platform text
) returns void
  language plpgsql
  security definer
  set search_path to 'public'
  as $function$
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli.';
  end if;
  if p_token is null or length(p_token) < 20 then
    raise exception 'Geçersiz token.';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'Geçersiz platform: %', p_platform;
  end if;

  insert into public.push_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
    set user_id = auth.uid(),
        platform = excluded.platform,
        updated_at = now();
end;
$function$;

revoke all on function public.register_push_token (text, text) from public;
grant execute on function public.register_push_token (text, text) to authenticated;
