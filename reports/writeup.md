# Fed, Pieniądz i Rynki — analiza cykli monetarnych 1990–2026

**Autor:** Wojciech Pakulski  
**Data:** Wrzesień 2026  
**Narzędzia:** Python (pandas, numpy, scipy, scikit-learn, plotly, matplotlib, seaborn), SQLite, FRED API, Yahoo Finance

---

## Cel projektu

Celem było zbadanie, jak polityka monetarna Rezerwy Federalnej — zmiany stóp procentowych i podaży pieniądza — wpływa na rynki finansowe i gospodarkę realną w perspektywie historycznej (1990–2026). Projekt łączy analizę danych makroekonomicznych z testowaniem hipotezy statystycznej.

---

## Dane i metodologia

**Źródła:**
- FRED (Federal Reserve Bank of St. Louis) — 16 serii makroekonomicznych pobrane przez API
- Yahoo Finance (`yfinance`) — historyczne ceny S&P500 (`^GSPC`) i VIX (`^VIX`) od 1990

**Baza danych:** SQLite (`fed_cycles.db`) z widokiem `v_master` agregującym 17 wskaźników miesięcznie — 441 obserwacji, styczeń 1990 - wrzesień 2026.

**Wskaźniki:** FEDFUNDS, M2, S&P500, yield curve (T10Y2Y), inflacja CPI, bezrobocie, PKB, tygodniowe wnioski o zasiłek (ICSA), zatrudnienie (PAYEMS), produkcja przemysłowa (INDPRO), sprzedaż detaliczna, pozwolenia budowlane, spread HY, warunki kredytowe, wskaźnik wyprzedzający LEI, **VIX** (indeks zmienności/strachu).

**Kolejność uruchamiania notebooków:** 01 → 02 → 05 → 03 → 04. Notebook 03 korzysta z VIX, który trafia do bazy dopiero w 05.

---

## Wyniki

### 1. Cykl zacieśnienia 2022–2023 — najszybsza podwyżka od dekad

Fed podniósł stopę z 0.08% (luty 2022) do **5.33%** (sierpień 2023) — 525 punktów bazowych w 16 miesięcy, najszybsze zacieśnienie od lat 80. Do sierpnia 2026 stopa obniżyła się do **3.63%**.

Inflacja CPI osiągnęła szczyt **9.0% w czerwcu 2022** (najwyżej od 1981), a do sierpnia 2026 spadła do **3.4%** — powyżej celu 2%. W ostatnich miesiącach spadek inflacji wyhamował - odczyt wrócił lekko w górę.

### 2. Inwersja krzywej dochodowości — rekordowe 26 miesięcy

Spread 10Y–2Y był ujemny od **lipca 2022 do sierpnia 2024** — przez **26 kolejnych miesięcy**. To najdłuższa inwersja w analizowanej historii (1990–2026). Inwersja krzywej jest tradycyjnie uważana za sygnał recesji, jednak:

> Pomimo rekordowej inwersji, recesja (wg NBER/USREC) **nie wystąpiła** w latach 2023–2026. Gospodarka spowolniła, ale nie skurczyła się.

### 3. Eksplozja i kontrakcja M2

Pandemia wywołała bezprecedensowy wzrost podaży pieniądza: M2 YoY osiągnęło **+26.8% w lutym 2021** — efekt bezpośredniego zastrzyku fiskalnego i zerowych stóp. Następnie Fed ograniczył bilans, a M2 YoY spadło do **-4.6% w kwietniu 2023** — pierwszy historyczny spadek podaży pieniądza od dekad. W lipcu 2026 M2 YoY wynosi **+5.4%**, wracając do normy.

### 4. Rynek pracy - sygnał ostrzegawczy wygasł, brak recesji

Bezrobocie spadło do historycznego minimum **3.4%** w kwietniu 2023, następnie wzrosło do **4.5%** w listopadzie 2025, po czym cofnęło się do **4.1%** w sierpniu 2026. Sahm Rule - wskaźnik wczesnego ostrzegania przed recesją - wynosi **0.00 pp** wobec progu alarmowego 0.5 pp. Sygnał ostrzegawczy z pierwszego kwartału 2026 wygasł.

### 5. Recession Scorecard - niskie ryzyko

Autorski scorecard zapala flagę, gdy wskaźnik przekracza próg ostrzegawczy. Odczyt na lipiec 2026 to **0 z 4**, czyli ryzyko **niskie**:

| Flaga | Wartość | Próg zapalenia | Stan |
|---|---|---|---|
| Yield curve (10Y-2Y) | +0.38 pp | poniżej 0 | ✅ normalna |
| M2 YoY | +5.4% | poniżej 0 | ✅ dodatni |
| Realna stopa Fed | +0.3 pp | powyżej 2 pp | ✅ neutralna |
| Sahm Rule | 0.10 | od 0.5 | ✅ poniżej progu |

Odczyt zatrzymuje się na lipcu 2026, mimo że część serii sięga września: scorecard wymaga kompletu czterech wskaźników naraz, a M2 publikowane jest z największym opóźnieniem.

Osobna uwaga metodologiczna. FRED nie opublikował stopy bezrobocia za październik 2025, a Sahm Rule liczy się z okna kroczącego - jeden brakujący miesiąc wyciszał ją przez kolejnych dwanaście i zatrzymywał cały scorecard na wrześniu 2025. Okna korzystają teraz z `min_periods`, więc pojedyncza dziura w źródle nie unieruchamia wskaźnika.

Scorecard celowo pyta tylko o cztery rzeczy. Szerszy przegląd ośmiu sygnałów znajduje się w [`sygnaly_recesyjne.md`](sygnaly_recesyjne.md) - raport generowany skryptem `scripts/sygnaly_recesyjne.py`, z progami wyznaczonymi na rozkładzie historycznym 1990-2026 (UWAGA = najgorsze 25% obserwacji, ALARM = najgorsze 10%). Przy obecnych danych daje **0 z 8 flag**, co potwierdza odczyt scorecardu.

### 6. Realna stopa Fed - chwiejnie powyżej zera

Realna stopa Fed (FEDFUNDS minus CPI YoY) wynosi +0.28 pp w sierpniu 2026. Po powrocie nad zero w 2023 roku utrzymywała się dodatnia do marca 2026, ale odbicie inflacji zepchnęło ją ponownie poniżej zera w kwietniu i maju (-0.54 pp w maju). Od czerwca jest znów dodatnia, choć blisko granicy. Historycznie 47% miesięcy miało ujemną realną stopę.

### 7. VIX — sentyment rynku

VIX (indeks strachu) dodany jako 17. wskaźnik. Aktualnie **15.7** (36. percentyl historyczny) - rynek jest spokojniejszy niż w dwóch trzecich miesięcy od 1990 roku i bardzo daleko od paniki (GFC: 63, COVID: 58). VIX wykazuje silną korelację ze spreadem HY (r=+0.73) i ujemną z S&P500 YoY (r=-0.48).

### 8. Korelacje wskaźników — niezależność sygnałów

Analiza korelacji 11 kluczowych wskaźników ujawniła:
- **Najsilniejsze pary:** Stopa Fed × Realna stopa (r=+0.77), S&P500 YoY × Spread HY (r=-0.62), VIX × Spread HY (r=+0.73)
- **Wniosek:** Spread HY i VIX niosą podobną informację (strach rynkowy) — w scorecardzie wystarczy jeden z nich. Yield Curve i bezrobocie (r=+0.71) też są powiązane, ale z różnym opóźnieniem czasowym. Yield Curve × S&P500 YoY (r=+0.52) - stroma krzywa idzie w parze z hossą, co wzmacnia interpretację krzywej jako wskaźnika oczekiwań, a nie tylko sygnału recesji.

### 9. Timeline inwersji → recesji

Wizualna analiza 4 epizodów inwersji krzywej dochodowości:

| Inwersja | Recesja | Czas |
|----------|---------|------|
| 1990-03 – 1990-04 | Gulf War (1990) | 5 mies. |
| 2000-02 – 2001-01 | Dot-com (2001) | 14 mies. |
| 2006-02 – 2007-06 | GFC (2008) | 23 mies. |
| 2022-07 – 2024-09 | **Brak recesji** | — |

Średni czas inwersja → recesja: ~14 miesięcy (bez 2022). Ostatnia inwersja (26 miesięcy) nie doprowadziła do recesji — potwierdza tezę o soft landing.

### 10. Model predykcyjny — Logistic Regression

Model regresji logistycznej przewidujący prawdopodobieństwo recesji w ciągu 12 miesięcy na podstawie 5 zmiennych (yield curve, realna stopa, M2 YoY, bezrobocie, VIX).

| Metryka | Wartość |
|---------|---------|
| ROC AUC | 0.819 |
| Recall (recesja) | 73% |
| Próba | 416 miesięcy |

**Najważniejsze zmienne:** bezrobocie (coef = **-1.26**) i VIX (coef = **+0.99**). Znak przy
bezrobociu jest odwrotny do intuicji i to najciekawszy wynik modelu: bezrobocie rośnie
najsilniej *w trakcie* recesji, a zmienna objaśniana pyta o recesję w ciągu *następnych*
12 miesięcy. Model odczytuje więc wysokie bezrobocie jako „dołek już za nami". Łapie fazę
cyklu, nie zależność przyczynową - przy trzech recesjach w próbie nie ma materiału, by je
rozróżnić.

**Ostatni odczyt w próbie (sierpień 2025):** P(recesja w 12M) = **49.1%**

Próba kończy się na sierpniu 2025, choć dane sięgają września 2026. Powód jest
metodologiczny: zmienna objaśniana pyta o recesję w ciągu następnych 12 miesięcy,
więc dla ostatniego roku obserwacji odpowiedzi jeszcze nie znamy.

**Prognoza na najświeższych danych (lipiec 2026):** P(recesja w 12M) = **54.6%** -
poza próbą, możliwa do weryfikacji dopiero w lipcu 2027.

> **Model i scorecard dają różne odczyty i jest to zamierzone.** Scorecard z punktu 5
> pokazuje 0 z 4, bo żaden wskaźnik nie przekroczył progu alarmowego. Model pokazuje
> 55%, mimo że sytuacja makro się poprawiła - bo spadek bezrobocia z 4.5% do 4.1% przy
> ujemnym współczynniku *podnosi* jego odczyt. To dobra ilustracja, dlaczego modelu
> uczonego in-sample na trzech recesjach nie należy czytać jak prognozy. Scorecard
> odpowiada na pytanie „czy coś przekroczyło próg", model - „jak ten układ zmiennych
> wyglądał historycznie".

Model należy traktować z ostrożnością: uczony in-sample, na zaledwie 3 recesjach.

---

## Test hipotezy statystycznej

**H₁:** Średni 12-miesięczny zwrot S&P500 jest wyższy w miesiącach z ujemną realną stopą Fed niż w miesiącach z dodatnią.

**Metoda:** t-test Welcha (nierówne wariancje), α = 0.05

| Reżim | n | Średni zwrot 12M | Mediana |
|-------|---|------------------|---------|
| Ujemna realna stopa | 197 | 10.1% | 11.8% |
| Dodatnia realna stopa | 220 | 10.1% | 12.2% |

**Wynik:** t = -0.009, **p = 0.9927** → brak podstaw do odrzucenia H₀.

> **Wniosek:** Wbrew popularnej narracji, ujemna realna stopa Fed **nie przekłada się statystycznie** na wyższe zwroty S&P500 w horyzoncie 12 miesięcy. Różnica średnich wynosi **0.0 pp** - zwroty są nierozróżnialne, a mediana jest nawet nieznacznie wyższa w reżimie dodatniej realnej stopy, co odwraca kierunek popularnej tezy. Inne czynniki — zyski spółek, sentyment, polityka fiskalna — mają większe znaczenie niż sam poziom realnej stopy.

---

## Wnioski końcowe

1. **Cykl zacieśnienia 2022–2023 był wyjątkowy** pod względem tempa, skali i braku recesji — gospodarka USA okazała się bardziej odporna niż sugerowały historyczne wzorce.

2. **Yield curve przestała być niezawodnym wskaźnikiem recesji** — rekordowa 26-miesięczna inwersja nie poprzedzała recesji w standardowym oknie 12–18 miesięcy.

3. **M2 wraca do normy** po epizodzie pandemicznym. Tempo wzrostu +5.4% YoY nie sygnalizuje ani deflacyjnej pułapki, ani inflacyjnego przegrzania.

4. **Rynek pracy pozostaje kluczową zmienną do obserwacji** — sygnał ostrzegawczy z przełomu 2025 i 2026 wygasł, Sahm Rule wróciła do zera. Jej ponowne przekroczenie 0.5 pp byłoby pierwszym silnym sygnałem recesyjnym.

5. **Statystyczna analiza podważa intuicje** — korelacja realna stopa / zwroty giełdowe jest słaba i nieistotna. Inwestowanie na podstawie samego poziomu stóp to uproszczenie.

---

## Pliki projektu

```
notebooks/
├── 01_data_collection.ipynb   # pobieranie danych z FRED i yfinance
├── 02_sqlite_queries.ipynb    # budowa bazy SQLite, widok v_master, 10 zapytań
├── 03_dashboard.ipynb         # interaktywny dashboard Plotly (7 paneli)
├── 04_analysis.ipynb          # percentyle, momentum M2, test hipotezy
└── 05_rozszerzenia.ipynb      # VIX, korelacje, timeline, logistic regression

reports/
├── dashboard.html             # interaktywny dashboard
├── 01_percentyle_historyczne.png
├── 02_m2_momentum.png
├── 03_realna_stopa_fed.png
├── 04_test_hipotezy_sp500.png
├── 05_vix.png                 # VIX z progami strachu/paniki
├── 06_korelacje.png           # heatmapa korelacji wskaźników
├── 07_timeline_inwersja_recesja.png  # inwersja → recesja timeline
└── 08_recession_model.png     # logistic regression + ROC curve
```
