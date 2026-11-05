# Yapay Zekâ Kullanım Beyanı

Bu çalışmada kullandığım yapay zekâ araçlarını ve ne için kullandığımı aşağıda beyan ediyorum.

| Araç | Sağlayıcı / sürüm | Kullanım tarihi | Ne için kullandım |
|---|---|---|---|
| Claude (Claude mobil uygulaması) | Anthropic, Claude Opus 5.5 | 5.11.2026 | Aşağıda ayrıntılı |

## Claude'un yaptıkları

- Kura listesinde numaramın görünmemesi üzerine listeyi inceleyip #37'nin büyük ihtimalle bana ait olduğu çıkarımını yaptı (öğretim elemanına teyit için yazdım).
- Veri kaynağı araştırması: KCC verisinin Hugging Face kopyasını (`Vrushali/MH`) ve Open-Meteo'yu önerdi.
- Repo iskeletini ve şu dosyaların ilk taslağını yazdı: `SCENARIO.md`, `data/README.md` (veri kartı şablonu), `scripts/01–04` Python betikleri, `sql/hafta-04.sql`, `sql/hafta-05.sql` ve bu dosyanın taslağı.
- SQL sorgularını ve betikleri önce yapay bir deneme verisiyle kendi ortamında PostgreSQL 16 üzerinde test etti (bu deneme verisi repoda **yoktur**).
- Benim onayımla bilgisayarıma bağlanarak betikleri bilgisayarımda çalıştırdı; ilk denemede API hatası çıkınca indirme betiğini Parquet dosyalarını indirecek şekilde değiştirdi.
- Temizlenmiş gerçek veriyi PostgreSQL'e yükleyip Hafta 4 ve 5 sorgularını çalıştırdı; veri kartındaki sayıları ve her sorgunun "Sonuç" yorumunun taslağını bu çıktılardan yazdı.

## Benim yaptıklarım

- Kura numarası konusunu öğretim elemanına sordum.
- Sorguları kendi PostgreSQL'imde çalıştırıp sonuçları ve yorumları kontrol ettim.
- Repoyu GitHub'da açtım, commit'leri ve PR'ı kendim oluşturdum.
- [Kendi değiştirdiğin / eklediğin bir şey varsa buraya yaz; yoksa bu satırı sil.]

## Veride yapay zekâ kullanımı

Veri setinde dil modeliyle üretilmiş satır ya da değer **yoktur**. `responses` tablosundaki `source_chunk_count`, `generation_ms` ve `top_similarity` sütunları, `scripts/04_rag_yanitlari.py` ile yerelde çalıştırılan TF-IDF getirme adımıyla ölçülmüştür (bkz. `data/README.md`, bölüm 4).
