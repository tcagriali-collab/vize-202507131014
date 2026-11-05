"""
Kisan Call Centre (KCC) çiftçi sorularını indirir (ham veri).

Kaynak: Hugging Face'teki "Vrushali/MH" veri seti (Maharashtra eyaleti KCC kayıtları,
3,3 milyon satır). Asıl veri sahibi: Hindistan Tarım ve Çiftçi Refahı Bakanlığı,
data.gov.in (Government Open Data License - India, GODL).

Yöntem: Veri setinin Parquet dosyaları (yaklaşık 135 MB) bir kez indirilir,
bilgisayarda tek ilçe ve tek yıl süzülür. (Satır satır API ile indirmek çok yavaş.)
Parquet dosyaları data/raw/_parquet/ altına iner; boyutları büyük olduğu için
.gitignore ile repoya konmaz. Repoya giren ham dosya süzülmüş CSV'dir.

Kullanım (repo kök klasöründen):
    pip install pandas pyarrow
    python scripts/01_indir_kcc.py                 # ilçe NASIK, yıl otomatik
    python scripts/01_indir_kcc.py --ilce PUNE --yil 2017

--yil verilmezse, ilçenin en az 2000 kaydı olan EN SON yılı seçilir.

Çıktı:
    data/raw/kcc_<ilce>_<yil>.csv     -> ham veri (süzülmüş), ELLE DEĞİŞTİRİLMEZ
    data/raw/kcc_indirme_kaydi.json   -> indirme tarihi, kaynak, satır sayıları, seçilen yıl
"""
import argparse
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

DATASET = "Vrushali/MH"
PARQUET_API = f"https://datasets-server.huggingface.co/parquet?dataset={DATASET}"
UA = {"User-Agent": "dbms-odev-script"}


def indir(url, hedef: Path):
    if hedef.exists() and hedef.stat().st_size > 0:
        print(f"  zaten var: {hedef.name}")
        return
    tmp = hedef.with_suffix(".part")
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r, open(tmp, "wb") as f:
        toplam = int(r.headers.get("Content-Length", 0))
        gelen = 0
        while True:
            parca = r.read(1 << 20)
            if not parca:
                break
            f.write(parca)
            gelen += len(parca)
            if toplam:
                print(f"\r  {hedef.name}: {gelen/1e6:.0f}/{toplam/1e6:.0f} MB", end="", flush=True)
    print()
    tmp.replace(hedef)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ilce", default="NASIK", help="DistrictName (veride Nashik 'NASIK' yazılır)")
    ap.add_argument("--yil", type=int, default=None)
    a = ap.parse_args()

    raw = Path("data/raw")
    pq_dir = raw / "_parquet"
    pq_dir.mkdir(parents=True, exist_ok=True)

    with urllib.request.urlopen(urllib.request.Request(PARQUET_API, headers=UA), timeout=60) as r:
        liste = json.loads(r.read())["parquet_files"]
    dosyalar = []
    for p in liste:
        if p.get("split") != "train":
            continue
        hedef = pq_dir / p["filename"]
        print(f"İndiriliyor: {p['filename']} ({p.get('size', 0)/1e6:.0f} MB)")
        indir(p["url"], hedef)
        dosyalar.append(hedef)

    kolonlar = None
    parcalar = []
    for d in dosyalar:
        df = pd.read_parquet(d)
        kolonlar = list(df.columns)
        parcalar.append(df[df["DistrictName"].astype(str).str.strip().str.upper() == a.ilce.upper()])
    ilce = pd.concat(parcalar, ignore_index=True)
    if ilce.empty:
        raise SystemExit(f"'{a.ilce}' ilçesi bulunamadı.")

    yil_sayim = ilce["Year"].value_counts().sort_index()
    print("\nİlçedeki yıl dağılımı:\n" + yil_sayim.to_string())
    yil = a.yil
    if yil is None:
        uygun = yil_sayim[yil_sayim >= 2000]
        yil = int(uygun.index.max()) if len(uygun) else int(yil_sayim.idxmax())
    secili = ilce[ilce["Year"] == yil].sort_values("Unnamed: 0")
    print(f"\nSeçilen yıl: {yil} -> {len(secili)} satır")

    cikti = raw / f"kcc_{a.ilce.lower()}_{yil}.csv"
    secili.to_csv(cikti, index=False, encoding="utf-8")

    kayit = {
        "kaynak": f"https://huggingface.co/datasets/{DATASET}",
        "asil_kaynak": "data.gov.in - Kisan Call Centre (KCC) farmer queries (GODL-India)",
        "yontem": "Parquet dosyalari indirildi, ilce ve yil yerelde suzuldu",
        "parquet_dosyalari": [p["url"] for p in liste if p.get("split") == "train"],
        "ilce": a.ilce, "yil": yil,
        "ilcedeki_toplam_satir": int(len(ilce)),
        "ilce_yil_dagilimi": {int(k): int(v) for k, v in yil_sayim.items()},
        "indirilen_satir": int(len(secili)),
        "kolonlar": kolonlar,
        "indirme_zamani_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "dosya": str(cikti).replace("\\", "/"),
    }
    with open(raw / "kcc_indirme_kaydi.json", "w", encoding="utf-8") as f:
        json.dump(kayit, f, ensure_ascii=False, indent=2)
    print(f"Yazıldı: {cikti}")


if __name__ == "__main__":
    main()
