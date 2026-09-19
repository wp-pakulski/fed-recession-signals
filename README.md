# Fed, pieniądz i rynki - analiza cykli monetarnych 1990-2026

Jak polityka Rezerwy Federalnej przekłada się na rynki i gospodarkę realną. 17 serii
makroekonomicznych, 441 obserwacji miesięcznych, styczeń 1990 - wrzesień 2026.
Python + SQLite + Excel + Power BI.

**Autor:** Wojciech Pakulski

### 📊 [Interaktywny dashboard →](https://wp-pakulski.github.io/fed-recession-signals/reports/dashboard.html)

Siedem paneli: S&P 500, krzywa dochodowości ze stopą Fed, podaż pieniądza M2, inflacja CPI
wobec realnej stopy, bezrobocie z Sahm Rule, VIX oraz Recession Scorecard. Wykresy można
przybliżać i odczytywać wartości punkt po punkcie.

---

## Co z tego wyszło

**1. Ujemna realna stopa Fed nie daje wyższych zwrotów z giełdy.** Popularna teza mówi,
że tani pieniądz napędza S&P500. Test t-Welcha na 417 miesiącach: średni zwrot 12-miesięczny
wynosi **10,1% w obu reżimach**, `t = -0,009`, **`p = 0,993`**. Różnica jest nie do odróżnienia
od zera, a mediana jest nawet nieco wyższa przy dodatniej realnej stopie.
Hipoteza, poziom istotności i naruszone założenie testu: [Metoda i walidacja](#metoda-i-walidacja).

**2. Rekordowa inwersja krzywej nie zapowiedziała recesji.** Spread 10Y-2Y był ujemny przez
**26 kolejnych miesięcy** (lipiec 2022 - sierpień 2024) - najdłużej w całej analizowanej
historii. Recesja nie nastąpiła. Trzy wcześniejsze inwersje poprzedzały recesję średnio
o 14 miesięcy.

**3. Połowa popularnych wskaźników recesji nie wyprzedza recesji.** Przy kalibracji progów
na rozkładzie historycznym okazało się, że **Sahm Rule, spread HY i wnioski o zasiłek**
mają w oknie 12 miesięcy przed recesją niemal identyczny rozkład co w spokojnych czasach -
rosną dopiero w jej trakcie. Realnie wyprzedzają tylko krzywa dochodowości (mediana 0,12
wobec 1,05) i pozwolenia budowlane (-5,1% wobec +4,5%).

**4. Model uczony in-sample potrafi mylić fazę cyklu z przyczyną.** Regresja logistyczna
osiąga ROC AUC **0,819**, ale współczynnik przy bezrobociu jest **ujemny**: model odczytuje
wysokie bezrobocie jako „dołek już za nami", bo rośnie ono najmocniej *w trakcie* recesji,
a zmienna objaśniana pyta o *następne* 12 miesięcy. Przy czterech recesjach w próbie nie ma
materiału, by to rozróżnić - i dlatego model jest w projekcie opisany jako ilustracja,
nie prognoza.

![Przegląd serii](reports/00_przeglad_serii.png)

---

## Wskaźnik do bieżącego użytku

`scripts/sygnaly_recesyjne.py` generuje [przegląd ośmiu sygnałów recesyjnych](reports/sygnaly_recesyjne.md)
jednym poleceniem:

```bash
python scripts/sygnaly_recesyjne.py
```

Progi nie są dobrane na wyczucie, tylko na rozkładzie historycznym 1990-2026: **UWAGA** gdy
wskaźnik trafia w najgorsze 25% obserwacji, **ALARM** w najgorsze 10%.

Backtest na czterech recesjach:

| Okres | Średnia liczba zapalonych flag |
|---|---|
| 12 miesięcy przed recesją | **2,35** |
| w trakcie recesji | **4,86** |
| pozostałe miesiące | **1,37** |

Wskaźnik zapalił się przed każdą z czterech recesji w próbie. Ostatni wyraźny sygnał to
listopad 2025 (4 flagi); od stycznia 2026 odczyty wahają się między 0 a 2, a dwa ostatnie
miesiące to 0.

---

## Jak to uruchomić

```bash
pip install -r requirements.txt
```

Notebooki uruchamia się **w kolejności 01 → 02 → 05 → 03 → 04**. Nie jest to kolejność
numeryczna: notebook 03 korzysta z indeksu VIX, który trafia do bazy dopiero w notebooku 05.

| Notebook | Co robi |
|---|---|
| `01_data_collection` | pobiera 16 serii z FRED oraz S&P500 i VIX z Yahoo Finance |
| `02_sqlite_queries` | buduje bazę SQLite i widok `v_master` |
| `05_rozszerzenia` | VIX, korelacje, timeline inwersji, regresja logistyczna |
| `03_dashboard` | interaktywny dashboard Plotly, Recession Scorecard |
| `04_analysis` | percentyle, momentum M2, test hipotezy |

Baza `data/fed_cycles.db` nie jest wersjonowana - powstaje z plików w `data/raw/`.

---

## Struktura

```
notebooks/    pięć notebooków, pełny łańcuch od pobrania danych do analizy
scripts/      sygnaly_recesyjne.py - generator raportu
data/raw/     18 plików CSV: dane źródłowe z FRED i Yahoo Finance
reports/      writeup, raport sygnałów, słownik wskaźników, 9 wykresów, dashboard HTML
excel/        skonsolidowany arkusz zbudowany w Power Query
powerbi/      model danych i raport .pbix
```

Arkusz Excel i model Power BI zbudowano na danych z kwietnia 2026 i nie były od tego
czasu odświeżane - liczby w nich pochodzą z tamtego pobrania. Część analityczna
(notebooki, raporty, wykresy) korzysta z danych aktualnych.

Pełne omówienie metody i wyników: **[reports/writeup.md](reports/writeup.md)**
Wyjaśnienie każdego wskaźnika: [reports/slownik_wskaznikow.md](reports/slownik_wskaznikow.md)

---

## Dane

FRED (Federal Reserve Bank of St. Louis), publiczny endpoint CSV bez klucza API, oraz Yahoo
Finance przez `yfinance` dla S&P500 i VIX.

Dwa ograniczenia warte odnotowania:

- FRED skraca historię serii licencjonowanych przy pobraniu (indeks ICE BofA do 3 lat,
  S&P500 do 10). Notebook 01 dopisuje nowe dane do istniejących plików w `data/raw/`,
  zamiast je nadpisywać - dlatego CSV są częścią repozytorium.
- Seria `USSLIND` (wskaźnik wyprzedzający) kończy się w lutym 2020 - została wycofana
  przez FRED i nie da się jej odświeżyć.

---

## Metoda i walidacja

Cztery wnioski powyżej opierają się na różnych narzędziach i mają różną siłę dowodową.
Poniżej wprost, które jest które.

**Test hipotezy (wniosek 1).** Test t Welcha dla dwóch prób o nierównych wariancjach,
`scipy.stats.ttest_ind(equal_var=False)`, poziom istotności α = 0,05.

- H₀: średni 12-miesięczny zwrot S&P500 jest taki sam w miesiącach z ujemną
  i dodatnią realną stopą Fed
- H₁: przy ujemnej realnej stopie zwrot jest wyższy
- Próby: n = 197 (realna stopa < 0) wobec n = 220 (>= 0), okres 1990-2026
- Wynik: średnia 10,1% wobec 10,1%; mediana 11,8% wobec 12,2%;
  odchylenie 14,2 wobec 17,0; `t = -0,009`, `p = 0,9927`
- Decyzja: brak podstaw do odrzucenia H₀

Wariant Welcha, nie Studenta, bo odchylenia w grupach różnią się o blisko 3 pp -
zakładanie równych wariancji byłoby tu nieuprawnione.

**Założenie, które ten test narusza.** Zwroty forward 12M na danych miesięcznych
nakładają się na siebie w 11 z 12 miesięcy, więc 417 obserwacji nie jest niezależnych -
efektywnie jest ich około 35. Nakładanie zaniża wariancję, a więc zawyża istotność.
Obciążenie działa zatem przeciw wykryciu efektu jako istotnego, a nie na jego rzecz:
gdyby test pokazał różnicę, byłaby podejrzana. Pokazał `p = 0,993`, więc wniosek
„różnicy nie widać" jest wobec tego problemu odporny. Test na nienakładających się
okresach rocznych zostawiłby 35 obserwacji - za mało, by cokolwiek wykryć, i to jest
druga strona tego samego ograniczenia.

**Korelacja (heatmapa, 11 wskaźników).** Pearson na oknie 1990-2026, mieszanka
poziomów i dynamik rocznych. Najsilniejsze pary: stopa Fed x realna stopa r = +0,77,
spread HY x VIX r = +0,73, krzywa dochodowości x bezrobocie r = +0,71.
Żaden z 11 wskaźników nie ma wszystkich |r| < 0,3, czyli nie ma tu sygnału niezależnego
od pozostałych. To wynik opisowy, nie test: część korelacji na poziomach jest zawyżona
wspólnym trendem, a stacjonarności serii nie badałem (brak testu ADF).

**Model klasyfikacyjny (wniosek 4).** Regresja logistyczna, `StandardScaler`,
`class_weight='balanced'`, 416 miesięcy, zmienna objaśniana = recesja w ciągu
następnych 12 miesięcy (63 przypadki, 15,1% próby).

- ROC AUC 0,819, **liczone in-sample** - bez podziału na zbiór uczący i testowy
  i bez walidacji krzyżowej szeregów czasowych
- dla klasy „recesja": czułość 0,73, precyzja 0,33 - wyrównanie wag klas kupuje
  wykrywalność kosztem fałszywych alarmów
- współczynniki standaryzowane nie są interpretowalne przyczynowo: przy korelacjach
  rzędu 0,7 między zmiennymi objaśniającymi znaki rozkładają się arbitralnie,
  co widać na ujemnym współczynniku przy bezrobociu (wniosek 4)

AUC 0,819 in-sample nie jest miarą zdolności prognostycznej. Uczciwa ocena wymaga
podziału po czasie, a przy czterech recesjach w próbie każdy podział zostawia
w zbiorze testowym najwyżej jedną - dlatego model jest w projekcie ilustracją metody,
nie prognozą.

**Progi wskaźników (wniosek 3).** Kalibracja na rozkładzie historycznym: porównanie
median w oknie 12 miesięcy przed recesją z pozostałymi okresami. Bez testu istotności -
przy tak małej liczbie recesji i ośmiu wskaźnikach kontrola porównań wielokrotnych
zabrałaby i tak całą moc. Ten wniosek traktować jako obserwację z danych, nie wynik testu.

---

## Ograniczenia

Model predykcyjny uczony jest in-sample na próbie zawierającej **cztery recesje**, z których
najstarsza (1990-1991) wchodzi do niej tylko częściowo, bo okno 12 miesięcy przed jej
początkiem wychodzi poza zakres danych. Przy pięciu zmiennych objaśniających to bardzo mało
materiału. Jego odczyty należy traktować
jako ilustrację metody, nie prognozę. Recession Scorecard i raport sygnałów są oparte na
progach, nie na uczeniu, i są od tego zastrzeżenia niezależne.
