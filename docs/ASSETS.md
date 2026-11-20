# АССЕТЫ «МЁРТВЫЙ ЭФИР» — план, источники, fallback

Политика: только CC0 / Public Domain / CC-BY (с указанием автора в ATTRIBUTION.md).
Запрещены: ripped-ассеты, ассеты из Pale Mimic, паки с неизвестной лицензией.

## 0. Что уже сделано (текущее состояние проекта)

Вся графика в срезе — **процедурная**, средствами Godot 4.3: StandardMaterial3D
(цвет + roughness/metallic + emission) на примитивах BoxMesh/CylinderMesh,
декали Decal-нодами, освещение OmniLight3D/SpotLight3D + WorldEnvironment.
Вся звуковая дорожка — **процедурно сгенерированные WAV** (24 файла в `sounds/`,
генератор `tools/make_sounds.py`): гул трансформатора, ветер, капли, шаги,
статика, «мимикрия», тревога. Это честные placeholder'ы, но не пустые комнаты —
каждая комната наполнена мешами, звуком и декора́ми независимо от внешних ассетов.

## 1. 3D-модели (замена примитивов, как только появится доступ к ассетам)

| Ассет | Поисковый запрос | Источник (CC0 гарантируется) | Fallback в срезе |
|---|---|---|---|
| Скрипучая металлическая дверь | "metal door CC0 gltf kenney" | Kenney (kenney.nl, CC0) — Industrial Kit; Poly Pizza | BoxMesh-створка + материал «ржавый металл», анимация скольжения |
| Радиостанция / консоль | "soviet radio console 3d model CC0" | Poly Pizza (CC0-фильтр), OpenGameArt CC0 | `_led_rack`, `_antenna` (level_builder.gd) |
| Распределительный щиток | "fuse box breaker panel CC0" | Poly Pizza CC0, Sketchfab CC0-фильтр | BoxMesh + дверца + LED |
| Ящики, полки | "crate shelf CC0 kenney" | Kenney Furniture Kit (CC0) | BoxMesh-штабели, seeded RNG в `_furnish_rooms` |
| Трубы / вентиляция | "pipe set CC0 gltf" | Kenney Industrial Kit | `_pipes_wall`, `_pipe_mesh` (цилиндры) |
| Манекен (landmark) | "mannequin CC0 gltf" | Poly Pizza CC0 | `_mannequin` — капсула + сфера, шершавый материал |
| Мебель кабинета/столовой | "desk bench soviet CC0" | Kenney Furniture Kit | Метка PLACEHOLDER: простые боксы с материалом краски |
| Обшивка станка серверной | "server rack CC0" | Poly Pizza CC0 | `_led_rack` с эмиссионными LED-точками |

Обязательное правило при замене: заменить примитив, а не переписывать размещение —
`level_builder.gd` ставит объекты по ячейкам карты, так что смена меша локальна.

## 2. Текстуры / материалы

| Ассет | Поисковый запрос | Источник | Fallback |
|---|---|---|---|
| Бетонные панели (albedo+normal+rough) | "concrete wall PBR CC0" | ambientCG (CC0), Poly Haven (CC0) | Плоский StandardMaterial #3E3A36 |
| Ржавый металл | "rust metal PBR CC0 1k" | ambientCG | Идентичное раскрашивание |
| Кафель душевой | "tile wall PBR CC0" | Poly Haven | То же |
| Снег / иней у окон | "frost decal CC0" | ambientCG (frost decals) | Эмиссионное стекло + холодный свет окна |
| Грязь, копоть, следы | "grime decal CC0 4k" | ambientCG | `_decor_room`: Decal с процедурным цветом + мусор-боксы |

Требование: ≤ ~20 текстур всего по 1K, чтобы 
## 3. Звук

| Ассет | Поисковый запрос | Источник | Fallback |
|---|---|---|---|
| Гул трансформатора (loop) | "transformator hum CC0 freesound" | freesound.org, фильтр CC0 | `hum_transformer.wav` (проц.) |
| Ветер в окнах (loop) | "winter wind loop CC0" | freesound CC0 | `wind.wav` |
| Капли (one-shot) | "water drip metal CC0" | freesound CC0 | `drip.wav` |
| Металлическая дверь | "metal door slide sci-fi CC0" | freesound CC0 | `door_metal.wav` / `door_slam.wav` |
| Шаги по бетону | "concrete footsteps CC0" | freesound CC0 (набор Soniss GDC — иногда CC0) | `step.wav` |
| Низкая тихая тёмная подложка (loop) | "dark drone 50hz CC0" | freesound CC0 | `drone_dark.wav`, `hum_room.wav` |
| Шёпот / имитация голоса | "whisper reversed CC0" | freesound CC0 | `mimic.wav`, `whisper.wav` |
| Статическая помеха | "radio static loop CC0" | freesound CC0 | `static_burst.wav` |

Замена формата: любой WAV/OGG подключается через `sound_bank.gd`; "loops" в `sound_bank.gd` — добавить имя файла в список LOOPS.

## 4. Шрифты

| Ассет | Запрос | Источник | Fallback |
|---|---|---|---|
| Стилизация под советскую вывеску (кириллица) | "cyrillic font OFL soviet" | Google Fonts (OFL — разрешено как CC-совместимый) | Дефолтный шрифт Godot (в UI это допустимо: минимальный HUD) |

## 5. Правило обязательной подстановки

Ни одна комната не считается «не готовой без ассетов»: каждая комната обязана
иметь перечисленное в правилах наполнения (мин. 1 арх. деталь, 2 функциональных
объекта, 3 следа жизни, 2 декали, 1 звук. маркер, 1 интерактив). Всё это
сейчас уже выполнено процедурно; внешние ассеты — только апгрейд визуала.
