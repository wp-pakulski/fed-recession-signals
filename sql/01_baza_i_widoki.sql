-- ============================================================
-- Model danych: tabele, indeksy i widok v_master
-- Baza: data/fed_cycles.db (SQLite), budowana notebookami 01-02
-- Zakres danych: 1990-01 do 2026-09, 441 obserwacji miesięcznych
-- Ten plik dokumentuje schemat, który notebooki tworzą w Pythonie.
-- ============================================================

-- Dane trzymane są w formacie długim: jeden wiersz to jedna wartość jednej serii
-- w jednym dniu. 17 serii o różnej częstotliwości (dzienne, miesięczne, kwartalne)
-- w jednej tabeli, bez kolumny na każdą serię.

CREATE TABLE "raw_series" (
"date" TEXT,
  "value" REAL,
  "series_id" TEXT
);

CREATE INDEX idx_raw_date ON raw_series(date);
CREATE INDEX idx_raw_series ON raw_series(series_id);

-- Recesje wg NBER: start = miesiąc szczytu, end = miesiąc dołka.
-- Cztery recesje w zakresie danych. Recesja 1990-1991 była tu długo pominięta,
-- mimo że siedzi w serii USREC - skutkiem było liczenie Q4, Q7 i Q9 na trzech z czterech.

CREATE TABLE "dim_recession" (
"recession_id" INTEGER,
  "name" TEXT,
  "start" TEXT,
  "end" TEXT,
  "cause" TEXT
);

INSERT INTO dim_recession VALUES (1, 'Gulf War', '1990-07-01', '1991-03-01', 'Szok naftowy po inwazji na Kuwejt i zacieśnienie Fed');
INSERT INTO dim_recession VALUES (2, 'Dot-com', '2001-03-01', '2001-11-01', 'Pęknięcie bańki technologicznej');
INSERT INTO dim_recession VALUES (3, 'GFC', '2007-12-01', '2009-06-01', 'Kryzys finansowy - rynek nieruchomości');
INSERT INTO dim_recession VALUES (4, 'COVID', '2020-02-01', '2020-04-01', 'Pandemia COVID-19');

-- ------------------------------------------------------------
-- Widok v_master: format długi na szeroki, wszystko na osi miesięcznej
-- ------------------------------------------------------------
-- PYTANIE: jak połączyć 17 serii o różnej częstotliwości w jedną tabelę analityczną?
-- DECYZJA: CTE `monthly` uśrednia każdy miesiąc (dla serii dziennych jak T10Y2Y
--          czy spread HY to średnia miesięczna), a MAX(CASE WHEN ...) obraca format
--          długi na szeroki. Jedna kolumna na serię, jeden wiersz na miesiąc.
-- UWAGA:   średnia miesięczna wygładza ekstrema dzienne. Inwersja krzywej trwająca
--          dwa tygodnie może nie pojawić się w tym widoku wcale.

DROP VIEW IF EXISTS v_master;

CREATE VIEW v_master AS
WITH monthly AS (
    SELECT
        strftime('%Y-%m', date) AS ym,
        series_id,
        AVG(value) AS value
    FROM raw_series
    GROUP BY ym, series_id
)
SELECT
    ym,
    MAX(CASE WHEN series_id = 'FEDFUNDS'       THEN value END) AS fedfunds,
    MAX(CASE WHEN series_id = 'M2SL'           THEN value END) AS m2sl,
    MAX(CASE WHEN series_id = 'SP500'          THEN value END) AS sp500,
    MAX(CASE WHEN series_id = 'T10Y2Y'        THEN value END) AS t10y2y,
    MAX(CASE WHEN series_id = 'USREC'         THEN value END) AS usrec,
    MAX(CASE WHEN series_id = 'UNRATE'        THEN value END) AS unrate,
    MAX(CASE WHEN series_id = 'GDPC1'         THEN value END) AS gdpc1,
    MAX(CASE WHEN series_id = 'CPIAUCSL'      THEN value END) AS cpiaucsl,
    MAX(CASE WHEN series_id = 'ICSA'          THEN value END) AS icsa,
    MAX(CASE WHEN series_id = 'PAYEMS'        THEN value END) AS payems,
    MAX(CASE WHEN series_id = 'INDPRO'        THEN value END) AS indpro,
    MAX(CASE WHEN series_id = 'RSXFS'         THEN value END) AS rsxfs,
    MAX(CASE WHEN series_id = 'PERMIT'        THEN value END) AS permit,
    MAX(CASE WHEN series_id = 'BAMLH0A0HYM2'  THEN value END) AS hy_spread,
    MAX(CASE WHEN series_id = 'DRTSCILM'      THEN value END) AS credit_cond,
    MAX(CASE WHEN series_id = 'USSLIND'       THEN value END) AS lei,
    MAX(CASE WHEN series_id = 'VIX'           THEN value END) AS vix
FROM monthly
GROUP BY ym
ORDER BY ym;

-- ------------------------------------------------------------
-- Kontrola po przebudowie bazy
-- ------------------------------------------------------------

-- 17 serii, 24 315 wierszy łącznie
SELECT series_id, COUNT(*) AS n, MIN(date) AS od, MAX(date) AS do
FROM raw_series
GROUP BY series_id
ORDER BY series_id;

-- v_master: 441 wierszy, sp500 wypełniony we wszystkich
-- (jeśli sp500 ma ~120 wartości, to znaczy że do bazy trafiła 10-letnia seria z FRED
--  zamiast pełnej historii z Yahoo Finance - patrz notebook 01)
SELECT COUNT(*) AS miesiecy, COUNT(sp500) AS z_sp500, MIN(ym) AS od, MAX(ym) AS do
FROM v_master;

-- żaden (date, series_id) nie może się powtarzać
SELECT date, series_id, COUNT(*) AS n
FROM raw_series
GROUP BY date, series_id
HAVING n > 1;
