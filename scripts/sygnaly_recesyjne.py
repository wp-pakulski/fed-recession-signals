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

def formatuj_wartosc(wartosc) -> str:
    """206000.0 -> '206 000', 0.3962 -> '+0.40', None -> 'brak danych'."""
    if wartosc is None:
        return 'brak danych'
    if abs(wartosc) >= 1000:
        return f'{wartosc:,.0f}'.replace(',', ' ')
    return f'{wartosc:+.2f}'

def zbuduj_raport(wyniki: list, nazwa: str, flagi: int, alarmy: int) -> str:
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
    zapisz(zbuduj_raport(wyniki, nazwa, flagi, alarmy))
    print(f'{RAPORT.name}: {nazwa}, flagi {flagi}, alarmy {alarmy}')