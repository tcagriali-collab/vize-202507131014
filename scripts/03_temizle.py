"""
Ham veriyi okur, temizler ve data/clean/ altına yazar.
data/raw/ altındaki dosyalara DOKUNMAZ (yalnızca okur).

Kullanım:
    python scripts/03_temizle.py --kcc data/raw/kcc_nashik_2019.csv --hava data/raw/openmeteo_2019.json

Çıktı:
    data/clean/questions.csv
    data/clean/weather_daily.csv
    data/clean/temizleme_raporu.json   -> veri kartına yazılacak sayılar burada
"""
import argparse
import json
from pathlib import Path

import pandas as pd

# Aynı anlama gelen konu adlarını tek ada indirir. Yalnızca açık eşanlamlılar
# birleştirilir; yeni bir eşanlamlı görürsen buraya ekle ve veri kartına yaz.
KONU_BIRLESTIR = {
    "seeds and planting material": "seeds",
    "seed": "seeds",
    "fertilizer use & availability": "fertilizer use and availability",
    "plant protection.": "plant protection",
    "govt schemes": "government schemes",
    "government scheme": "government schemes",
    "weather forecast": "weather",
}

# KCC'de "yanıt yok" yerine yazılmış yer tutucular
BOS_YANIT = {"", "0", "na", "n/a", "nan", "none", "null", "-", "--", "."}


def konu_normalle(s):
    if pd.isna(s):
        return None
    t = " ".join(str(s).split()).strip().lower()  # fazla boşluk, sekme, büyük/küçük harf
    if t in ("", "0", "nan"):
        return None
    t = KONU_BIRLESTIR.get(t, t)
    return t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kcc", required=True)
    ap.add_argument("--hava", required=True)
    a = ap.parse_args()

    out = Path("data/clean")
    out.mkdir(parents=True, exist_ok=True)
    rapor = {}

    # ---------------- KCC soruları ----------------
    ham = pd.read_csv(a.kcc, dtype=str, keep_default_na=False)
    rapor["ham_satir"] = len(ham)
    rapor["ham_kolon"] = len(ham.columns)
    rapor["ham_bos_hucre"] = {c: int((ham[c].str.strip() == "").sum()) for c in ham.columns}

    df = ham.copy()
    # Tarih: Year/Month/Day ayrı tamsayı kolonlar; saat bilgisi YOK.
    tarih = pd.to_datetime(
        dict(year=pd.to_numeric(df["Year"], errors="coerce"),
             month=pd.to_numeric(df["Month"], errors="coerce"),
             day=pd.to_numeric(df["Day"], errors="coerce")),
        errors="coerce",
    )
    rapor["gecersiz_tarih"] = int(tarih.isna().sum())

    konu_ham = df["QueryType"].where(df["QueryType"].str.strip() != "", None)
    konu = konu_ham.map(konu_normalle)
    rapor["konu_farkli_ham_yazim"] = int(konu_ham.dropna().nunique())
    rapor["konu_farkli_temiz"] = int(konu.dropna().nunique())
    rapor["konu_bos"] = int(konu.isna().sum())

    soru = df["QueryText"].str.strip()
    soru = soru.where(soru != "", None)
    rapor["soru_metni_bos"] = int(soru.isna().sum())

    yanit = df["KccAns"].str.strip()
    yanit_bos = yanit.str.lower().isin(BOS_YANIT)
    rapor["yanit_bos_ya_da_yer_tutucu"] = int(yanit_bos.sum())

    rapor["tam_tekrar_satir"] = int(df.drop(columns=[df.columns[0]]).duplicated().sum())

    questions = pd.DataFrame({
        "id": range(1, len(df) + 1),
        "source_row": df[df.columns[0]],
        "topic": konu,
        "topic_raw": konu_ham,
        "asked_at": tarih.dt.strftime("%Y-%m-%d"),
        "channel": "phone",  # KCC bir telefon hattıdır; tüm kayıtlar aynı kanaldan gelir
        "sector": df["Sector"].str.strip().str.lower().replace("", None),
        "crop": df["Crop"].str.strip().replace("", None),
        "question_length": soru.str.len().astype("Int64"),
        "query_text": soru,
        "answer_text": yanit.where(~yanit_bos, None),
    })
    # Tekrarlı satırlar SİLİNMEZ: KCC'de aynı gün aynı soruyu soran iki farklı
    # çiftçi olabilir. Sayısı rapora yazılır.
    questions.to_csv(out / "questions.csv", index=False)
    rapor["questions_satir"] = len(questions)
    rapor["konular"] = questions["topic"].fillna("(konu yok)").value_counts().head(25).to_dict()
    rapor["konular"] = {str(k): int(v) for k, v in rapor["konular"].items()}
    rapor["tarih_araligi"] = [questions["asked_at"].min(), questions["asked_at"].max()]

    # ---------------- Hava ----------------
    with open(a.hava, encoding="utf-8") as f:
        h = json.load(f)
    d = h["daily"]
    hava = pd.DataFrame({
        "date": d["time"],
        "avg_temp_c": d["temperature_2m_mean"],
        "precipitation_mm": d["precipitation_sum"],
    })
    rapor["hava_gun"] = len(hava)
    rapor["hava_bos_sicaklik"] = int(hava["avg_temp_c"].isna().sum())
    rapor["hava_bos_yagis"] = int(hava["precipitation_mm"].isna().sum())
    rapor["hava_negatif_yagis"] = int((hava["precipitation_mm"] < 0).sum())
    hava.loc[hava["precipitation_mm"] < 0, "precipitation_mm"] = None
    rapor["hava_konum"] = {"enlem": h.get("latitude"), "boylam": h.get("longitude"),
                           "saat_dilimi": h.get("timezone")}
    hava.to_csv(out / "weather_daily.csv", index=False)

    with open(out / "temizleme_raporu.json", "w", encoding="utf-8") as f:
        json.dump(rapor, f, ensure_ascii=False, indent=2)
    print(json.dumps(rapor, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
