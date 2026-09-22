# Przegląd sygnałów recesyjnych

**Wygenerowano:** 2026-09-22  
**Werdykt: ✅ NISKIE ryzyko recesji**

Zapalone flagi: **0 z 8**, w tym alarmy: **0**

| Wskaźnik | Wartość | Flaga zapala się | Dane za | Sygnał |
|---|---|---|---|---|
| Yield curve 10Y-2Y (pp) | +0.40 | < +0.36 | 2026-09 | ✅ OK |
| Sahm Rule (pp) | +0.03 | > +0.30 | 2026-08 | ✅ OK |
| Zatrudnienie MoM (%) | +0.10 | < +0.03 | 2026-08 | ✅ OK |
| Produkcja przemysłowa YoY (%) | +1.08 | < -0.17 | 2026-07 | ✅ OK |
| Wnioski o zasiłek (tyg.) | 206 000 | > 461 600 | 2026-09 | ✅ OK |
| Spread kredytowy HY (pp) | +2.67 | > +8.08 | 2026-09 | ✅ OK |
| Sprzedaż detaliczna YoY (%) | +5.01 | < +2.99 | 2026-07 | ✅ OK |
| Pozwolenia budowlane YoY (%) | +2.36 | < -2.32 | 2026-07 | ✅ OK |

Progi wyznaczone na rozkładzie historycznym 1990-2026: UWAGA gdy wskaźnik
trafia w najgorsze 25% obserwacji, ALARM w najgorsze 10%.

## Backtest 1996-2026

| Reżim | Średnio flag | Maksimum | Miesięcy |
|---|---|---|---|
| 12 miesięcy przed recesją | **2.56** | 4 | 36 |
| w trakcie recesji | **5.46** | 7 | 28 |
| pozostałe miesiące | **1.51** | 7 | 291 |

Liczone tylko na miesiącach, w których wszystkie osiem wskaźników miało dane.
Ogranicza to backtest do okresu od grudnia 1996 i trzech recesji - spread HY
z indeksu ICE BofA zaczyna się dopiero wtedy.

Średnia separuje reżimy, maksimum już nie: spokojne miesiące też dochodzą
do 7 flag, a najwyższe odczyty wypadają **po** recesjach, nie przed nimi.
To zachowanie wskaźnika opóźnionego i granica tego, co ten zestaw potrafi.

## Dane źródłowe

- FRED, baza `data/fed_cycles.db`