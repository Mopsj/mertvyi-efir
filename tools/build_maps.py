#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Генератор station_data.gd: строит ASCII-карты этажей из прямоугольников комнат,
валидирует их и выкладывает готовый GDScript-файл."""

# Legend: '#' стенка, '.' пол, '+' дверь, 'H' люк, '1'/'2' лестницы,
# P/M/m/n/N/F/f/b/T/x/W/L/l/r маркеры.

FLOORS = []


def rect(x0, y0, x1, y1):
    return (x0, y0, x1, y1)


class Floor:
    def __init__(self, fid, name, w, h, ceil_h, ambient, ambient_energy, fog_density):
        self.fid = fid
        self.name = name
        self.w = w
        self.h = h
        self.ceil_h = ceil_h
        self.ambient = ambient
        self.ambient_energy = ambient_energy
        self.fog = fog_density
        self.grid = [['#'] * w for _ in range(h)]
        self.rooms = []
        self.doors = []
        self.marks = []

    def room(self, name, r, style):
        x0, y0, x1, y1 = r
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.grid[y][x] = '.'
        self.rooms.append((name, style, (x0, y0, x1, y1)))
        return self

    def door(self, x, y, kind='+'):
        self.grid[y][x] = kind
        self.doors.append((x, y, kind))
        return self

    def put(self, ch, *cells):
        for (x, y) in cells:
            self.grid[y][x] = ch
            self.marks.append((ch, x, y))
        return self

    def rows(self):
        return [''.join(r) for r in self.grid]


# ---------------------------------------------------------------- БУНКЕР Б1
f0 = Floor(0, "БУНКЕР Б1 — МАШИННОЕ ОТДЕЛЕНИЕ", 28, 15, 2.7,
           (0.16, 0.19, 0.24), 0.22, 0.028)
f0.room("Лестничная клетка Б1", rect(1, 1, 4, 4), "stairs")
f0.room("Генераторная", rect(6, 1, 14, 4), "generator")
f0.room("Шлюзовая", rect(16, 1, 19, 4), "gallery")
f0.room("Котельная", rect(21, 1, 26, 4), "boiler")
f0.room("Коридор Б1", rect(1, 6, 26, 7), "corridor_basement")
f0.room("Склад Б1", rect(1, 9, 6, 13), "storage")
f0.room("Технический тоннель", rect(8, 9, 9, 13), "tunnel")
f0.room("Клетка антенны", rect(11, 9, 26, 13), "cage")
f0.door(5, 2)     # лестничная ↔ генераторная
f0.door(2, 5)     # лестничная → коридор
f0.door(10, 5)    # генераторная → коридор
f0.door(18, 5)    # шлюзовая → коридор
f0.door(24, 5)    # котельная → коридор
f0.door(2, 8)     # коридор → склад Б1
f0.door(8, 8, 'H')  # люк техтоннеля (заперт)
f0.door(13, 8)    # коридор → клетка антенны (красная дверь)
f0.put('2', (2, 1))
f0.put('x', (5, 2))          # громкоговоритель на стене генераторной
f0.put('F', (8, 2))
f0.put('N', (12, 3))
f0.put('f', (25, 3))
f0.put('L', (10, 1))
f0.put('l', (22, 2))     # котельная: мигающая аварийная LED
f0.put('r', (13, 7))         # красный маяк над красной дверью
f0.put('r', (8, 7))          # маяк у люка
f0.put('b', (2, 12))
for m in [(4, 3), (9, 11), (18, 6), (24, 12), (2, 11), (5, 12)]:
    f0.put('m', m)

# ------------------------------------------------------------- 1 ЭТАЖ
f1 = Floor(1, "1 ЭТАЖ — ОПЕРАТОРСКАЯ ЗОНА", 28, 17, 3.0,
           (0.13, 0.16, 0.21), 0.26, 0.012)
f1.room("Пост охраны (КПП)", rect(1, 1, 4, 4), "guardpost")
f1.room("Холл", rect(6, 1, 11, 4), "hall")
f1.room("Кабинет нач. смены", rect(13, 1, 17, 4), "office")
f1.room("Радиоузел", rect(19, 1, 26, 4), "radio")
f1.room("Душевая", rect(1, 6, 4, 9), "shower")
f1.room("Коридор западный", rect(6, 6, 18, 9), "corridor")
f1.room("Склад", rect(20, 6, 26, 9), "storage")
f1.room("Столовая", rect(1, 11, 8, 15), "canteen")
f1.room("Лифт-холл", rect(10, 11, 13, 15), "lift")
f1.room("Коридор южный", rect(15, 11, 21, 15), "corridor_south")
f1.room("Лестница на Б1", rect(23, 11, 26, 15), "stairs")
f1.door(5, 2)      # КПП ↔ холл
f1.door(8, 5)      # холл → коридор
f1.door(15, 5)     # кабинет → коридор
f1.door(22, 5)     # радиоузел → склад
f1.door(5, 7)      # душевая → коридор
f1.door(19, 8)     # коридор → склад
f1.door(3, 10)     # столовая → коридор
f1.door(17, 10)    # коридор южный
f1.door(24, 10)    # лестница на Б1
f1.door(9, 12)     # столовая → лифт-холл
f1.door(22, 14)    # коридор южный ↔ лестница (срез)
f1.put('P', (2, 2))
f1.put('1', (7, 7))
f1.put('2', (24, 12))
f1.put('n', (3, 1))
f1.put('n', (15, 2))
f1.put('N', (23, 2))
f1.put('f', (24, 7))
f1.put('b', (2, 8))
f1.put('b', (12, 13))
f1.put('x', (18, 3))
f1.put('W', (2, 0), (3, 0), (9, 0), (15, 0), (16, 0), (2, 5), (3, 5))
f1.put('L', (2, 1), (8, 2), (15, 1), (22, 1), (16, 7), (4, 13), (18, 12))
f1.put('l', (12, 8), (25, 7))
for m in [(7, 8), (24, 3), (17, 14), (2, 14), (11, 6)]:
    f1.put('m', m)

# ------------------------------------------------------------ РАДИОЭТАЖ
f2 = Floor(2, "РАДИОЭТАЖ — АППАРАТНЫЕ", 26, 15, 2.8,
           (0.11, 0.15, 0.22), 0.20, 0.016)
f2.room("Лестница с 1 этажа", rect(1, 1, 3, 4), "stairs")
f2.room("Аппаратная", rect(5, 1, 11, 4), "radio")
f2.room("Операторская", rect(13, 1, 23, 4), "oproom")
f2.room("Коридор радио", rect(1, 5, 14, 8), "corridor")
f2.room("Серверная", rect(16, 5, 24, 8), "server")
f2.room("Архив", rect(1, 10, 6, 13), "archive")
f2.room("Машинный зал", rect(8, 10, 20, 13), "machine")
f2.room("Трубная", rect(22, 10, 24, 13), "storage_small")
f2.door(4, 2)      # лестница ↔ аппаратная
f2.door(12, 3)     # аппаратная ↔ операторская
f2.door(8, 4)      # аппаратная → коридор
f2.door(18, 4)     # операторская → серверная
f2.door(15, 6)     # коридор → серверная
f2.door(2, 9)      # архив
f2.door(9, 9)      # машинный зал (север)
f2.door(13, 9)     # машинный зал (север-2)
f2.door(21, 12)    # машинный зал → трубная
f2.put('1', (2, 2))
f2.put('N', (8, 2), (20, 6))
f2.put('n', (15, 2))
f2.put('f', (3, 11))
f2.put('b', (2, 12))
f2.put('b', (23, 11))
f2.put('x', (6, 9))
f2.put('W', (19, 0), (20, 0))
f2.put('L', (8, 1), (18, 1), (4, 6), (22, 6), (10, 10))
f2.put('l', (11, 7), (19, 5), (15, 12))
for m in [(5, 7), (16, 13), (2, 11), (11, 10)]:
    f2.put('m', m)
f2.put('M', (12, 11))

FLOORS = [f0, f1, f2]

# ---------------------------------------------------------------- ВАЛИДАЦИЯ
PASS = set('#. +H12PMmNFnfxWLlrbT')
WALLLIKE = set('#WHx')

errors = []


def check_floor(f):
    base = f'floor {f.fid} ({f.name})'
    for i, row in enumerate(f.rows()):
        if len(row) != f.w:
            errors.append(f'{base}: row {i} length {len(row)} != {f.w}')
    for y in range(f.h):
        for x in range(f.w):
            c = f.grid[y][x]
            if c not in PASS:
                errors.append(f'{base}: bad char {c!r} at {x},{y}')
    border_pos = []
    for x in range(f.w):
        border_pos += [(x, 0), (x, f.h - 1)]
    for y in range(f.h):
        border_pos += [(0, y), (f.w - 1, y)]
    for (x, y) in border_pos:
        c = f.grid[y][x]
        if c not in '#Wx':  # окна и громкоговорители намеренно встроены в стены
            errors.append(f'{base}: broken border at {x},{y} ({c!r})')

    walk = set('. +H12PMmNFnfLlrbT')  # всё кроме стен, окон, колонок
    def ok(x, y):
        return 0 <= x < f.w and 0 <= y < f.h and f.grid[y][x] in walk

    # старт: P, если есть, иначе лестница вперёд (радиоэтаж) /
    # лестница 2 (бункер)
    seeds = [(x, y) for y in range(f.h) for x in range(f.w) if f.grid[y][x] in 'P12']
    if not seeds:
        errors.append(f'{base}: no P/stairs seed')
        return
    seen = set()
    stack = list(seeds)
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not ok(x, y):
            continue
        seen.add((x, y))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            stack.append((x + dx, y + dy))
    for y in range(f.h):
        for x in range(f.w):
            c = f.grid[y][x]
            if c in '.PMmNFnfLlrbT12+H' and (x, y) not in seen:
                errors.append(f'{base}: unreachable {c!r} at {x},{y}')

    # двери должны соединять два пола
    for (x, y, k) in f.doors:
        n_ok = ok(x, y - 1) and ok(x, y + 1)
        w_ok = ok(x - 1, y) and ok(x + 1, y)
        if not (n_ok or w_ok):
            errors.append(f'{base}: door {k} at {x},{y} has no two sides')

    # комнаты: прямоугольники внутри проходимых клеток
    for (name, style, (x0, y0, x1, y1)) in f.rooms:
        xs = range(x0, x1 + 1)
        for y in range(y0, y1 + 1):
            for x in xs:
                if f.grid[y][x] in '#WH':
                    errors.append(f'{base}: room "{name}" covers wall at {x},{y}')


for fl in FLOORS:
    check_floor(fl)

counts = {'N': 0, 'f': 0, 'n': 0, 'P': 0}
for fl in FLOORS:
    for (ch, x, y) in fl.marks:
        counts[ch] = counts.get(ch, 0) + 1
for k, v in counts.items():
    if k == 'N' and v != 4:
        errors.append(f'nodes N = {v}, need 4')
    if k == 'f' and v != 3:
        errors.append(f'fuses f = {v}, need 3')
    if k == 'n' and v != 3:
        errors.append(f'notes n = {v}, need 3')
    if k == 'P' and v != 1:
        errors.append(f'P = {v}, need 1')

if errors:
    print('VALIDATION ERRORS:')
    for e in errors:
        print(' -', e)
else:
    print('VALIDATION OK')

for fl in FLOORS:
    print(f'--- {fl.fid}: {fl.name} ---')
    for r in fl.rows():
        print(r)

# ------------------------------------------------------- ЭМИССИЯ GDScript
NOTES = {
    'n1': {
        'title': 'Накладная смены Ильина',
        'text': "24.01.1986. Ламп накаливания 40 Вт — 12 упаковок, это всё, что осталось.\n"
                "Батарейный ящик опечатан, ключи — у нач. смены.\n\n"
                "Второй пост дважды давал конфликтный доклад: в канале слышали голос,\n"
                "которого нет в журнале разговоров. Селектор при этом работал\n"
                "даже при снятых предохранителях.\n\n"
                "Если услышите позывной «СОСНА» без запроса — не отвечать.",
    },
    'n2': {
        'title': 'Приказ по узлу связи «Сосна-7»',
        'text': "Приказ №19: в 21:00 личный состав покинуть узел.\n\n"
                "Нач. смены Никитин отказался. Из объяснительной: «если её заткнуть,\n"
                "аппаратура остынет. Она не любит холод. Она голоса собирает, как иней».\n\n"
                "Приказ отменён. Узлы не глушить.\n"
                "К 03:10 связь с Никитиным потеряна. Линия держит несущую,\n"
                "и голос на несущей один и тот же, кто бы ни докладывал.",
    },
    'n3': {
        'title': 'К первому дежурству',
        'text': "Правила, которых нет на стенах, но их все выполняют:\n\n"
                "— Не бегать, если не собираешься далеко бежать.\n"
                "— Она не смотрит. Она слушает и говорит.\n"
                "— Не отвечать на голос в селекторе. Никогда. Даже своим.\n\n"
                "Имя ей никто не дал. Мы просто говорим «тишина» —\n"
                "когда она проходит по коридору, эфир затихает первым.",
    },
}

ENDINGS = {
    'silence': {
        'title': '«Заглушить станцию»',
        'text': "Вы опускаете главный рубильник. Несущая умирает с долгим стоном —\n"
                "и впервые за много зим в «Сосне-7» по-настоящему тихо.\n\n"
                "Где-то в трубной, за щитом, срывается пар — и затихает, как будто тоже слушал.\n\n"
                "Вы уходите по снегу, Не оглядываясь на антенну. Она больше не поёт.\n\n"
                "КОНЕЦ: ТИХИЙ ЭФИР",
    },
    'transmit': {
        'title': '«Передать сигнал»',
        'text': "Вы поднимаете несущую до полной мощности. Селектор оживает, и в нём —\n"
                "ваш собственный голос, слово в слово, повторяет то,\n"
                "что вы сказали вслух минуту назад.\n\n"
                "Станция приняла ещё одного диктора.\n\n"
                "Экран гаснет. В темноте антенной клетки кто-то терпеливо ждёт очередь.\n\n"
                "КОНЕЦ: ВЫШКА ПОЁТ",
    },
}


def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


def emit_dict(d, ind):
    out = []
    for k, v in d.items():
        if isinstance(v, str):
            out.append(f'{ind}{q(k)}: {q(v)},')
        else:
            out.append(f'{ind}{q(k)}: {emit_dict(v, ind + chr(9))},')
    return '{\n' + '\n'.join(out) + '\n' + ind[:-1] + '}'


lines = []
lines.append('extends RefCounted')
lines.append('class_name StationData')
lines.append('## АВТОГЕНЕРАЦИЯ: tools/build_maps.py — не редактировать вручную, править генератор.')
lines.append('## Сетка: 1 клетка = 2 метра. X — столбец (восток), Z — строка (юг).')
lines.append('')
lines.append('const CELL := 2.0')
lines.append('')
lines.append('# Легенда: # стенка, . пол, + дверь, H люк, 1/2 лестницы,')
lines.append('# P спавн игрока, M спавн монстра, m патруль, N узел, F щиток,')
lines.append('# f предохранитель, n записка, b бутыль, T терминал, x громкоговоритель,')
lines.append('# W окно, L лампа тёплая, l лампа мигающая, r красный маяк.')
lines.append('')
lines.append('const MAPS := [')

for fl in FLOORS:
    lines.append('\t{')
    lines.append(f'\t\t"id": {fl.fid},')
    lines.append(f'\t\t"name": {q(fl.name)},')
    lines.append(f'\t\t"ceil_h": {fl.ceil_h},')
    a = fl.ambient
    lines.append(f'\t\t"ambient": Color({a[0]}, {a[1]}, {a[2]}),')
    lines.append(f'\t\t"ambient_energy": {fl.ambient_energy},')
    lines.append(f'\t\t"fog_density": {fl.fog},')
    lines.append(f'\t\t"rows": [')
    for row in fl.rows():
        lines.append(f'\t\t\t{q(row)},')
    lines.append('\t\t],')
    lines.append('\t\t"rooms": [')
    for (name, style, r) in fl.rooms:
        lines.append(f'\t\t\t{{"name": {q(name)}, "style": {q(style)}, "rect": [{r[0]}, {r[1]}, {r[2]}, {r[3]}]}},')
    lines.append('\t\t],')
    lines.append('\t},')
lines.append(']')
lines.append('')
lines.append('# --- Записки ---')
lines.append('const NOTES := ' + emit_dict(NOTES, '\t'))
lines.append('')
lines.append('# --- Финальный выбор ---')
lines.append('const ENDINGS := ' + emit_dict(ENDINGS, '\t'))
lines.append('')

with open('scripts/station_data.gd', 'w', encoding='utf-8') as fp:
    fp.write('\n'.join(lines) + '\n')
print('written scripts/station_data.gd')
