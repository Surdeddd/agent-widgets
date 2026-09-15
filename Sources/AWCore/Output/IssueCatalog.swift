// swiftlint:disable line_length
import AWSchema

public struct IssueExplanation: Codable, Equatable, Sendable {
    public var code: String
    public var title: LocalizedText
    public var cause: LocalizedText
    public var fix: LocalizedText
    public var example: String?
}

public enum IssueCatalog {
    public static var entries: [IssueExplanation] {
        catalogEntries
    }

    public static func explain(_ code: String) -> IssueExplanation? {
        let wanted = code.uppercased().replacingOccurrences(of: "-", with: "_")
        return catalogEntries.first { $0.code == wanted }
    }

    public static func render(_ entry: IssueExplanation) -> String {
        var lines = [
            "\(entry.code) — \(entry.title.localized)",
            L10n.pick(en: "Why: ", ru: "Почему: ") + entry.cause.localized,
            L10n.pick(en: "Fix: ", ru: "Как чинить: ") + entry.fix.localized
        ]
        if let example = entry.example {
            lines.append(L10n.pick(en: "Example:", ru: "Пример:"))
            lines += example.split(separator: "\n", omittingEmptySubsequences: false).map { "    \($0)" }
        }
        return lines.joined(separator: "\n")
    }
}

private func text(_ en: String, _ ru: String) -> LocalizedText {
    LocalizedText(en: en, ru: ru)
}

private let catalogEntries: [IssueExplanation] = [
    IssueExplanation(
        code: IssueCode.overflow,
        title: text("Content does not fit the widget", "Содержимое не влезает в виджет"),
        cause: text(
            "The laid-out content needs more room than the family has inside its padding, or spills past the edge. WidgetKit clips it.",
            "Свёрстанному содержимому нужно больше места, чем есть в размере внутри полей, или оно вылезает за край. WidgetKit его обрежет."
        ),
        fix: text(
            "Start with the tallest parts the message names. Show less in smaller families: branch on @Environment(\\.aw).family, cap lists with AWList(maxRows:), drop secondary lines. Name your own views with .awBlock(\"…\") to see them in the message.",
            "Начни с самых высоких частей из сообщения. Показывай меньше в маленьких размерах: ветвись по @Environment(\\.aw).family, ограничь AWList(maxRows:), убери второстепенные строки. Свои вьюхи подпиши .awBlock(\"…\"), чтобы видеть их в сообщении."
        ),
        example: "if context.family == .small {\n    AWMetric(value, unit: unit)\n} else {\n    AWMetric(value, unit: unit, label: caption)\n    AWSparkline(history)\n}"
    ),
    IssueExplanation(
        code: IssueCode.truncation,
        title: text("Text is cut off", "Текст обрезан"),
        cause: text(
            "An AWText does not fit its line limit even at its minimum scale, so it would end with an ellipsis. Error in the default sample.",
            "AWText не влезает в свои строки даже на минимальном масштабе и закончится многоточием. В default-сэмпле это ошибка."
        ),
        fix: text(
            "Shorten the text for that family, allow another line with lines:, use a smaller role, or make the feed send a shorter label.",
            "Сократи текст для этого размера, дай ещё строку через lines:, возьми роль поменьше или пусть feed шлёт короткую подпись."
        ),
        example: "AWText(data.title, .headline, lines: context.isSmall ? 2 : 1)"
    ),
    IssueExplanation(
        code: IssueCode.decode,
        title: text("Data does not match the model", "Данные не совпадают с моделью"),
        cause: text(
            "A sample, feed output or aw data set JSON cannot be decoded into the Codable model: a key is missing, misspelled or has another type.",
            "JSON сэмпла, вывода feed или aw data set не декодируется в Codable-модель: ключа нет, он с опечаткой или другого типа."
        ),
        fix: text(
            "Make keys and types match; make fields optional (let x: T?) when data may omit them. Dates: ISO 8601 strings or epoch seconds.",
            "Приведи ключи и типы к модели; поля, которых может не быть, делай опциональными (let x: T?). Даты — ISO 8601 или секунды epoch."
        ),
        example: "struct Weather: Codable, Sendable { let city: String; let temp: Double }\n{\"city\": \"Bangkok\", \"temp\": 31.5}"
    ),
    IssueExplanation(
        code: IssueCode.tinyText,
        title: text("Text is too small to read", "Текст слишком мелкий"),
        cause: text("Text shrinks below about 10 pt at its minimum scale; nobody reads that on a desktop.", "Текст ужимается мельче ~10 pt; на столе такое не читается."),
        fix: text("Use fewer words, a larger AWTextRole, or give the text more room.", "Меньше слов, роль AWTextRole покрупнее или больше места под текст."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.emptyScenario,
        title: text("The empty state is broken", "Пустое состояние сломано"),
        cause: text(
            "The empty sample renders nothing useful. Right after install a widget has no data until its first feed run.",
            "Пустой сэмпл рисует пустоту. Сразу после установки у виджета нет данных до первого прогона feed."
        ),
        fix: text(
            "Wrap the content in AWPhaseView(entry) — it draws waiting, stale and error states. Keep samples/empty.json as null to preview it.",
            "Оберни содержимое в AWPhaseView(entry) — он рисует ожидание, устаревание и ошибку. Держи samples/empty.json со значением null."
        ),
        example: "AWPhaseView(entry) { data in\n    AWMetric(\"\\(data.value)\")\n}"
    ),
    IssueExplanation(
        code: IssueCode.unrenderable,
        title: text("A control cannot be rendered", "Контрол не отрисовывается"),
        cause: text(
            "AppKit-backed SwiftUI controls such as Gauge render as a placeholder outside a real widget, so the preview cannot show them.",
            "SwiftUI-контролы на AppKit вроде Gauge вне настоящего виджета рисуются заглушкой — превью их не покажет."
        ),
        fix: text("Use kit components: AWRing, AWGauge, AWBar, AWButton.", "Бери компоненты кита: AWRing, AWGauge, AWBar, AWButton."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.manifestInvalid,
        title: text("widget.json or aw.json breaks a rule", "widget.json или aw.json нарушает правило"),
        cause: text(
            "Ids are lowercase letters, digits and dashes; view names a Swift type; families are not empty; feed.every is at least 60 s; "
                + "the App Group starts with the Team ID.",
            "id — строчные буквы, цифры и дефис; view — имя Swift-типа; families не пустой; feed.every не меньше 60 с; App Group начинается с Team ID."
        ),
        fix: text("Fix the field named in the message; the hint shows the expected form.", "Исправь поле из сообщения; подсказка показывает нужную форму."),
        example: "{\"id\": \"weather\", \"name\": {\"en\": \"Weather\", \"ru\": \"Погода\"}, \"families\": [\"small\", \"medium\"], \"view\": \"WeatherView\","
            + "\n \"feed\": {\"command\": \"./feed.py\", \"every\": \"30m\"}}"
    ),
    IssueExplanation(
        code: IssueCode.duplicateKind,
        title: text("Two widgets share a kind", "У двух виджетов один kind"),
        cause: text("WidgetKit tells widgets apart by kind; with duplicates one disappears from the gallery.", "WidgetKit различает виджеты по kind; при дубле один пропадёт из галереи."),
        fix: text("Drop the explicit \"kind\" (the default is aw.<id>) or make it unique.", "Убери явный \"kind\" (по умолчанию aw.<id>) или сделай его уникальным."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.budgetRisk,
        title: text("The feed refreshes too often", "Feed обновляется слишком часто"),
        cause: text(
            "macOS gives a widget roughly 40–70 reloads a day; faster than every 15 minutes gets throttled and looks stale.",
            "macOS даёт виджету примерно 40–70 перезагрузок в сутки; чаще раза в 15 минут — придушат, и данные будут выглядеть устаревшими."
        ),
        fix: text(
            "Use every 15m or slower. Clocks and countdowns: AWClock, AWCountdown, Text(date, style:). Known future values: a timeline.",
            "Ставь every от 15m. Часы и отсчёты — AWClock, AWCountdown, Text(date, style:). Известные заранее значения — timeline."
        ),
        example: "{\"timeline\": [{\"date\": \"2026-09-14T09:00:00Z\", \"data\": {\"temp\": 30}}, {\"date\": \"2026-09-14T10:00:00Z\", \"data\": {\"temp\": 31}}]}"
    ),
    IssueExplanation(
        code: IssueCode.missingDefaultSample,
        title: text("No samples/default.json", "Нет samples/default.json"),
        cause: text("Previews, the gallery placeholder and the dev slot all start from the default sample.", "Превью, заглушка в галерее и dev-слот начинаются с default-сэмпла."),
        fix: text("Add samples/default.json shaped like the model; add long.json and empty.json for edge cases.", "Добавь samples/default.json в форме модели; для краёв — long.json и empty.json."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.workspaceNotFound,
        title: text("Not inside a workspace", "Не внутри workspace"),
        cause: text("aw looks for aw.json in the current folder and its parents.", "aw ищет aw.json в текущей папке и выше."),
        fix: text("cd into the workspace, pass --workspace <path>, or create one with aw init.", "Перейди в workspace, передай --workspace <путь> или создай его через aw init."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.workspaceExists,
        title: text("The workspace already exists", "Workspace уже есть"),
        cause: text("aw init found aw.json and will not overwrite it.", "aw init нашёл aw.json и не станет его перезаписывать."),
        fix: text("Add widgets with aw new; refresh signing with aw init --refresh-signing.", "Добавляй виджеты через aw new; подпись обновит aw init --refresh-signing."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.engineNotFound,
        title: text("Engine files are missing", "Нет файлов движка"),
        cause: text("aw needs its Templates and Kit folders next to the binary.", "aw нужны папки Templates и Kit рядом с бинарём."),
        fix: text("Reinstall with make install from the agent-widgets checkout, or set AW_HOME to it.", "Переустанови через make install из папки agent-widgets или укажи на неё AW_HOME."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.invalidJSON,
        title: text("JSON cannot be read", "JSON не читается"),
        cause: text("A JSON file is malformed or has an unexpected shape.", "JSON-файл битый или неожиданной формы."),
        fix: text("Fix it at the reported place; python3 -m json.tool <file> shows syntax errors.", "Исправь в указанном месте; python3 -m json.tool <файл> покажет синтаксис."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.invalidArgument,
        title: text("A tool argument is wrong", "Неверный аргумент инструмента"),
        cause: text(
            "An MCP tool got an argument it does not know, a value of the wrong type, or no value for a required argument.",
            "MCP-инструмент получил неизвестный аргумент, значение не того типа или не получил обязательный."
        ),
        fix: text(
            "Use the names and types from the tool's input schema — ids, names and samples are strings, flags are booleans, "
                + "timeouts are numbers, families and scenarios are arrays of strings.",
            "Бери имена и типы из схемы аргументов инструмента — id, имена и сэмплы это строки, флаги — булевы, "
                + "таймауты — числа, families и scenarios — массивы строк."
        ),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.signingMissing,
        title: text("No signing identity", "Нет подписи"),
        cause: text(
            "Previews work without a certificate. Only build, install and ship sign the app.",
            "Превью работает без сертификата. Подпись нужна только build, install и ship."
        ),
        fix: text(
            "Xcode → Settings → Accounts → + Apple ID (free is fine, no paid membership) "
                + "→ Manage Certificates → + Apple Development, then aw init --refresh-signing.",
            "Xcode → Settings → Accounts → + Apple ID (бесплатный подойдёт, платная подписка не нужна) "
                + "→ Manage Certificates → + Apple Development, затем aw init --refresh-signing."
        ),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.toolMissing,
        title: text("A required tool is missing or failed", "Нужный инструмент не найден или упал"),
        cause: text("Xcode, XcodeGen or another tool is not installed, not selected, or exited with an error.", "Xcode, XcodeGen или другой инструмент не стоит, не выбран или упал."),
        fix: text(
            "Run aw doctor; brew install xcodegen; sudo xcode-select -s /Applications/Xcode.app.",
            "Запусти aw doctor; brew install xcodegen; sudo xcode-select -s /Applications/Xcode.app."
        ),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.compileError,
        title: text("Swift does not compile", "Swift не компилируется"),
        cause: text("The widget's Swift code has an error; the message points at the file and line.", "В Swift-коде виджета ошибка; сообщение указывает файл и строку."),
        fix: text(
            "Fix that line. Import only AWKit and SwiftUI; the view conforms to AWView and has init(entry: AWEntry<Model>).",
            "Исправь эту строку. Импортируй только AWKit и SwiftUI; вьюха реализует AWView и имеет init(entry: AWEntry<Model>)."
        ),
        example: "struct WeatherView: AWView {\n    let entry: AWEntry<Weather>\n    init(entry: AWEntry<Weather>) { self.entry = entry }\n    var body: some View { ... }\n}"
    ),
    IssueExplanation(
        code: IssueCode.buildError,
        title: text("The app build failed", "Сборка приложения упала"),
        cause: text(
            "xcodebuild failed. Errors in .aw/build files usually mean \"view\" in widget.json names a type that does not exist.",
            "xcodebuild упал. Ошибки в файлах .aw/build обычно значат, что \"view\" в widget.json называет несуществующий тип."
        ),
        fix: text("Read the file:line in the message, then .aw/logs/build.log; aw build --no-sign checks code without signing.", "Смотри file:line в сообщении и .aw/logs/build.log; aw build --no-sign проверит код без подписи."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.installFailed,
        title: text("Install problem", "Проблема установки"),
        cause: text(
            "The app could not be copied, launched or registered, or its App Group container did not appear.",
            "Приложение не скопировалось, не запустилось или не зарегистрировалось, либо не появился контейнер App Group."
        ),
        fix: text("Run aw doctor; aw install --hard restarts chronod; aw rollback brings back the previous app.", "Запусти aw doctor; aw install --hard перезапустит chronod; aw rollback вернёт прошлое приложение."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.screenRecordingDenied,
        title: text("No Screen Recording access", "Нет доступа к записи экрана"),
        cause: text(
            "Capturing real widget windows needs Screen Recording for the app that runs aw (Terminal, iTerm, the agent app).",
            "Чтобы снимать реальные окна виджетов, приложению, из которого запущен aw (Терминал, iTerm, агент), нужна запись экрана."
        ),
        fix: text(
            "System Settings → Privacy & Security → Screen Recording → enable that app, then restart it.",
            "Системные настройки → Конфиденциальность и безопасность → Запись экрана → включи это приложение и перезапусти его."
        ),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.widgetNotPlaced,
        title: text("The widget is not on the desktop", "Виджета нет на столе"),
        cause: text(
            "Real screenshots need the widget or the dev slot on the desktop, and only a person can place widgets.",
            "Для реальных снимков виджет или dev-слот должен стоять на столе, а ставить виджеты может только человек."
        ),
        fix: text(
            "Ask the user once: right-click the desktop → Edit Widgets → search the app name → add “<App> · Dev” in medium and large. "
                + "After that aw dev and aw ship switch it to any widget.",
            "Попроси пользователя один раз: правый клик по столу → «Изменить виджеты» → найди приложение → добавь «<App> · Dev» в medium и large. "
                + "Дальше aw dev и aw ship сами переключают его на любой виджет."
        ),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.slotTimeout,
        title: text("The dev slot did not appear in time", "Dev-слот не появился вовремя"),
        cause: text(
            "aw slot waited for the person to put the dev slot on the desktop, and the window did not show up before the timeout.",
            "aw slot ждал, пока человек поставит dev-слот на стол, и окно не появилось до истечения времени."
        ),
        fix: text(
            "Right-click the desktop → Edit Widgets → search the app name → add “<App> · Dev” in the requested sizes, "
                + "then run aw slot again if it already timed out.",
            "Правый клик по столу → «Изменить виджеты» → найди приложение → добавь «<App> · Dev» в нужных размерах "
                + "и снова запусти aw slot, если ожидание уже кончилось."
        ),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.shotUnchanged,
        title: text("The widget did not redraw", "Виджет не перерисовался"),
        cause: text(
            "After the install the dev slot looked the same for the whole wait: the change was not visual, or macOS has not redrawn yet.",
            "После установки dev-слот не менялся всё ожидание: правка была невидимой или macOS ещё не перерисовала."
        ),
        fix: text("Wait a few seconds and run aw shot --dev; if it stays old, aw install --hard.", "Подожди пару секунд и запусти aw shot --dev; если осталось старое — aw install --hard."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.shipUnverified,
        title: text("Nobody has seen the widget on the desktop", "Виджет на столе никто не видел"),
        cause: text(
            "Ship installed the widget without a screenshot of the real desktop window, so nobody has checked how it looks.",
            "Ship установил виджет, но снимка реального окна на столе нет — как он выглядит, никто не проверял."
        ),
        fix: text(
            "Put the dev slot (“<App> · Dev”) on the desktop (right-click → Edit Widgets) and run aw shot --dev. sheet.png is not enough.",
            "Поставь dev-слот («<App> · Dev») на стол (правый клик → «Изменить виджеты») и запусти aw shot --dev. sheet.png недостаточно."
        ),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.widgetExists,
        title: text("The widget id is taken", "id виджета занят"),
        cause: text("widgets/<id> already exists.", "widgets/<id> уже есть."),
        fix: text("Pick another id or edit the existing widget.", "Выбери другой id или правь существующий виджет."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.widgetNotFound,
        title: text("No such widget", "Нет такого виджета"),
        cause: text("The workspace has no widget with that id or kind.", "В workspace нет виджета с таким id или kind."),
        fix: text("aw list shows the ids; aw new <id> creates a widget.", "aw list покажет id; aw new <id> создаст виджет."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.widgetIdInvalid,
        title: text("Widget id is not valid", "Недопустимый id виджета"),
        cause: text(
            "Ids name folders, widget kinds and generated Swift types, so they are lowercase letters, digits and dashes, "
                + "start with a letter, at most 40 characters.",
            "Id даёт имя папке, kind виджета и сгенерированному Swift-типу, поэтому это строчные буквы, цифры и дефис, "
                + "начинается с буквы, не длиннее 40 символов."
        ),
        fix: text(
            "Pick an id like `bangkok-weather` or `cpu-load`; `aw list` shows the ids that exist.",
            "Возьми id вроде `bangkok-weather` или `cpu-load`; `aw list` покажет те, что уже есть."
        ),
        example: "aw new bangkok-weather --template metric"
    ),
    IssueExplanation(
        code: IssueCode.templateUnknown,
        title: text("No such template", "Нет такого шаблона"),
        cause: text("The template name is not in the engine's Templates folder.", "Такого шаблона нет в папке Templates движка."),
        fix: text("aw templates lists them: metric, list, ring, chart, card, image, timer, blank.", "aw templates покажет список: metric, list, ring, chart, card, image, timer, blank."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.scenarioNotFound,
        title: text("No such sample", "Нет такого сэмпла"),
        cause: text("The widget has no samples/<name>.json.", "У виджета нет samples/<имя>.json."),
        fix: text("Use one of the listed samples or add the file.", "Возьми один из перечисленных сэмплов или добавь файл."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.feedFailed,
        title: text("The feed failed", "Feed упал"),
        cause: text(
            "The feed exited with a non-zero code or could not start. The widget keeps the last good data and marks it stale.",
            "Feed завершился с ненулевым кодом или не запустился. Виджет держит последние хорошие данные и помечает их устаревшими."
        ),
        fix: text("Run aw feed run <id> and read aw logs <id>; print logs to stderr and only JSON to stdout.", "Запусти aw feed run <id> и прочитай aw logs <id>; логи — в stderr, в stdout только JSON."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.feedTimeout,
        title: text("The feed timed out", "Feed не уложился во время"),
        cause: text("The feed ran longer than feed.timeout (60 s by default) and was stopped.", "Feed работал дольше feed.timeout (по умолчанию 60 с) и был остановлен."),
        fix: text("Make it faster (cache, fewer requests) or raise feed.timeout, for example \"2m\".", "Ускорь его (кэш, меньше запросов) или подними feed.timeout, например \"2m\"."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.feedInvalidOutput,
        title: text("The feed printed something that is not JSON", "Feed напечатал не JSON"),
        cause: text("stdout must be exactly one JSON object: the model itself or a timeline envelope.", "stdout должен быть ровно одним JSON-объектом: сама модель или конверт timeline."),
        fix: text("Print once with json.dumps(...) at the end; send every log line to stderr.", "Печатай один раз через json.dumps(...) в конце; все логи — в stderr."),
        example: "import json, sys\nprint(\"fetching…\", file=sys.stderr)\nprint(json.dumps({\"city\": \"Bangkok\", \"temp\": 31.5}))"
    ),
    IssueExplanation(
        code: IssueCode.staleData,
        title: text("The data is stale", "Данные устарели"),
        cause: text(
            "The last successful feed run is older than twice the refresh interval, or the last run failed; the widget shows a stale badge.",
            "Последний успешный прогон feed старше двух интервалов обновления или последний прогон упал; виджет показывает значок устаревания."
        ),
        fix: text("Read aw logs <id> and check the daemon with aw daemon status.", "Смотри aw logs <id> и проверь daemon: aw daemon status."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.geometryUnknown,
        title: text("Desktop widget sizes are unknown", "Размеры виджетов на столе неизвестны"),
        cause: text(
            "Widget sizes depend on the display. aw reads them from the system log of chronod; without a measurement previews use built-in sizes that can differ from the desktop by 10 pt.",
            "Размеры виджетов зависят от экрана. aw читает их из системного лога chronod; без замера превью рисует по встроенным размерам, а они могут отличаться от стола на 10 pt."
        ),
        fix: text("Put any widget on the desktop, then run aw geometry --measure.", "Поставь любой виджет на стол и запусти aw geometry --measure."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.shotMismatch,
        title: text("The desktop widget does not match its preview", "Виджет на столе не совпадает с превью"),
        cause: text(
            "aw compares the real window with the closest preview cell: the size in points and the outlines of text and shapes. "
                + "Colors are ignored because the desktop tints widgets with the wallpaper.",
            "aw сравнивает настоящее окно с ближайшей ячейкой превью: размер в пунктах и контуры текста и фигур. "
                + "Цвет не сравнивается — стол тонирует виджеты обоями."
        ),
        fix: text(
            "Open the compare image (preview, desktop, outlines). A size gap needs aw geometry --measure and a new preview; "
                + "different outlines mean the widget shows other data or state than the sample.",
            "Открой картинку сравнения (превью, стол, контуры). Разница в размере — aw geometry --measure и новое превью; "
                + "разные контуры — виджет показывает другие данные или состояние, чем сэмпл."
        ),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.feedCommandNotFound,
        title: text("The feed command cannot be run", "Команду feed не запустить"),
        cause: text(
            "The shell could not find the program (exit 127) or was not allowed to run it (exit 126). Feeds run through /bin/zsh -c "
                + "with PATH=/opt/homebrew/bin:/usr/local/bin:~/.local/bin plus the PATH aw itself got — not your interactive shell profile.",
            "Оболочка не нашла программу (код 127) или ей не дали её запустить (код 126). Feed идёт через /bin/zsh -c "
                + "с PATH=/opt/homebrew/bin:/usr/local/bin:~/.local/bin плюс PATH самого aw — без профиля твоей оболочки."
        ),
        fix: text(
            "Install the program or put its full path in widget.json; make scripts executable with chmod +x or call them through the interpreter.",
            "Установи программу или впиши полный путь в widget.json; скрипты сделай исполняемыми (chmod +x) или вызывай через интерпретатор."
        ),
        example: "\"feed\": {\"command\": \"/opt/homebrew/bin/python3 feed.py\", \"every\": \"30m\"}"
    ),
    IssueExplanation(
        code: IssueCode.feedSecretMissing,
        title: text("A feed secret has no value", "У секрета feed нет значения"),
        cause: text(
            "widget.json lists the secret in feed.secrets, but aw.local.json has no value for it, so the feed is not started.",
            "widget.json перечисляет секрет в feed.secrets, но в aw.local.json для него нет значения, поэтому feed не запускается."
        ),
        fix: text(
            "Put the value into \"secrets\" in aw.local.json. The feed gets it as an environment variable of the same name.",
            "Положи значение в \"secrets\" в aw.local.json. Feed получит его переменной окружения с тем же именем."
        ),
        example: "aw.local.json: {\"secrets\": {\"GITHUB_TOKEN\": \"ghp_…\"}}\nwidget.json: \"feed\": {\"command\": \"python3 feed.py\", \"every\": \"30m\", \"secrets\": [\"GITHUB_TOKEN\"]}"
    ),
    IssueExplanation(
        code: IssueCode.secretsInConfig,
        title: text("Secrets are in aw.json", "Секреты лежат в aw.json"),
        cause: text(
            "aw.json describes the workspace and goes to git with it; tokens there leak with the repository.",
            "aw.json описывает workspace и уходит в git вместе с ним; токены в нём утекут с репозиторием."
        ),
        fix: text(
            "Move \"secrets\" to aw.local.json, which is machine-specific and git-ignored.",
            "Перенеси \"secrets\" в aw.local.json — он у каждой машины свой и в git не попадает."
        ),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.sampleNotLocalized,
        title: text("No Russian sample for a feed widget", "Нет русского сэмпла у виджета с feed"),
        cause: text(
            "The preview in Russian uses samples/default.json, so text that the feed writes in Russian (AW_LANG=ru) is never checked for fit.",
            "Русское превью берёт samples/default.json, и текст, который feed пишет по-русски (AW_LANG=ru), на влезание не проверяется."
        ),
        fix: text(
            "Run the feed with AW_LANG=ru and save its output as samples/default.ru.json.",
            "Запусти feed с AW_LANG=ru и сохрани его вывод в samples/default.ru.json."
        ),
        example: "cd widgets/weather && AW_LANG=ru python3 feed.py > samples/default.ru.json"
    ),
    IssueExplanation(
        code: IssueCode.daemonMissing,
        title: text("Feeds are not scheduled", "Feed не запланированы"),
        cause: text(
            "Some widgets have feeds, but no LaunchAgent runs them, so data only changes when you run aw feed run.",
            "У виджетов есть feed, но их не запускает LaunchAgent — данные меняются только от ручного aw feed run."
        ),
        fix: text("aw daemon install.", "aw daemon install."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.keptExisting,
        title: text("An existing file was kept", "Существующий файл оставлен"),
        cause: text("aw init found the file already there and did not overwrite it.", "aw init нашёл файл и не стал его перезаписывать."),
        fix: text("Nothing to do; merge the template by hand if you want its content.", "Ничего делать не нужно; содержимое шаблона при желании перенеси руками."),
        example: nil
    ),
    IssueExplanation(
        code: IssueCode.previewCrashed,
        title: text("The preview renderer crashed", "Рендер превью упал"),
        cause: text(
            "The preview binary exited without a report, usually because the view crashed: a force unwrap, an index out of range, a fatalError.",
            "Бинарь превью вышел без отчёта — обычно упала сама вьюха: force unwrap, выход за границы массива, fatalError."
        ),
        fix: text("Read the output tail in the hint; guard optionals and indexes in the view.", "Смотри хвост вывода в подсказке; проверяй опционалы и индексы во вьюхе."),
        example: nil
    )
]
// swiftlint:enable line_length
