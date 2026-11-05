"""
RAG asistanının "getirme" (retrieval) adımını yerelde çalıştırır ve responses tablosunu üretir.

Neden: KCC verisinde soru ve uzman yanıtı var, ama RAG ölçümleri (kaç kaynak parça
bulundu, ne kadar sürdü) yok. Bu ölçümler UYDURULMAZ; gerçekten çalışan basit bir
TF-IDF getirme adımıyla ÖLÇÜLÜR. Bu yüzden bu sütunlar "türetilmiş" (derived) olarak
veri kartına yazılır; dil modeliyle üretilmiş satır yoktur.

Bilgi tabanı (kılavuz parçaları): KCC uzmanlarının yazdığı, boş olmayan yanıtlar.
Her farklı yanıt metni bir parça (chunk) sayılır.
Kendi yanıtını bulmasın diye her soru için o satırın kendi yanıt metni dışarıda tutulur
(leave-one-out).

Kullanım:
    pip install pandas scikit-learn
    python scripts/04_rag_yanitlari.py

Çıktı:
    data/clean/responses.csv
    data/clean/rag_ayarlari.json
"""
import json
import time
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer

ESIK = 0.30   # bir parçanın "ilgili" sayılması için gereken en düşük kosinüs benzerliği
TOP_K = 5     # en fazla getirilecek parça sayısı


def main():
    q = pd.read_csv("data/clean/questions.csv", dtype={"answer_text": str, "query_text": str})

    parcalar = q["answer_text"].dropna().drop_duplicates().reset_index(drop=True)
    parca_index = {t: i for i, t in enumerate(parcalar)}
    vek = TfidfVectorizer(lowercase=True, ngram_range=(1, 2), min_df=1, sublinear_tf=True)
    X = vek.fit_transform(parcalar)  # parça x kelime

    kayitlar = []
    for row in q.itertuples(index=False):
        t0 = time.perf_counter()
        if isinstance(row.query_text, str) and row.query_text.strip():
            v = vek.transform([row.query_text])
            sims = (X @ v.T).toarray().ravel()
            if isinstance(row.answer_text, str) and row.answer_text in parca_index:
                sims[parca_index[row.answer_text]] = -1.0  # kendi yanıtını dışla
            enust = np.sort(sims)[::-1][:TOP_K]
            sayi = int((enust >= ESIK).sum())
            en_iyi = float(max(enust[0], 0.0)) if len(enust) else 0.0
        else:
            sayi, en_iyi = 0, None  # soru metni yoksa getirme yapılamaz
        ms = (time.perf_counter() - t0) * 1000
        kayitlar.append({
            "id": row.id,
            "question_id": row.id,
            "source_chunk_count": sayi,
            "generation_ms": round(ms, 3),
            # is_empty KCC'nin kendi yanıt alanından gelir (gerçek veri);
            # source_chunk_count ise bizim getirme adımımızdan. İkisi çelişebilir.
            "is_empty": not (isinstance(row.answer_text, str) and row.answer_text.strip()),
            "top_similarity": None if en_iyi is None else round(en_iyi, 4),
        })

    r = pd.DataFrame(kayitlar)
    r.to_csv("data/clean/responses.csv", index=False)
    ayar = {
        "yontem": "TF-IDF (1-2 gram, sublinear_tf) + kosinüs benzerliği, leave-one-out",
        "esik": ESIK, "top_k": TOP_K,
        "parca_sayisi": int(len(parcalar)),
        "responses_satir": int(len(r)),
        "kaynak_parcasi_0_olan": int((r["source_chunk_count"] == 0).sum()),
        "is_empty_true": int(r["is_empty"].sum()),
        "generation_ms_medyan": float(r["generation_ms"].median()),
        "not": "generation_ms, yerel bilgisayarda getirme adımının ölçülen süresidir; "
               "dil modeli yanıt üretim süresi değildir.",
    }
    Path("data/clean/rag_ayarlari.json").write_text(json.dumps(ayar, ensure_ascii=False, indent=2),
                                                    encoding="utf-8")
    print(json.dumps(ayar, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
