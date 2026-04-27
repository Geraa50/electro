<div align="center">

# ⚡ Электро ⚡

### 🔌 Образовательная головоломка по сборке электрических цепей 🔌

<img src="electro/icons/icon_172.png" alt="Electro Icon" width="128" />

![Godot](https://img.shields.io/badge/Godot-4.4-478CBF?style=for-the-badge&logo=godotengine&logoColor=white)
![Language](https://img.shields.io/badge/GDScript-%E2%9A%A1-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20Android-success?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

---

🎮 *Собери цепь. Подай напряжение. Зажги лампу!* 💡

</div>

## 🌟 О проекте

**Электро** — это увлекательная обучающая игра-головоломка, в которой игрок собирает электрические схемы на виртуальной макетной плате (breadboard) 🧩. Под капотом работает настоящий **MNA-солвер** (Modified Nodal Analysis) ⚙️, поэтому все цепи рассчитываются по законам Кирхгофа — как в реальной физике! 🔬

### 🎯 Для кого?

- 👨‍🏫 Преподавателям физики и электротехники
- 👨‍🎓 Школьникам и студентам
- 🔧 Всем, кто хочет понять, как работают электрические цепи
- 🎮 Любителям образовательных головоломок

---

## ✨ Возможности

| Возможность | Описание |
|:---:|:---|
| 🔋 | **Источники питания** с настраиваемым напряжением |
| 💡 | **Потребители** (лампы) с цветовой индикацией |
| 🔗 | **Провода** с подсветкой — светятся синим, когда по ним идёт ток ⚡ |
| 🎚️ | **Резисторы** различных номиналов |
| 🔘 | **Выключатели** и **тумблеры** для управления цепью |
| 📟 | **Вольтамперметр** для измерения напряжения и силы тока |
| 🧮 | **MNA-солвер** — точный расчёт цепей любой сложности |
| 🎵 | **Звуковое сопровождение** действий |
| 📚 | **5 уровней** с нарастающей сложностью |

---

## 🗺️ Уровни игры

| № | 🏷️ Название | 🎓 Чему учит |
|:---:|:---|:---|
| 1️⃣ | **Туториал: первая цепь** | Базовое замыкание цепи 🔁 |
| 2️⃣ | **Параллельное соединение** | Распределение тока по веткам 🔀 |
| 3️⃣ | **Измерения** | Работа с вольтамперметром 📏 |
| 4️⃣ | **Переключатели** | Управление потоком тока 🔄 |
| 5️⃣ | **Двойная нагрузка** | Комбинация последовательного и параллельного 🧠 |

---

## 🚀 Запуск

### 📱 Готовые сборки для ОС Аврора

Скачайте готовый RPM-пакет из [**📦 Releases**](https://github.com/Geraa50/electro/releases/latest):

| 🏗️ Архитектура | 📥 Файл |
|:---:|:---|
| 🟢 **aarch64** (64-бит ARM) | [`pmifi.electro-0.5-1.aarch64.rpm`](https://github.com/Geraa50/electro/releases/latest) |
| 🟡 **armv7hl** (32-бит ARM) | [`pmifi.electro-0.5-1.armv7hl.rpm`](https://github.com/Geraa50/electro/releases/latest) |

Установка на устройство с ОС Аврора:

```sh
pkcon install-local pmifi.electro-0.5-1.aarch64.rpm
```

### 💻 Запуск из исходников

**Требования:** 🎮 **Godot Engine 4.4** или новее — [скачать](https://godotengine.org/download)

```bash
# 1. Клонируем репозиторий
git clone https://github.com/Geraa50/electro.git

# 2. Заходим в папку проекта
cd electro/electro

# 3. Открываем project.godot в Godot Engine и жмём F5
```

Или просто запустите Godot, выберите **Import** и укажите `electro/project.godot` 📂

---

## 🏗️ Архитектура

```
electro/
├── 🎨 assets/          # Графика, спрайты, звуки
├── 🖼️ icons/           # Иконки приложения (86, 108, 128, 172 px)
├── 📚 resources/
│   └── levels/         # Уровни как нативные ресурсы Godot (.tres)
├── 🎬 scenes/
│   ├── main_menu/      # Главное меню
│   ├── level_select/   # Выбор уровня
│   ├── game/           # Игровой процесс
│   └── level_complete/ # Экран победы
├── 📜 scripts/
│   ├── autoload/       # GameManager, AudioManager
│   ├── breadboard/     # Макетная плата
│   ├── circuit/        # ⚡ MNA-солвер и граф цепи
│   ├── components/     # Компоненты (батарея, лампа, провод…)
│   ├── level/          # Логика уровня
│   └── ui/             # UI-элементы
├── 🎨 themes/          # Визуальные темы
└── ⚙️ project.godot    # Конфиг проекта
```

---

## 🧩 Формат уровней

Каждый уровень — это нативный Godot-ресурс [`LevelData`](electro/scripts/level/level_data.gd) (`.tres`-файл) 📝. Все уровни жёстко зарегистрированы в [`GameManager`](electro/scripts/autoload/game_manager.gd) через `preload()`, поэтому гарантированно попадают в `.pck` при экспорте — это критично для портов на закрытые ОС вроде **Авроры**, где `DirAccess`/`FileAccess` к произвольным файлам внутри пакета может быть ограничен.

Пример уровня (`electro/resources/levels/01_tutorial.tres`):

```ini
[resource]
script = ExtResource("1")
level_name = "Туториал: первая цепь"
hint = "Соедините «+» и «−» батареи с лампой через провода."
power_count = 1
power_voltages = Array[float]([9.0])
goal_count = 1
goal_voltages = Array[float]([9.0])
allow_wire = true
allow_voltammeter = false
allow_toggle = false
allow_switch = false
resistor_count = 0
resistor_values = Array[float]([])
voltage_tolerance = 1.0
```

💡 *Хотите добавить свой уровень?*

1. В Godot: `resources/levels/` → `New Resource… ▶ LevelData` → заполните поля → сохраните как `06_xxx.tres`.
2. Допишите одну строку `preload("res://resources/levels/06_xxx.tres"),` в массив `levels` в `electro/scripts/autoload/game_manager.gd`.

---

## 🔬 Под капотом: MNA-солвер

Проект использует **Modified Nodal Analysis** — метод расчёта электрических цепей, применяемый в SPICE и других симуляторах 🎓. Для каждого кадра:

1. 📊 Строится граф цепи из компонентов на breadboard
2. 🧮 Составляется матричное уравнение `G·v = i`
3. ⚡ Решается относительно узловых потенциалов
4. 💡 Рассчитываются токи и напряжения на всех элементах
5. 🎨 Обновляется визуализация (подсветка, яркость лампы, стрелки приборов)

---

## 🤝 Вклад в проект

Приветствуются любые идеи и предложения! 🎉

- 🐛 Нашли баг? Откройте [issue](https://github.com/Geraa50/electro/issues)
- 💡 Есть идея? Создайте pull request
- ⭐ Понравилось? Поставьте звезду!

---

## 📜 Лицензия

Проект распространяется под лицензией **MIT** 📄

---

<div align="center">

### 💖 Сделано с любовью к физике и играм 💖

⚡ *«Электричество — это не просто наука, это магия, которую мы научились понимать»* ⚡

🌟 Поставьте ⭐ если проект вам понравился! 🌟

</div>
