"""
Open-Meteo Historical Weather API'den günlük sıcaklık ve yağış verisini indirir (ham veri).
API anahtarı gerekmez. Lisans: CC BY 4.0 (open-meteo.com).

Konum, soruların geldiği ilçe ile AYNI olmalıdır; aksi halde hava ile soru
trafiği arasında kurulan ilişkinin anlamı kalmaz.
Varsayılan: Nashik, Maharashtra (19.9975 K, 73.7898 D).

Kullanım:
    python scripts/02_indir_hava.py            # yıl KCC kaydından
    python scripts/02_indir_hava.py --yil 2019 --enlem 18.52 --boylam 73.86   # Pune

Çıktı:
    data/raw/openmeteo_<yil>.json   -> API yanıtı olduğu gibi (ELLE DEĞİŞTİRİLMEZ)
"""
import argparse
import json
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

API = "https://archive-api.open-meteo.com/v1/archive"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--yil", type=int, default=None, help="verilmezse kcc_indirme_kaydi.json içindeki yıl kullanılır")
    ap.add_argument("--enlem", type=float, default=19.9975)
    ap.add_argument("--boylam", type=float, default=73.7898)
    a = ap.parse_args()
    if a.yil is None:
        a.yil = json.loads(Path("data/raw/kcc_indirme_kaydi.json").read_text(encoding="utf-8"))["yil"]
        print(f"Yıl KCC indirme kaydından alındı: {a.yil}")

    params = {
        "latitude": a.enlem,
        "longitude": a.boylam,
        "start_date": f"{a.yil}-01-01",
        "end_date": f"{a.yil}-12-31",
        "daily": "temperature_2m_mean,precipitation_sum",
        "timezone": "Asia/Kolkata",
    }
    url = API + "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=60) as r:
        veri = json.loads(r.read().decode("utf-8"))

    veri["_indirme"] = {
        "url": url,
        "indirme_zamani_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    raw = Path("data/raw")
    raw.mkdir(parents=True, exist_ok=True)
    cikti = raw / f"openmeteo_{a.yil}.json"
    with open(cikti, "w", encoding="utf-8") as f:
        json.dump(veri, f, ensure_ascii=False, indent=2)
    print(f"Yazıldı: {cikti} ({len(veri['daily']['time'])} gün)")


if __name__ == "__main__":
    main()
