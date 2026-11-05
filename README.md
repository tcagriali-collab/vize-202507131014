# vize-202507131014

Veritabanı Yönetim Sistemleri (PostgreSQL), Güz 2026 · Vize (Hafta 3–5)
**Kura #37 · Tarım × RAG bilgi asistanı × Anomali tespiti**

Veri: Nashik (Maharashtra, Hindistan), 2018, 23.843 çiftçi sorusu + günlük hava.

Ana soru: Soru trafiğinde normal dışı artışlar hangi konuda ve hangi hafta yoğunlaşıyor? Bu artışlar mevsimsel hava değişiklikleriyle uyuşuyor mu?

## Klasörler

| Yol | İçerik | Hafta |
|---|---|---|
| `SCENARIO.md` | Problem, hedef kullanıcı, tablo adayları, YZ bileşeni, veri kaynakları | 3 |
| `data/raw/` | Ham veri (hiç elle değiştirilmez) | 4 |
| `data/clean/` | Temizlenmiş CSV'ler ve temizleme raporu | 4 |
| `data/README.md` | Veri kartı | 4 |
| `sql/hafta-04.sql` | Yükleme ve ilk SELECT sorguları | 4 |
| `sql/hafta-05.sql` | Beş analiz sorgusu | 5 |
| `scripts/` | İndirme, temizleme ve RAG getirme betikleri | 4 |
| `AI_BEYAN.md` | Yapay zekâ kullanım beyanı | — |

## Yeniden üretmek için

```bash
pip install pandas pyarrow scikit-learn
python scripts/01_indir_kcc.py            # ilçe NASIK, yıl otomatik (2018)
python scripts/02_indir_hava.py           # yıl, KCC indirme kaydından
python scripts/03_temizle.py --kcc data/raw/kcc_nasik_2018.csv --hava data/raw/openmeteo_2018.json
python scripts/04_rag_yanitlari.py

createdb vize
psql -d vize -f sql/hafta-04.sql
psql -d vize -f sql/hafta-05.sql
```

## Kaynaklar

- Kisan Call Centre (KCC) farmer queries, data.gov.in (GODL-India), Hugging Face kopyası `Vrushali/MH`
- Weather data by Open-Meteo.com (CC BY 4.0)
