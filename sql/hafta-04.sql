-- =====================================================================
-- Hafta 4: Temizlenmiş veriyi PostgreSQL'e yükleme ve ilk SELECT sorguları
-- Kura #37 · Tarım × RAG bilgi asistanı × Anomali tespiti
--
-- Çalıştırma (repo kök klasöründen):
--   createdb vize
--   psql -d vize -f sql/hafta-04.sql
--
-- Not: Buradaki CREATE TABLE ifadeleri yalnızca CSV'yi yükleyebilmek içindir.
-- Asıl şema tasarımı (ERD, anahtarlar, ilişkiler) Hafta 7 ve 9'da yapılacak.
-- =====================================================================

DROP TABLE IF EXISTS responses;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS weather_daily;

CREATE TABLE questions (
    id              integer,
    source_row      text,      -- ham dosyadaki satır numarası (izlenebilirlik için)
    topic           text,      -- temizlenmiş konu (QueryType)
    topic_raw       text,      -- ham yazım, karşılaştırma için tutuluyor
    asked_at        date,      -- KCC'de yalnızca gün var, saat yok
    channel         text,
    sector          text,
    crop            text,
    question_length integer,
    query_text      text,
    answer_text     text
);

CREATE TABLE responses (
    id                 integer,
    question_id        integer,
    source_chunk_count integer,
    generation_ms      numeric,
    is_empty           boolean,
    top_similarity     numeric
);

CREATE TABLE weather_daily (
    date             date,
    avg_temp_c       numeric,
    precipitation_mm numeric
);

\copy questions     FROM 'data/clean/questions.csv'     WITH (FORMAT csv, HEADER true)
\copy responses     FROM 'data/clean/responses.csv'     WITH (FORMAT csv, HEADER true)
\copy weather_daily FROM 'data/clean/weather_daily.csv' WITH (FORMAT csv, HEADER true)

-- ---------------------------------------------------------------------
-- İlk SELECT sorguları: veri yüklendi mi, nasıl görünüyor?
-- ---------------------------------------------------------------------

-- 1) Her tabloda kaç satır var? Veri kartındaki sayılarla aynı olmalı.
SELECT 'questions' AS tablo, COUNT(*) FROM questions
UNION ALL SELECT 'responses', COUNT(*) FROM responses
UNION ALL SELECT 'weather_daily', COUNT(*) FROM weather_daily;

-- 2) İlk 10 soru: kolonlar doğru yerde mi?
SELECT id, asked_at, topic, crop, question_length, LEFT(query_text, 60) AS soru
FROM questions
ORDER BY asked_at, id
LIMIT 10;

-- 3) Tarih aralığı: sorular ve hava verisi aynı dönemi kapsıyor mu?
SELECT MIN(asked_at) AS ilk_soru, MAX(asked_at) AS son_soru FROM questions;
SELECT MIN(date) AS ilk_gun, MAX(date) AS son_gun FROM weather_daily;

-- 4) WHERE: Hava durumu ile ilgili sorular
SELECT id, asked_at, LEFT(query_text, 60) AS soru
FROM questions
WHERE topic = 'weather'
ORDER BY asked_at
LIMIT 10;

-- 5) WHERE + NULL: konusu boş kalan sorular
SELECT id, topic_raw, LEFT(query_text, 60) AS soru
FROM questions
WHERE topic IS NULL
LIMIT 10;

-- 6) WHERE: Hiç kaynak parça bulunamayan yanıtlar
SELECT id, question_id, source_chunk_count, is_empty, generation_ms
FROM responses
WHERE source_chunk_count = 0
LIMIT 10;

-- 7) WHERE: Yağışı 20 mm'nin üstünde olan günler
SELECT date, avg_temp_c, precipitation_mm
FROM weather_daily
WHERE precipitation_mm > 20
ORDER BY precipitation_mm DESC
LIMIT 10;
