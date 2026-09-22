-- ============================================================
-- Fed a rynki: pieniądz, stopy realne, zwroty S&P500
-- Baza: data/fed_cycles.db (SQLite), budowana notebookami 01-02
-- Zakres danych: 1990-01 do 2026-09, 441 obserwacji miesięcznych
-- Pytania o to, czy polityka Fed przekłada się na rynek.
-- ============================================================

-- 1. Wzrost M2 przed recesją i poza nią
-- PYTANIE: Czy przyspieszenie podaży pieniądza poprzedza recesje?
-- WNIOSEK: Odwrotnie niż mówi popularna teza. Najwyższy wzrost M2 wypada PODCZAS recesji
--          (8,93% wobec 5,50% w spokojnych czasach) - to reakcja Fed na kryzys, nie jego
--          zapowiedź. W 6 miesięcy przed recesją 6,65%, czyli tylko nieco powyżej normy.
--          Przyczyna i skutek są tu odwrócone w czasie.

WITH m2_growth AS (
    SELECT
        ym,
        m2sl,
        usrec,
        LAG(m2sl, 12) OVER (ORDER BY ym) AS m2sl_12m_ago,
        LEAD(usrec, 6) OVER (ORDER BY ym) AS recession_in_6m
    FROM v_master
    WHERE m2sl IS NOT NULL AND usrec IS NOT NULL
)
SELECT
    CASE
        WHEN recession_in_6m = 1 THEN 'Przed recesją (6m wcześniej)'
        WHEN usrec = 1           THEN 'Podczas recesji'
        ELSE                          'Normalny wzrost'
    END AS okres,
    COUNT(*) AS n_miesiecy,
    ROUND(AVG((m2sl - m2sl_12m_ago) / m2sl_12m_ago * 100), 2) AS sredni_wzrost_M2_pct
FROM m2_growth
WHERE m2sl_12m_ago IS NOT NULL AND recession_in_6m IS NOT NULL
GROUP BY 1
ORDER BY sredni_wzrost_M2_pct DESC;

-- 2. Realna stopa Fed per dekada
-- PYTANIE: Czy pieniądz był darmowy i kiedy?
-- WNIOSEK: Zmiana reżimu, nie epizod: +2,08 pp w latach 90., +0,38 w 2000s, -1,16 w 2010s
--          i -1,11 w 2020s. Dwie dekady z rzędu z ujemną realną stopą.
--          UWAGA: dekada 2020s to 6 lat danych, nie 10 - średnia nie jest wprost
--          porównywalna z pozostałymi.

WITH cpi_growth AS (
    SELECT
        ym,
        fedfunds,
        cpiaucsl,
        LAG(cpiaucsl, 12) OVER (ORDER BY ym) AS cpi_12m_ago
    FROM v_master
    WHERE fedfunds IS NOT NULL AND cpiaucsl IS NOT NULL
)
SELECT
    substr(ym, 1, 3) || '0s' AS dekada,
    ROUND(AVG(fedfunds), 2)  AS avg_stopa_fed,
    ROUND(AVG((cpiaucsl - cpi_12m_ago) / cpi_12m_ago * 100), 2) AS avg_inflacja_pct,
    ROUND(AVG(fedfunds - (cpiaucsl - cpi_12m_ago) / cpi_12m_ago * 100), 2) AS avg_realna_stopa
FROM cpi_growth
WHERE cpi_12m_ago IS NOT NULL
GROUP BY dekada
ORDER BY dekada;

-- 3. Zwrot S&P500 po decyzji Fed
-- PYTANIE: Czy obniżka stóp napędza giełdę w kolejnych 12 miesiącach?
-- WNIOSEK: Nie. Obniżki wypadają NAJGORZEJ: 7,7% średniego zwrotu 12-miesięcznego, wobec
--          11,7% po podwyżkach i 11,2% przy braku zmian. Mechanizm jest odwrotny do intuicji:
--          Fed obniża, gdy gospodarka słabnie, więc obniżka jest objawem problemu,
--          a nie prezentem dla rynku.
--          Ten wynik liczy się na 427 miesiącach. Wcześniej w bazie siedziała 10-letnia seria
--          S&P500 z FRED i to samo zapytanie dawało 112 miesięcy oraz odwrotną kolejność
--          reżimów - dobra ilustracja tego, jak zakres danych potrafi odwrócić wniosek.

WITH fed_changes AS (
    SELECT
        ym,
        fedfunds,
        LAG(fedfunds) OVER (ORDER BY ym) AS prev_fedfunds,
        sp500,
        LEAD(sp500, 12) OVER (ORDER BY ym) AS sp500_12m_later
    FROM v_master
    WHERE fedfunds IS NOT NULL AND sp500 IS NOT NULL
)
SELECT
    CASE
        WHEN fedfunds < prev_fedfunds THEN 'Obniżka stóp'
        WHEN fedfunds > prev_fedfunds THEN 'Podwyżka stóp'
        ELSE                               'Brak zmiany'
    END AS decyzja_fed,
    COUNT(*) AS n_miesiecy,
    ROUND(AVG((sp500_12m_later - sp500) / sp500 * 100), 1) AS avg_zwrot_sp500_12m_pct
FROM fed_changes
WHERE prev_fedfunds IS NOT NULL AND sp500_12m_later IS NOT NULL
GROUP BY 1
ORDER BY avg_zwrot_sp500_12m_pct DESC;

-- 4. Spadek S&P500 wewnątrz recesji
-- PYTANIE: Ile rynek tracił między szczytem a dołkiem każdej recesji?
-- WNIOSEK: GFC odstaje: -48,8% wobec -17,5% (Gulf War), -17,8% (Dot-com) i -19,1% (COVID).
--          Trzy z czterech recesji to spadek rzędu 18%, jedna to połowa wartości indeksu.
--          UWAGA 1: to zasięg WEWNĄTRZ okna NBER, nie maksymalne obsunięcie liczone od
--          szczytu poprzedzającego recesję. Dno S&P500 po GFC wypadło w marcu 2009, czyli
--          jeszcze w oknie, ale szczyt z października 2007 już poza nim.
--          UWAGA 2: v_master trzyma średnie miesięczne, więc każdy spadek jest tu
--          wygładzony. COVID: średnia marca 2020 to 2652, a dzienne minimum było
--          o kilkanaście procent niżej. Te liczby zaniżają faktyczne obsunięcia.

WITH rec_periods AS (
    SELECT name, start, end FROM dim_recession
),
sp_during AS (
    SELECT
        r.name,
        r.start,
        r.end,
        MAX(m.sp500) AS sp500_peak,
        MIN(m.sp500) AS sp500_trough
    FROM rec_periods r
    JOIN v_master m
        ON m.ym BETWEEN strftime('%Y-%m', r.start) AND strftime('%Y-%m', r.end)
    WHERE m.sp500 IS NOT NULL
    GROUP BY r.name, r.start, r.end
)
SELECT
    name AS recesja,
    start || ' → ' || end AS okres,
    ROUND(sp500_peak, 0)  AS sp500_szczyt,
    ROUND(sp500_trough, 0) AS sp500_dolek,
    ROUND((sp500_trough - sp500_peak) / sp500_peak * 100, 1) AS drawdown_pct
FROM sp_during
ORDER BY start;

-- 5. Aktualny stan wskaźników
-- PYTANIE: Gdzie jesteśmy teraz i czy coś się świeci?
-- WNIOSEK: Sierpień 2026: stopa 3,63%, krzywa dodatnia (+0,47), bezrobocie 4,1%,
--          M2 YoY +5,4%, realna stopa +0,28 pp. Żaden warunek ostrzegawczy nie jest spełniony.
--          M2 YoY dla najnowszego miesiąca jest puste - M2 publikowane jest z największym
--          opóźnieniem ze wszystkich serii w tej bazie. To ograniczenie źródła, nie błąd.

WITH recent AS (
    SELECT *
    FROM v_master
    WHERE fedfunds IS NOT NULL
    ORDER BY ym DESC
    LIMIT 6
),
m2_calc AS (
    SELECT
        r.ym,
        r.fedfunds,
        r.t10y2y,
        r.unrate,
        r.m2sl,
        r.cpiaucsl,
        r.sp500,
        h.m2sl AS m2sl_12m_ago,
        h.cpiaucsl AS cpi_12m_ago
    FROM recent r
    LEFT JOIN v_master h
        ON h.ym = strftime('%Y-%m', date(r.ym || '-01', '-12 months'))
)
SELECT
    ym AS miesiac,
    ROUND(fedfunds, 2)                                           AS stopa_fed,
    ROUND(t10y2y, 3)                                            AS yield_curve,
    ROUND(unrate, 1)                                            AS bezrobocie,
    ROUND((m2sl - m2sl_12m_ago) / m2sl_12m_ago * 100, 1)      AS m2_yoy_pct,
    ROUND(fedfunds - (cpiaucsl - cpi_12m_ago)
          / cpi_12m_ago * 100, 2)                               AS realna_stopa,
    ROUND(sp500, 0)                                             AS sp500,
    CASE WHEN t10y2y < 0 THEN '⚠️' ELSE '✅' END               AS yield_ok,
    CASE WHEN (m2sl - m2sl_12m_ago) / m2sl_12m_ago * 100 < 0
         THEN '⚠️' ELSE '✅' END                                AS m2_ok
FROM m2_calc
WHERE m2sl_12m_ago IS NOT NULL
ORDER BY miesiac DESC;
