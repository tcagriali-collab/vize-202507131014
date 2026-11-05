# SCENARIO.md · Kura #37

**Öğrenci no:** 202507131014
**Kura:** #37 · Tarım × RAG bilgi asistanı × Anomali tespiti
**Ders:** Veritabanı Yönetim Sistemleri (PostgreSQL), Güz 2026

> Not: Kura listesinde #37 satırı `202607131014` olarak yazılmıştır. Numaram `202507131014`'tür; yıl hanesinin yanlış girildiğini düşünüyorum ve öğretim elemanına teyit için yazdım.

## Problem

Bir tarım danışmanlık firması çiftçilerin sorularını yanıtlayan RAG tabanlı bir bilgi asistanı işletiyor. Asistan, bilgi tabanındaki tarım kılavuzu parçalarından (chunk) ilgili olanları getirip yanıt üretiyor. Soru trafiği normalde mevsime göre dalgalanır; ama bazen bir konuda ani bir artış olur (bir zararlı salgını, bir hastalık haberi, yeni bir destek programı). Firma bu olağandışı artışları erken görmek ve asistanın bu dönemlerde dayanacak kaynak bulup bulamadığını izlemek istiyor.

## Ana soru

Soru trafiğinde normal dışı artışlar hangi konuda ve hangi hafta yoğunlaşıyor? Bu artışlar mevsimsel hava değişiklikleriyle uyuşuyor mu?

## Hedef kullanıcı

- **Firmanın içerik ekibi:** Hangi konuda bilgi tabanına yeni kılavuz eklemesi gerektiğini görür.
- **Operasyon sorumlusu:** Artış haftalarında asistanın boş ya da kaynaksız yanıt oranını izler.

## Veri kaynağı adayları ve seçim

| Aday | Durum |
|---|---|
| **Kisan Call Centre (KCC) çiftçi soruları**, Hindistan Tarım Bakanlığı, data.gov.in (GODL-India) | **Seçildi.** Gerçek çiftçi soruları, uzman yanıtları, konu (QueryType) ve tarih var. Hugging Face'teki `Vrushali/MH` (Maharashtra) kopyasından indirildi. Kapsam: Nashik ilçesi, 2018 (23.843 soru). |
| Open-Meteo Historical Weather API (CC BY 4.0) | **Seçildi.** Soruların geldiği ilçe (Nashik) için 2018 yılının günlük sıcaklık ve yağışı. |
| Hugging Face "agriculture QA" veri setleri | Elendi: tarih bilgisi yok, zaman serisi kurulamıyor. |

Neden Hindistan verisi: Türkiye için tarih damgalı, açık lisanslı çiftçi soru-yanıt kaydı bulamadım. KCC, gerçek bir çağrı merkezinin kayıtlarıdır ve senaryodaki "çiftçi soruları + yanıt + zaman" ihtiyacını birebir karşılar. Hava verisi, senaryodaki "öğrencinin ili" yerine **soruların geldiği ilçe** için alındı; aksi halde hava ile soru trafiği arasındaki ilişki anlamsız olurdu.

## Tablo adayları (Hafta 3)

| Tablo | Kolonlar | Not |
|---|---|---|
| `questions` | id, topic, asked_at, channel, sector, crop, question_length, query_text | KCC'den. `topic` = QueryType. `channel` tüm satırlarda `phone` (KCC bir telefon hattıdır). |
| `responses` | id, question_id, source_chunk_count, generation_ms, is_empty | `is_empty` KCC yanıt alanından gelir. `source_chunk_count` ve `generation_ms` yerelde çalıştırılan getirme adımıyla **ölçülür** (bkz. veri kartı). |
| `weather_daily` | date, avg_temp_c, precipitation_mm | Open-Meteo, Nashik. |

İlişkiler (Hafta 7'de ERD ile ayrıntılanacak): `responses.question_id → questions.id`; `questions.asked_at` ile `weather_daily.date` gün üzerinden eşleşir.

## YZ bileşeni

RAG bilgi asistanı + anomali tespiti.

- **Vize kapsamında:** Getirme adımı (TF-IDF + kosinüs benzerliği) gerçekten çalıştırıldı ve her soru için kaç kaynak parça bulunduğu ile süresi kaydedildi. Anomali, Hafta 5 Sorgu 3'te basit bir kuralla arandı: bir konunun haftalık soru sayısı, o konunun haftalık ortalamasının 2 katını aşarsa aday sayılır.
- **Dönem sonu:** Hareketli ortalama üzerine üç standart sapma kuralı, her uyarı için bir kayıt ve uyarının insan incelemesi sonucunu tutan bir tablo.

## Sınırlar ve dikkat edilecekler

- **Anomali kötü bir şey olduğu anlamına gelmez.** Yalnızca olağandışı olduğunu gösterir. Bir hastalık haberi ya da yeni bir destek programı da artış yaratır.
- **Hava ile soru sayısı arasındaki ilişki nedensellik değildir.** Muson dönemi aynı zamanda ekim ve zararlı dönemidir; asıl etken bunlar olabilir.
- KCC'de yalnızca **gün** var, saat yok. Bu yüzden saat bazlı analiz yapılamaz.
- KCC yanıtları tarımsal tavsiye olarak kullanılmaz; bu proje veri akışını ve sorgu mantığını gösterir.
