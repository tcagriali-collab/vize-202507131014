-- =====================================================================
-- Hafta 5: Analiz sorguları (GROUP BY, NULL, tarih fonksiyonları, CASE WHEN)
-- Kura #37 · Tarım × RAG bilgi asistanı × Anomali tespiti
--
-- Ana soru: Soru trafiğinde normal dışı artışlar hangi konuda ve hangi
-- hafta yoğunlaşıyor? Bu artışlar mevsimsel hava değişiklikleriyle uyuşuyor mu?
--
-- Çalıştırma:  psql -d vize -f sql/hafta-05.sql
--
-- JOIN Hafta 6 konusu olduğu için burada kullanılmadı. Tablolar arası bilgi
-- gerektiğinde alt sorgu (subquery) ile alındı.
-- Veri: Nashik (Maharashtra, Hindistan) ilçesi, 2018 yılı, 23.843 soru.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Sorgu 1 · Konuya ve haftaya göre soru sayısı
-- Konular: GROUP BY, date_trunc('week', ...), COALESCE
--
-- Ne soruyor: Her konu için her hafta kaç soru gelmiş? Bu tablo anomali
-- aramanın temelidir; "normal" haftalık hacmi görmeden artışı tanıyamayız.
-- Beklenti: Plant protection gibi zararlı/hastalık konularının muson
-- döneminde (Haziran–Eylül) arttığını, weather sorularının da yağmur
-- mevsimine yakın yükseldiğini bekliyorum. Konusu boş satırlar ayrı grupta görünür.
-- Not: date_trunc('week') haftayı pazartesiden başlatır. 31 Aralık 2018 pazartesi
-- olduğu için o tek gün ayrı bir "2018-12-31" haftası olarak görünür; o haftanın
-- düşük sayısı (42) yarım hafta olmasından kaynaklanır, gerçek bir düşüş değildir.
-- Sonuç: 933 konu–hafta satırı çıktı. Yılın 23.843 sorusunun 12.402'si (%52)
-- weather konusunda. Weather haftalık ortalaması 234 iken muson başında 490–539'a
-- çıkıyor (Haziran 2. hafta – Temmuz 2. hafta). Plant protection beklediğim gibi
-- Temmuz–Ağustos'ta artıyor (aylık 404 ve 399, Mayıs'ta 132), ama Ocak'ta da yüksek
-- (444); bu kış sebzeleri (domates, lahana) zararlılarıyla ilgili. Market information
-- ise beklemediğim şekilde kışın (Ocak ve Kasım–Aralık) yüksek, yağmur aylarında düşük.
-- 1.151 sorunun konusu boş; örneklere bakınca çoğu "weather forecast" sorusu.
-- ---------------------------------------------------------------------
SELECT
    COALESCE(topic, '(konu yok)')              AS konu,
    date_trunc('week', asked_at)::date         AS hafta,
    COUNT(*)                                   AS soru_sayisi
FROM questions
WHERE asked_at IS NOT NULL
GROUP BY COALESCE(topic, '(konu yok)'), date_trunc('week', asked_at)
ORDER BY hafta, soru_sayisi DESC;


-- ---------------------------------------------------------------------
-- Sorgu 2 · Kaynak parça bulunamayan yanıtların oranı (konu bazında)
-- Konular: GROUP BY, CASE WHEN içinde sayma, ROUND, NULL
--
-- Ne soruyor: RAG asistanı her konuda bilgi tabanından en az bir parça
-- bulabiliyor mu? source_chunk_count = 0 olan yanıt, asistanın dayanacak
-- kaynağı olmadan cevap vermesi riskidir.
-- Beklenti: Sık sorulan konularda (plant protection) oran düşük, nadir ya da
-- dağınık konularda (others, government schemes) yüksek olmalı.
-- İkinci sorgu tutarlılığı kontrol eder: KCC'nin kendi yanıt alanı boş
-- (is_empty) iken parça bulunmuş olabilir, ya da tersi. Bu çelişki
-- Hafta 4'te beklenen sorunlardan biridir.
-- Sonuç: Kaynak parça bulunamayan yanıtlar tüm veride 614 (%2,6). Oran sık
-- konularda düşük: weather %0,4, market information %1,4, plant protection %6,0.
-- Beklentim doğru çıktı: az soru alan konularda oran yüksek (field preparation
-- %22,5, dairy production %22,2). 1–5 sorusu olan konulardaki %100 ya da %0 gibi
-- değerler örneklem küçük olduğu için güvenilir değil.
-- Tutarlılık kontrolü: KCC yanıtı dolu olduğu halde parça bulunamayan 611 satır,
-- KCC yanıtı boş olduğu halde parça bulunan 19 satır var. Yani iki alan aynı şeyi
-- ölçmüyor: is_empty kaydın kendisini, source_chunk_count bilgi tabanının kapsamını
-- gösteriyor.
-- ---------------------------------------------------------------------
SELECT
    COALESCE((SELECT q.topic FROM questions q WHERE q.id = r.question_id), '(konu yok)') AS konu,
    COUNT(*)                                                       AS yanit_sayisi,
    SUM(CASE WHEN r.source_chunk_count = 0 THEN 1 ELSE 0 END)     AS parca_yok,
    ROUND(100.0 * SUM(CASE WHEN r.source_chunk_count = 0 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                           AS parca_yok_yuzde
FROM responses r
GROUP BY 1
ORDER BY parca_yok_yuzde DESC, yanit_sayisi DESC;

-- Tutarlılık kontrolü: is_empty ile source_chunk_count çapraz tablosu
SELECT
    is_empty                                  AS kcc_yaniti_bos,
    (source_chunk_count = 0)                  AS parca_bulunamadi,
    COUNT(*)                                  AS satir
FROM responses
GROUP BY is_empty, (source_chunk_count = 0)
ORDER BY 1, 2;


-- ---------------------------------------------------------------------
-- Sorgu 3 · Haftalık soru sayısı, o konunun haftalık ortalamasının
--           iki katından fazla olan konu–hafta çiftleri (anomali adayları)
-- Konular: GROUP BY, HAVING, alt sorgu, date_trunc
--
-- Ne soruyor: Hangi hafta hangi konuda "olağandışı" bir artış var?
-- Kural basit: bir haftanın sayısı, aynı konunun haftalık ortalamasının
-- 2 katını aşarsa anomali adayıdır.
-- Beklenti: Birkaç konu–hafta çifti çıkmalı; bunların çoğunun yağmur
-- mevsiminin başı ya da hasat dönemi gibi belirli haftalarda toplanmasını bekliyorum.
-- Dikkat: Ortalama yalnızca o konunun en az bir soru aldığı haftalar üzerinden
-- hesaplanır (hiç soru gelmeyen hafta 0 olarak sayılmaz). Bu, eşiği biraz
-- yükseltir. Anomali "kötü bir şey oldu" demek değildir, yalnızca olağandışıdır.
-- Sonuç: 73 konu–hafta çifti anomali adayı çıktı. En çok seeds (8 hafta),
-- nutrient management (7) ve market information (6). İki öbek var:
-- (1) Ocak başı: market information, fertilizer, seeds gibi pek çok konu aynı anda
-- işaretleniyor. Bu tek bir konuda salgın değil, Ocak'ta genel çağrı hacminin
-- yüksek olmasından (2.338 soru) kaynaklanıyor; kural toplam hacmi hesaba katmadığı
-- için yanlış alarm üretiyor.
-- (2) Muson dönemi (Haziran ortası – Temmuz sonu): weather (3 hafta, 475–539 soru),
-- varieties, seeds, weed management, bio-pesticides. Bu ekim mevsimiyle uyumlu ve
-- ana sorunun cevabı burada: artışlar yağmurların başladığı haftalarda yoğunlaşıyor.
-- Dönem sonu için kural, toplam hacme oranla (pay) ya da hareketli ortalamayla
-- iyileştirilmeli.
-- ---------------------------------------------------------------------
SELECT
    q.topic                                    AS konu,
    date_trunc('week', q.asked_at)::date       AS hafta,
    COUNT(*)                                   AS soru_sayisi,
    ROUND((SELECT AVG(h.n) FROM (
              SELECT COUNT(*) AS n
              FROM questions q2
              WHERE q2.topic = q.topic AND q2.asked_at IS NOT NULL
              GROUP BY date_trunc('week', q2.asked_at)
          ) h), 1)                             AS konu_haftalik_ortalama
FROM questions q
WHERE q.topic IS NOT NULL AND q.asked_at IS NOT NULL
GROUP BY q.topic, date_trunc('week', q.asked_at)
HAVING COUNT(*) > 2 * (SELECT AVG(h.n) FROM (
              SELECT COUNT(*) AS n
              FROM questions q2
              WHERE q2.topic = q.topic AND q2.asked_at IS NOT NULL
              GROUP BY date_trunc('week', q2.asked_at)
          ) h)
ORDER BY hafta, soru_sayisi DESC;


-- ---------------------------------------------------------------------
-- Sorgu 4 · Üretim süresini fast / medium / slow olarak sınıflandırma
--           ve her sınıfta boş yanıt oranı
-- Konular: CASE WHEN, GROUP BY, ROUND, NULL
--
-- Ne soruyor: Yavaş çalışan getirme adımları daha çok boş/kaynaksız yanıtla
-- mı sonuçlanıyor?
-- Sınırlar: Süreler yerel bilgisayarda ölçüldüğü için mutlak bir "yavaş"
-- değeri yok. Sınırlar verinin kendisinden alındı: alt üçte bir fast,
-- üst üçte bir slow (yüzdelik 33 ve 66).
-- Beklenti: Uzun sorular daha çok kelime içerdiği için biraz daha yavaş
-- olmalı; boş yanıt oranının süreyle güçlü bir ilişkisi olmasını beklemiyorum.
-- Sonuç: Üç sınıf neredeyse eşit büyüklükte (yaklaşık 7.850–8.130). Ortalama süre
-- fast 0,84 ms, medium 0,99 ms, slow 1,33 ms. Ortalama parça sayısı üçünde de
-- 4,55–4,60, boş yanıt oranı üçünde de %0,1. Parça bulunamama oranı fast sınıfında
-- biraz daha yüksek (%3,4, diğerleri %2,1–2,3); en hızlı aramalar büyük ihtimalle çok
-- kısa sorular ve bunlar daha az eşleşme buluyor. Beklediğim gibi süre ile boş yanıt
-- arasında anlamlı bir ilişki yok. Süreler yerel ölçüm olduğu için mutlak değerler
-- başka bilgisayarda farklı çıkar.
-- ---------------------------------------------------------------------
SELECT
    CASE
        WHEN generation_ms IS NULL THEN 'unknown'
        WHEN generation_ms < (SELECT percentile_cont(0.33) WITHIN GROUP (ORDER BY generation_ms) FROM responses) THEN 'fast'
        WHEN generation_ms < (SELECT percentile_cont(0.66) WITHIN GROUP (ORDER BY generation_ms) FROM responses) THEN 'medium'
        ELSE 'slow'
    END                                                         AS hiz,
    COUNT(*)                                                    AS yanit_sayisi,
    ROUND(AVG(generation_ms), 3)                                AS ort_ms,
    ROUND(AVG(source_chunk_count), 2)                           AS ort_parca,
    ROUND(100.0 * SUM(CASE WHEN is_empty THEN 1 ELSE 0 END) / COUNT(*), 1) AS bos_yanit_yuzde,
    ROUND(100.0 * SUM(CASE WHEN source_chunk_count = 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS parca_yok_yuzde
FROM responses
GROUP BY 1
ORDER BY ort_ms;


-- ---------------------------------------------------------------------
-- Sorgu 5 · Günlük yağış ile o günkü soru sayısı: haftalık özet
-- Konular: date_trunc, CASE WHEN, COALESCE, GROUP BY, alt sorgu
--
-- Ne soruyor: Yağışlı haftalarda soru trafiği değişiyor mu?
-- Önce her güne o günün soru sayısı eklenir (hava verisinde gün olup soru
-- olmayan günler 0 sayılır), sonra haftalık toplanır.
-- Beklenti: Muson başlangıcında (Haziran) soru sayısının yükselmesini bekliyorum.
-- Dikkat: Bu bir ilişki (korelasyon) incelemesidir, nedensellik değildir.
-- Hava ve soru aynı ilçe (Nashik) ve aynı yıl (2018) için alınmıştır.
-- Sonuç: Haftalık soru sayısı muson ile belirgin şekilde artıyor: Mayıs başında
-- haftada 200–300 soru varken, yağışın başladığı Haziran 3. haftadan Temmuz sonuna
-- kadar 660–820 soru. En yüksek hafta 2–8 Temmuz (820 soru, 67 mm yağış).
-- Gün tipine göre: yağışlı günlerde (≥10 mm) günlük ortalama 103,5 soru, hafif
-- yağışlı günlerde 82,1, kuru günlerde 53,0. Günlük yağış ile soru sayısı arasındaki
-- korelasyon 0,32 (orta-zayıf, pozitif). Ama Ocak–Mart da kuru olduğu halde yoğun
-- (Şubat 1. hafta 772 soru), Aralık ise çok sakin. Yani hava tek açıklama değil;
-- ekim takvimi ve kış sebzesi sezonu da etkili. Bu bir ilişkidir, nedensellik değildir.
-- ---------------------------------------------------------------------
WITH gunluk AS (
    SELECT
        w.date,
        w.avg_temp_c,
        w.precipitation_mm,
        (SELECT COUNT(*) FROM questions q WHERE q.asked_at = w.date) AS soru_sayisi
    FROM weather_daily w
)
SELECT
    date_trunc('week', date)::date                     AS hafta,
    SUM(soru_sayisi)                                   AS haftalik_soru,
    ROUND(AVG(avg_temp_c), 1)                          AS ort_sicaklik_c,
    ROUND(SUM(COALESCE(precipitation_mm, 0)), 1)       AS toplam_yagis_mm,
    COUNT(*) - COUNT(precipitation_mm)                 AS yagis_verisi_eksik_gun,
    CASE
        WHEN SUM(COALESCE(precipitation_mm, 0)) = 0  THEN 'dry'
        WHEN SUM(COALESCE(precipitation_mm, 0)) < 20 THEN 'light rain'
        ELSE 'rainy'
    END                                                AS hafta_tipi
FROM gunluk
GROUP BY date_trunc('week', date)
ORDER BY hafta;

-- Aynı veriden tek bir özet: gün tipine göre ortalama soru sayısı ve korelasyon
WITH gunluk AS (
    SELECT
        w.date,
        w.precipitation_mm,
        (SELECT COUNT(*) FROM questions q WHERE q.asked_at = w.date) AS soru_sayisi
    FROM weather_daily w
)
SELECT
    CASE
        WHEN precipitation_mm IS NULL THEN 'no data'
        WHEN precipitation_mm = 0     THEN 'dry'
        WHEN precipitation_mm < 10    THEN 'light rain'
        ELSE 'rainy'
    END                                    AS gun_tipi,
    COUNT(*)                               AS gun_sayisi,
    ROUND(AVG(soru_sayisi), 1)             AS gunluk_ort_soru
FROM gunluk
GROUP BY 1
ORDER BY gunluk_ort_soru DESC;

-- Tüm yıl için günlük yağış ile günlük soru sayısı arasındaki korelasyon (-1 ile 1 arası)
SELECT ROUND(corr(
           (SELECT COUNT(*) FROM questions q WHERE q.asked_at = w.date),
           w.precipitation_mm)::numeric, 3) AS yagis_soru_korelasyonu
FROM weather_daily w;
