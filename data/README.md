# Veri Kartı

## 1. Kaynaklar

### 1a. Kisan Call Centre (KCC) çiftçi soruları

| Alan | Değer |
|---|---|
| Asıl sahibi | Department of Agriculture and Farmers Welfare, Hindistan; Open Government Data Platform (data.gov.in), "Kisan Call Centre (KCC) farmer queries" |
| İndirildiği yer | Hugging Face `Vrushali/MH` (Maharashtra eyaleti KCC kayıtlarının kopyası, 3.301.127 satır), https://huggingface.co/datasets/Vrushali/MH |
| Lisans | Asıl veri: Government Open Data License – India (GODL). Hugging Face kopyasının sayfasında ayrı bir lisans belirtilmemiş; bu yüzden asıl kaynağın lisansı esas alındı. |
| İndirme yöntemi | `scripts/01_indir_kcc.py`: veri setinin iki Parquet dosyası (yaklaşık 135 MB) indirildi, ilçe ve yıl bilgisayarda süzüldü. Parquet dosyaları büyük olduğu için repoya konmadı (`.gitignore`). |
| Filtre | DistrictName = `NASIK` (veride Nashik bu şekilde yazılıyor), Year = 2018 |
| Yıl seçimi | İlçenin en az 2.000 kaydı olan en son yılı. Veri setinde 2019 ve sonrası yok. İlçedeki tüm kayıt: 237.717 (2009–2018). |
| İndirme tarihi | 2026-11-05 17:39 UTC |
| Ham dosya | `data/raw/kcc_nasik_2018.csv` (indirme kaydı: `data/raw/kcc_indirme_kaydi.json`) |
| Satır × sütun (ham) | 23.843 × 14 |

Ham kolonlar: `Unnamed: 0` (kaynak satır no), BlockName, Category, Year, Month, Day, Crop, DistrictName, QueryType, Season, Sector, StateName, QueryText, KccAns.

Hamdaki boş hücreler: Season 12.644, QueryType 1.151, Crop 905, Sector 828, QueryText 33, KccAns 15.

### 1b. Open-Meteo günlük hava verisi

| Alan | Değer |
|---|---|
| Kaynak | Open-Meteo Historical Weather API, https://open-meteo.com |
| Lisans | CC BY 4.0 ("Weather data by Open-Meteo.com") |
| Konum | Nashik, Maharashtra (19.9975 K, 73.7898 D), saat dilimi Asia/Kolkata |
| Dönem | 2018-01-01 – 2018-12-31, günlük |
| Değişkenler | temperature_2m_mean (°C), precipitation_sum (mm) |
| İndirme tarihi | 2026-11-05 17:39 UTC |
| Ham dosya | `data/raw/openmeteo_2018.json` (istek URL'si dosyanın içinde `_indirme` alanında) |
| Satır × sütun | 365 gün × 3 (tarih, sıcaklık, yağış) |

## 2. Temizlenmiş tablolar

| Dosya | Satır | Sütun | Sayısal sütunlar | Tarih sütunu |
|---|---|---|---|---|
| `data/clean/questions.csv` | 23.843 | 11 | question_length | asked_at |
| `data/clean/responses.csv` | 23.843 | 6 | source_chunk_count, generation_ms, top_similarity | — |
| `data/clean/weather_daily.csv` | 365 | 3 | avg_temp_c, precipitation_mm | date |

Kurallar: en az 500 satır ✔ (23.843), en az 4 sayısal sütun ✔ (toplam 6), en az 1 tarih sütunu ✔.

## 3. Temizleme adımları (`scripts/03_temizle.py`)

Ham dosyalar hiç değiştirilmedi; temiz hâller `data/clean/` altında ayrı dosyalardır. Tüm sayılar `data/clean/temizleme_raporu.json` dosyasından alındı.

1. **Tarih:** KCC'de tarih Year / Month / Day olarak üç ayrı kolonda. Birleştirilip `asked_at` (DATE) yapıldı. Geçersiz tarih: 0 satır. **Saat bilgisi yok**, bu yüzden saat bazlı analiz yapılmadı.
2. **Konu (QueryType):** Fazla boşluk silindi, küçük harfe çevrildi, açık eşanlamlılar birleştirildi. Bu veride birleşen tek çift "Seeds and Planting Material" → "seeds" oldu; farklı değer sayısı 48'den 47'ye indi. Ham hâli `topic_raw` kolonunda tutuldu. Boş konu: 1.151 satır, NULL bırakıldı. Bunların yaklaşık %71'i soru metnine göre hava durumu sorusu, ama konu **tahmin edilip doldurulmadı**.
3. **Soru metni:** Boş olanlar NULL: 33 satır. `question_length` karakter sayısıdır, soru yoksa NULL.
4. **Yanıt metni:** Boş (15) ya da yer tutucu ("NA", "0", "-" gibi, 7) olan yanıtlar NULL yapıldı ve `is_empty = true` işaretlendi: toplam 22 satır.
5. **Tekrarlar:** Kaynak no dışında tamamen aynı olan 1.573 satır bulundu ama **silinmedi**, çünkü aynı gün aynı soruyu (ör. "weather forecast") soran farklı çiftçiler olabilir.
6. **Hava:** Boş sıcaklık 0, boş yağış 0, negatif yağış 0. Düzeltme gerekmedi.
7. **Kanal:** KCC tek kanallı bir telefon hattıdır; `channel` tüm satırlarda `phone`.

## 4. Türetilmiş sütunlar (gerçek veri değil, hesaplanmış)

`responses` tablosundaki `source_chunk_count`, `generation_ms` ve `top_similarity` sütunları KCC'de yoktur. Bunlar **dil modeliyle üretilmedi, uydurulmadı**; `scripts/04_rag_yanitlari.py` ile gerçekten çalıştırılan bir getirme (retrieval) adımıyla **ölçüldü** (ayarlar: `data/clean/rag_ayarlari.json`):

- Bilgi tabanı: KCC uzmanlarının boş olmayan yanıtları, her farklı yanıt bir parça. Parça sayısı: 7.461.
- Yöntem: TF-IDF (1–2 gram) + kosinüs benzerliği. Her soru için kendi yanıt metni dışarıda tutuldu (leave-one-out).
- `source_chunk_count`: benzerliği ≥ 0,30 olan en fazla 5 parçanın sayısı. 614 yanıtta 0.
- `generation_ms`: getirme adımının bu bilgisayarda ölçülen süresi (medyan 0,99 ms). Dil modeli yanıt süresi **değildir** ve bilgisayara göre değişir.
- `is_empty` ise KCC'nin kendi yanıt alanından gelir (gerçek veri, 22 satır true). İkisi bazen çelişir; Hafta 5 Sorgu 2 bunu gösterir.

## 5. Dil modeliyle üretilmiş satırlar

**Yok.** Hiçbir satır ya da değer bir dil modeliyle üretilmedi. Sorular ve hava verisi %100 gerçek; `responses` tablosundaki üç sütun yukarıda açıklandığı gibi ölçülerek türetildi.

## 6. Bilinen sınırlar

- KCC soruları çoğunlukla çağrı merkezi görevlisinin yazdığı kısa İngilizce özetlerdir; çiftçinin kendi cümlesi değildir. Yazım tutarsız ("MARKATE RATE", büyük/küçük harf karışık).
- Soruların %52'si hava durumu sorusu; bu, konu bazında yapılan analizleri weather konusuna doğru çarpıtır.
- Hugging Face kopyası tek eyaleti (Maharashtra) kapsar ve 2018'de bitiyor; seçilen ilçe ve yıl tüm KCC'yi temsil etmez.
