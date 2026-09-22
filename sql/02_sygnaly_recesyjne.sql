-- ============================================================
-- Sygnały recesyjne: krzywa dochodowości, bezrobocie, recesje
-- Baza: data/fed_cycles.db (SQLite), budowana notebookami 01-02
-- Zakres danych: 1990-01 do 2026-09, 441 obserwacji miesięcznych
-- Pytania o to, co i jak długo wyprzedza recesje.
-- ============================================================

-- 1. Miesiące z odwróconą krzywą dochodowości
-- PYTANIE: Kiedy spread 10Y-2Y był ujemny i jaka była wtedy stopa Fed?
-- WNIOSEK: 52 miesiące z inwersją w całej historii, w siedmiu epizodach. Najdłuższy to
--          lipiec 2022 - sierpień 2024 (26 miesięcy, połowa wszystkich) i jako jedyny NIE
--          skończył się recesją. Był też najgłębszy: -0,93 pp wobec -0,41 (2000)
--          i -0,15 (2006-2007). Głębokość i długość nie przełożyły się na recesję.

SELECT
    ym,
    ROUND(t10y2y, 3) AS yield_spread,
    ROUND(fedfunds, 2) AS stopa_fed,
    CASE WHEN usrec = 1 THEN 'RECESJA' ELSE '' END AS recesja
FROM v_master
WHERE t10y2y < 0
ORDER BY ym;

-- 2. Epizody inwersji i recesja w ciągu 36 miesięcy
-- PYTANIE: Ile razy krzywa się odwracała i czy za każdym razem przyszła recesja?
-- WNIOSEK: Siedem epizodów. Te dłuższe poprzedzają recesje z wyprzedzeniem 13-22 miesięcy,
--          a jednomiesięczne blipy (1998-06, 2007-05) łapią recesję przypadkiem: 1998-06
--          dostaje recesję z 2001, czyli 34 miesiące później, co nie jest sygnałem,
--          tylko artefaktem szerokości okna.
--          Epizod z 2022-07 (26 miesięcy) nie ma po sobie żadnej recesji.
--          Technika: gaps and islands - różnica dwóch numeracji jest stała w obrębie ciągu.
--          Ta wersja nie scala epizodów oddzielonych przerwą: 2006-02, 2006-06 i 2007-05 to tu
--          trzy epizody, a notebook 05 liczy je jako jedną inwersję przed GFC (23 miesiące).
--          Scalanie jest trywialne w Pythonie i tam właśnie siedzi.

WITH ponumerowane AS (
    SELECT ym, t10y2y, ROW_NUMBER() OVER (ORDER BY ym) AS nr
    FROM v_master
    WHERE t10y2y IS NOT NULL
),
ujemne AS (
    SELECT ym, nr - ROW_NUMBER() OVER (ORDER BY ym) AS grupa
    FROM ponumerowane
    WHERE t10y2y < 0
),
epizody AS (
    SELECT MIN(ym) AS start_inwersji, MAX(ym) AS koniec_inwersji, COUNT(*) AS dlugosc_mies
    FROM ujemne
    GROUP BY grupa
),
starty_recesji AS (
    SELECT ym FROM (
        SELECT ym, usrec, LAG(usrec) OVER (ORDER BY ym) AS poprzedni
        FROM v_master
        WHERE usrec IS NOT NULL
    )
    WHERE usrec = 1 AND (poprzedni = 0 OR poprzedni IS NULL)
)
SELECT
    e.start_inwersji,
    e.koniec_inwersji,
    e.dlugosc_mies,
    MIN(r.ym) AS recesja_po,
    CAST((julianday(MIN(r.ym) || '-01') - julianday(e.start_inwersji || '-01')) / 30.44 AS INT)
        AS miesiecy_do_recesji
FROM epizody e
LEFT JOIN starty_recesji r
    ON r.ym > e.start_inwersji
    AND (julianday(r.ym || '-01') - julianday(e.start_inwersji || '-01')) / 30.44 <= 36
GROUP BY e.start_inwersji, e.koniec_inwersji, e.dlugosc_mies
ORDER BY e.start_inwersji;

-- 3. Sahm Rule jako sygnał ostrzegawczy
-- PYTANIE: Czy wzrost bezrobocia o 0,5 pp ponad minimum z 12 miesięcy wyprzedza recesję?
-- WNIOSEK: Nie wyprzedza. Recesja 1990 trwa od sierpnia 1990 do marca 1991, a sygnał Sahm
--          zapala się we WRZEŚNIU 1990 - w drugim miesiącu recesji, czyli po fakcie. Gaśnie
--          dopiero w październiku 1992, ponad rok po jej końcu. To wskaźnik potwierdzający,
--          nie wyprzedzający: bezrobocie rośnie najmocniej w trakcie i po recesji.
--          Progu 0,5 pp nie da się przestawić tak, żeby wyprzedzał - problem jest
--          w samej zmiennej, nie w kalibracji.
--          Okno ROWS BETWEEN 11 PRECEDING pokazuje, jak liczyc krocze w SQL bez self-joina.

WITH sahm AS (
    SELECT
        ym,
        unrate,
        usrec,
        MIN(unrate) OVER (ORDER BY ym ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS min_12m,
        AVG(unrate) OVER (ORDER BY ym ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)  AS avg_3m
    FROM v_master
    WHERE unrate IS NOT NULL AND usrec IS NOT NULL
)
SELECT
    ym,
    ROUND(unrate, 1)             AS bezrobocie,
    ROUND(avg_3m - min_12m, 2)  AS sahm_indicator,
    CASE WHEN avg_3m - min_12m >= 0.5 THEN 'SYGNAŁ' ELSE '' END AS sahm_signal,
    CASE WHEN usrec = 1 THEN 'RECESJA' ELSE '' END AS recesja
FROM sahm
WHERE avg_3m - min_12m >= 0.4  -- pokaż tylko miesiące bliskie sygnałowi
ORDER BY ym;

-- 4. Długość i przyczyna każdej recesji
-- PYTANIE: Jak długo trwały recesje w tym zakresie danych?
-- WNIOSEK: Od 2 miesięcy (COVID) do 18 (GFC). Mediana 8. COVID jest odstający w każdym
--          wymiarze: najkrótszy i jednocześnie najgłębszy spadek aktywności - dlatego
--          każdą średnią liczoną na czterech recesjach łącznie trzeba czytać ostrożnie.

SELECT
    r.name AS recesja,
    r.start,
    r.end,
    CAST((julianday(r.end) - julianday(r.start)) / 30 AS INT) AS dlugosc_miesiecy,
    r.cause AS przyczyna
FROM dim_recession r
ORDER BY r.start;

-- 5. Warunki makro rok przed każdą recesją
-- PYTANIE: Jak wyglądały wskaźniki 12 miesięcy przed szczytem cyklu?
-- WNIOSEK: Dot-com i GFC wyglądają podobnie: krzywa już odwrócona (-0,27 i -0,11), stopa Fed
--          powyżej 5%, bezrobocie przy 4%. COVID zupełnie inaczej: krzywa dodatnia (+0,17),
--          stopa 2,4% - bo to był szok zewnętrzny, nie koniec cyklu monetarnego. Żaden
--          zestaw progów kalibrowanych na cyklu nie złapałby COVID.
--          Gulf War nie ma tu wiersza: punkt pomiaru wypada w 1989-07, przed początkiem danych.
--          M2 YoY liczone w osobnym CTE na całym v_master. Policzone po joinie dawało pustą
--          kolumnę, bo trzy wiersze wynikowe nie mają dwunastu wierszy wstecz.

WITH m2_yoy AS (
    SELECT
        ym,
        (m2sl - LAG(m2sl, 12) OVER (ORDER BY ym)) / LAG(m2sl, 12) OVER (ORDER BY ym) * 100 AS m2_yoy_pct
    FROM v_master
),
pre_rec AS (
    SELECT
        r.name,
        strftime('%Y-%m', date(r.start, '-12 months')) AS ym_12m_before
    FROM dim_recession r
)
SELECT
    p.name AS recesja,
    p.ym_12m_before AS data_pomiaru,
    ROUND(m.fedfunds, 2) AS stopa_fed,
    ROUND(m.t10y2y, 3)  AS yield_curve,
    ROUND(m.unrate, 1)  AS bezrobocie,
    ROUND(g.m2_yoy_pct, 1) AS m2_yoy_pct
FROM pre_rec p
JOIN v_master m ON m.ym = p.ym_12m_before
JOIN m2_yoy   g ON g.ym = p.ym_12m_before
ORDER BY p.ym_12m_before;
