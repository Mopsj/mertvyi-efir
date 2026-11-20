# ATTRIBUTION — «МЁРТВЫЙ ЭФИР»

## 1. Контент в репозитории

- **Код GDScript** (все `scripts/*.gd`, генераторы `tools/*.py`, сцена
  `scenes/main.tscn`, иконка `icon.svg`) — написаны для проекта без внешних
  зависимостей. Лицензия — как у проекта целиком (см. README).
- **Звук** (`sounds/*.wav`, 24 файла) — синтезированы процедурно скриптом
  `tools/make_sounds.py` (Python, stdlib `math`/`wave`). Внешние сэмплы
  не использовались.
- **Заглушки-примитивы Godot** — остаточные процедурные материалы (ящики,
  декор) честно помечены как placeholder в docs/ASSETS.md.

## 2. Внешние ассеты

Скачаны и включены в репозиторий:

| Ассет | Источник | Автор | Лицензия | Ссылка |
|---|---|---|---|---|
| Модель монстра «Тишина»: Skeleton Monster + анимации (Idle/Running/Attack/Spawn/Death), FBX | Pack «Animated Monster Pack», OpenGameArt | Quaternius | CC0 1.0 | https://opengameart.org/content/lowpoly-animated-monsters |
| Текстура polished wall — plastered_wall (diff/nor_gl/arm, 1k) | Poly Haven | Poly Haven | CC0 | https://polyhaven.com/a/plastered_wall |
| Текстура бетонной стены — concrete_wall_004 (diff/nor_gl/arm, 1k) | Poly Haven | Poly Haven | CC0 | https://polyhaven.com/a/concrete_wall_004 |
| Текстура бетонного пола — concrete_floor_worn_001 (diff/nor_gl/arm, 1k) | Poly Haven | Poly Haven | CC0 | https://polyhaven.com/a/concrete_floor_worn_001 |
| Текстура ржавого металла — rusty_metal_02 (diff/nor_gl/arm, 1k) | Poly Haven | Poly Haven | CC0 | https://polyhaven.com/a/rusty_metal_02 |
| Текстура металлической панели — metal_plate (diff/nor_gl/arm, 1k) | Poly Haven | Poly Haven | CC0 | https://polyhaven.com/a/metal_plate |

Файлы: `assets/monster/skeleton.fbx` (+ лицензия-копия `assets/monster/LICENSE_Quaternius_CC0.txt`),
`assets/tex/*_diff.jpg`, `*_nor_gl.jpg`, `*_arm.jpg` (AO=R, Roughness=G, Metallic=B).
Проверка лицензии «Animated Monster Pack»: страница OpenGameArt помечена
License(s): CC0; https://creativecommons.org/publicdomain/zero/1.0/.

## 4. Движок и инструменты

- **Godot Engine 4.3** — MIT License — https://godotengine.org/license
- **Python 3 / stdlib** (только для инструментария сборки, не поставляется
  с игрой) — PSF License.

## 5. Ревизия 2 (модели из интернета, P0-фиксы)

- Монстр: FBX «Skeleton Monster» (Quaternius, CC0) вместо капсулы-заглушки.
  Материал — бледный StandardMaterial3D с лёгким эмиссией-самосвечением,
  чтобы силуэт читался в темноте (правило читаемости силуэта).
- Все архитектурные поверхности — PBR-текстуры Poly Haven (CC0) с triplanar-UV:
  бетон не блестит (roughness из ARM-канала G), металл — rough+metallic из arm.
