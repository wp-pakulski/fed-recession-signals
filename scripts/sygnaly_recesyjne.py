"""Przegląd sygnałów recesyjnych - generuje reports/sygnaly_recesyjne.md z bazy fed_cycles.db."""

import sqlite3
from pathlib import Path
import pandas as pd

BASE = Path(__file__).resolve().parent.parent if '__file__' in globals() else Path.cwd().parent
DB = BASE / 'data' / 'fed_cycles.db'
RAPORT = BASE / 'reports' / 'sygnaly_recesyjne.md'

# kolumna, etykieta do raportu, kierunek, próg UWAGA, próg ALARM
# kierunek 'lt' = niższa wartość jest gorsza, 'gt' = wyższa jest gorsza
PROGI = [
    ('t10y2y',      'Yield curve 10Y-2Y (pp)',      'lt',       0.36,       0.05),
    ('sahm',        'Sahm Rule (pp)',               'gt',       0.30,       0.50),
    ('payems_mom',  'Zatrudnienie MoM (%)',         'lt',       0.03,       -0.10),
    ('indpro_yoy',  'Produkcja przemysłowa YoY (%)','lt',       -0.17,      -3.24),
    ('icsa',        'Wnioski o zasiłek (tyg.)',     'gt',       461600,     559200),
    ('hy_spread',   'Spread kredytowy HY (pp)',     'gt',       8.08,       9.0),
    ('rsxfs_yoy',   'Sprzedaż detaliczna YoY (%)',  'lt',       2.99,       1.40),
    ('permit_yoy',  'Pozwolenia budowlane YoY (%)', 'lt',       -2.32,      -16.13)
]

IKONY = {'OK': '✅', 'UWAGA': '⚠️', 'ALARM': '🔴', 'BRAK': '❔'}
ETYKIETY_REZIMOW = {
    'przed':   '12 miesięcy przed recesją',
    'recesja': 'w trakcie recesji',
    'spokoj':  'pozostałe miesiące',
}
IKONY_WERDYKTU = {'NISKIE': '✅', 'UMIARKOWANE': '⚠️', 'WYSOKIE': '🔴'}


def wczytaj_dane() -> pd.DataFrame:
    """Zwraca widok v_master posortowany rosnąco po kolumnie ym."""
    if not DB.exists():
        raise SystemExit(f'Brak bazy {DB}. Uruchom notebooki 01 i 02.')
    conn = sqlite3.connect(DB)
    df = pd.read_sql('SELECT * FROM v_master ORDER BY ym', conn)
    conn.close()

    return df

def policz_wskazniki(df: pd.DataFrame) -> pd.DataFrame:
    """Dodaje kolumny pochodne potrzebne do oceny sygnałów."""
    df = df.copy()

    df["sahm"] = (df["unrate"].rolling(3, min_periods=2).mean() - df["unrate"].rolling(12, min_periods=10).min())
    df["sahm"] = df["sahm"].where(df["unrate"].notna())

    df["payems_mom"] = df["payems"].pct_change() * 100
    df["indpro_yoy"] = df["indpro"].pct_change(12) * 100
    df["rsxfs_yoy"] = df["rsxfs"].pct_change(12) * 100
    df["permit_yoy"] = df["permit"].pct_change(12) * 100
    
    return df

def ostatni_odczyt(df: pd.DataFrame, kolumna: str) -> tuple:
    """Zwraca (wartość, miesiąc) ostatniego niepustego odczytu danej kolumny."""
    s = df[['ym', kolumna]].dropna()
    if s.empty:
        return None, None
    return s.iloc[-1][kolumna], s.iloc[-1]['ym']

def ocen(wartosc, kierunek: str, uwaga: float, alarm: float) -> str:
    """Zwraca 'BRAK', 'ALARM', 'UWAGA' albo 'OK'."""
    if wartosc is None:
        return 'BRAK'
    if kierunek == 'lt':
        if wartosc < alarm:  return 'ALARM'
        if wartosc < uwaga:  return 'UWAGA'
    else:
        if wartosc > alarm: return 'ALARM'
        if wartosc > uwaga: return 'UWAGA'
    return 'OK'

def zbierz_odczyty(df: pd.DataFrame) -> list:
    """Dla każdego wskaźnika z PROGI zwraca słownik z odczytem i oceną."""
    wyniki = []
    for kolumna, etykieta, kierunek, uwaga, alarm in PROGI:
        wartosc, miesiac = ostatni_odczyt(df, kolumna)
        ocena = ocen(wartosc, kierunek, uwaga, alarm)
        wyniki.append({
            'etykieta': etykieta,
            'wartosc': wartosc,
            'miesiac': miesiac,
            'ocena': ocena,
            'kierunek': kierunek,
            'prog_uwaga': uwaga,
        })
    return wyniki

def werdykt(wyniki: list) -> tuple:
    """Zwraca (nazwa werdyktu, liczba flag, liczba alarmów)."""
    flagi = sum(1 for w in wyniki if w['ocena'] in ('UWAGA', 'ALARM'))
    alarmy = sum(1 for w in wyniki if w['ocena'] == 'ALARM')

    if flagi <= 1:
        nazwa = 'NISKIE'
    elif flagi <= 3:
        nazwa = 'UMIARKOWANE'
    else:
        nazwa = 'WYSOKIE'

    if alarmy >= 1 and nazwa == 'NISKIE':
        nazwa = 'UMIARKOWANE'

    return nazwa, flagi, alarmy

def policz_flagi_historycznie(df: pd.DataFrame) -> tuple:
    """Dla każdego miesiąca zwraca (liczba flag, czy wszystkie 8 wskaźników miało dane)."""
    oceny = pd.DataFrame(index=df.index)
    for kolumna, _, kierunek, uwaga, alarm in PROGI:
        # pd.isna jest konieczne: ocen() porównuje wartość z progiem, a każde
        # porównanie z NaN daje False, więc brak danych wyszedłby jako 'OK'
        oceny[kolumna] = df[kolumna].map(
            lambda v, k=kierunek, u=uwaga, a=alarm: ocen(None if pd.isna(v) else v, k, u, a)
        )
    zapalone = oceny.isin(['UWAGA', 'ALARM']).sum(axis=1)
    kompletne = (oceny != 'BRAK').all(axis=1)
    return zapalone, kompletne

def przypisz_rezim(df: pd.DataFrame, okno: int = 12) -> pd.Series:
    """Oznacza każdy miesiąc jako 'recesja', 'przed' (okno mies. przed startem) albo 'spokoj'."""
    usrec = df['usrec'].fillna(0)
    poczatki = df.index[(usrec == 1) & (usrec.shift(1) == 0)]
    rezim = pd.Series('spokoj', index=df.index)
    for p in poczatki:
        rezim.iloc[max(0, p - okno):p] = 'przed'
    rezim[usrec == 1] = 'recesja'      # recesja ma pierwszeństwo nad oknem "przed"
    return rezim

def backtest(df: pd.DataFrame, okno: int = 12) -> pd.DataFrame:
    """Średnia i maksymalna liczba flag w trzech reżimach.

    Liczone tylko na miesiącach z kompletem ośmiu wskaźników. Ogranicza to próbę
    do okresu od grudnia 1996 (początek serii spreadu HY) i do trzech recesji -
    okno przed recesją 1990-1991 nie ma ani jednego miesiąca z pełnymi danymi.
    """
    zapalone, kompletne = policz_flagi_historycznie(df)
    tab = pd.DataFrame({
        'flagi': zapalone.where(kompletne),
        'rezim': przypisz_rezim(df, okno),
    }).dropna(subset=['flagi'])
    wynik = tab.groupby('rezim')['flagi'].agg(srednia='mean', maks='max', n='count')
    return wynik.reindex(['przed', 'recesja', 'spokoj'])

def formatuj_wartosc(wartosc) -> str:
    """206000.0 -> '206 000', 0.3962 -> '+0.40', None -> 'brak danych'."""
    if wartosc is None:
        return 'brak danych'
    if abs(wartosc) >= 1000:
        return f'{wartosc:,.0f}'.replace(',', ' ')
    return f'{wartosc:+.2f}'

def zbuduj_raport(wyniki: list, nazwa: str, flagi: int, alarmy: int, bt: pd.DataFrame) -> str:
    """Składa treść raportu w markdown."""
    dzis = pd.Timestamp.today().strftime('%Y-%m-%d')
    linie = [
        '# Przegląd sygnałów recesyjnych',
        '',
        f'**Wygenerowano:** {dzis}  ',
        f'**Werdykt: {IKONY_WERDYKTU[nazwa]} {nazwa} ryzyko recesji**',      # (1)
        '',
        f'Zapalone flagi: **{flagi} z {len(wyniki)}**, w tym alarmy: **{alarmy}**',
        '',
        '| Wskaźnik | Wartość | Flaga zapala się | Dane za | Sygnał |',
        '|---|---|---|---|---|',
    ]
    for w in wyniki:
        wartosc_txt = formatuj_wartosc(w['wartosc'])
        znak = '<' if w['kierunek'] == 'lt' else '>'
        prog_txt = f'{znak} {formatuj_wartosc(w["prog_uwaga"])}'
        ikona = IKONY[w['ocena']]
        linie.append(f'| {w["etykieta"]} | {wartosc_txt} | {prog_txt} | {w["miesiac"]} | {ikona} {w["ocena"]} |')
    linie += [
        '',
        'Progi wyznaczone na rozkładzie historycznym 1990-2026: UWAGA gdy wskaźnik',
        'trafia w najgorsze 25% obserwacji, ALARM w najgorsze 10%.',
        '',
        '## Backtest 1996-2026',
        '',
        '| Reżim | Średnio flag | Maksimum | Miesięcy |',
        '|---|---|---|---|',
        *[
            f'| {ETYKIETY_REZIMOW[r]} | **{bt.loc[r, "srednia"]:.2f}** | '
            f'{int(bt.loc[r, "maks"])} | {int(bt.loc[r, "n"])} |'
            for r in bt.index if pd.notna(bt.loc[r, 'srednia'])
        ],
        '',
        'Liczone tylko na miesiącach, w których wszystkie osiem wskaźników miało dane.',
        'Ogranicza to backtest do okresu od grudnia 1996 i trzech recesji - spread HY',
        'z indeksu ICE BofA zaczyna się dopiero wtedy.',
        '',
        'Średnia separuje reżimy, maksimum już nie: spokojne miesiące też dochodzą',
        'do 7 flag, a najwyższe odczyty wypadają **po** recesjach, nie przed nimi.',
        'To zachowanie wskaźnika opóźnionego i granica tego, co ten zestaw potrafi.',
        '',
        '## Dane źródłowe',
        '',
        '- FRED, baza `data/fed_cycles.db`',
    ]
    return '\n'.join(linie)

def zapisz(tresc: str) -> None:
    RAPORT.parent.mkdir(parents=True, exist_ok=True)
    RAPORT.write_text(tresc, encoding='utf-8')

if __name__ == '__main__':
    df = policz_wskazniki(wczytaj_dane())
    wyniki = zbierz_odczyty(df)
    nazwa, flagi, alarmy = werdykt(wyniki)
    bt = backtest(df)
    zapisz(zbuduj_raport(wyniki, nazwa, flagi, alarmy, bt))
    print(f'{RAPORT.name}: {nazwa}, flagi {flagi}, alarmy {alarmy}')
    print(f'backtest: przed {bt.loc["przed", "srednia"]:.2f}, '
          f'recesja {bt.loc["recesja", "srednia"]:.2f}, '
          f'spokoj {bt.loc["spokoj", "srednia"]:.2f}')