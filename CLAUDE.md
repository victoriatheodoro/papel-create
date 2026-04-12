# Papel & Create — CLAUDE.md

## Visão geral

Aplicativo Flutter da marca **Papel & Create** que digitaliza páginas de cadernos físicos via OCR (Gemini API), extrai tarefas e eventos estruturados, e os organiza em grupos. Roda como **web app** (Flutter Web).

---

## Como rodar

```bash
# Build (SEMPRE usar estas flags — veja seção "Armadilhas conhecidas")
cd H:\Claude\Papelaria\analog_sync_project
powershell.exe -Command "& 'C:\Users\jhona\.puro\envs\stable\flutter\bin\flutter.bat' build web --no-tree-shake-icons --release --pwa-strategy=none"

# Servidor local (após o build)
powershell.exe -Command "Start-Process python -ArgumentList '-m http.server 8080' -WorkingDirectory 'H:\Claude\Papelaria\analog_sync_project\build\web'"
# Acesse: http://localhost:8080

# Primeira vez ou após troca de dependências: limpar cache do build antes
rm -rf .dart_tool/flutter_build
powershell.exe -Command "& 'C:\Users\jhona\.puro\envs\stable\flutter\bin\flutter.bat' pub get"
```

> **Teste em aba anônima** na primeira abertura após um novo build para evitar interferência de service worker antigo no cache do browser.

---

## Estrutura de arquivos

```
lib/
├── main.dart                        # Ponto de entrada, rotas, tema
├── models/
│   ├── scan_result.dart             # TaskItem, EventItem, ScanResult
│   └── activity_group.dart          # ActivityGroup (grupos/blocos)
├── screens/
│   ├── splash_screen.dart           # Splash: logo sobre fundo escuro por 2s
│   ├── home_screen.dart             # Tela principal: logo, "Vencendo", grupos, entrada manual
│   ├── group_detail_screen.dart     # Detalhe de um grupo: tarefas e eventos
│   ├── review_screen.dart           # Revisão de scan antes de salvar
│   ├── history_screen.dart          # Histórico de scans
│   └── settings_screen.dart        # Configurações (API key)
└── services/
    ├── ocr_service.dart             # Fachada com import condicional
    ├── ocr_service_web.dart         # OCR via Gemini API (web)
    └── ocr_service_mobile.dart      # OCR via ML Kit (mobile — não usado na web)

assets/
└── images/
    └── logo.png                     # Logo Papel & Create (PNG com fundo transparente)
```

---

## Identidade visual

### Paleta de cores (Pantone)
| Pantone | Hex | Uso |
|---|---|---|
| P 1-1 C | `#F9F7F0` | Fundo scaffold e AppBar (creme claro) |
| 0331 C (rosa) | `#F4A7C7` | Botão "Tarefa" selecionado, acentos rosa |
| 0631 C (roxo) | `#C17FD4` | Botões primários (Salvar, Criar), badges de pendentes, chips selecionados |

Texto principal: `#2D2D2D` (escuro neutro).

### Logo
- Arquivo: `assets/images/logo.png` (PNG com fundo transparente)
- Fonte original: `H:\Claude\Papelaria\Papel e create\papel logo transparente.png`
- Exibido no corpo da `HomeScreen` (220px de largura, centralizado, acima dos cards)
- Também usado como favicon e ícones web (`web/favicon.png`, `web/icons/`)

### Splash screen
- Fundo escuro `#1A1A1A`, logo centralizado (260px)
- Navega para `/` após 2 segundos

---

## Modelos principais

### `TaskItem` (`scan_result.dart`)
| Campo | Tipo | Descrição |
|---|---|---|
| `id` | `String` | UUID gerado automaticamente |
| `text` | `String` | Texto da tarefa |
| `completed` | `bool` | Tarefa concluída |
| `priority` | `bool` | Prioridade alta (`!`) |
| `inProgress` | `bool` | Em andamento (`~`) |
| `dueDate` | `DateTime?` | Prazo (null = sem prazo) |

### `EventItem` (`scan_result.dart`)
| Campo | Tipo | Descrição |
|---|---|---|
| `id` | `String` | UUID |
| `text` | `String` | Descrição do evento |
| `date` | `String?` | Data em `dd/mm/aaaa` |
| `time` | `String?` | Hora em `HH:mm` |

### `ScanResult` (`scan_result.dart`)
| Campo | Tipo | Descrição |
|---|---|---|
| `id` | `String` | UUID |
| `imagePaths` | `List<String>` | Paths/URLs das imagens (vazio = criado manualmente) |
| `tasks` | `List<TaskItem>` | Tarefas extraídas |
| `events` | `List<EventItem>` | Eventos extraídos |
| `rawText` | `String` | Texto bruto do parser |
| `scannedAt` | `DateTime` | Data/hora do scan |
| `groupId` | `String?` | ID do grupo (null = Geral) |

### `ActivityGroup` (`activity_group.dart`)
| Campo | Tipo | Descrição |
|---|---|---|
| `id` | `String` | UUID |
| `name` | `String` | Nome do grupo (mutável) |

---

## Persistência (SharedPreferences / localStorage)

| Chave | Conteúdo |
|---|---|
| `scan_history` | JSON de `List<ScanResult>` |
| `activity_groups` | JSON de `List<ActivityGroup>` |
| `gemini_api_key` | String da API key do Gemini |

---

## Rotas (`main.dart`)

| Rota | Widget | Argumentos |
|---|---|---|
| `/splash` | `SplashScreen` | — (rota inicial) |
| `/` | `HomeScreen` | — |
| `/review` | `ReviewScreen` | `Map<String, dynamic>` com `result: ScanResult` e `groups: List<ActivityGroup>` |

---

## OCR (Gemini API)

- **Modelo:** `gemini-2.0-flash`
- **Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=API_KEY`
- **Arquivo:** `lib/services/ocr_service_web.dart`
- A API key é lida do SharedPreferences (`gemini_api_key`) em cada chamada
- Erros tratados: `400` → API key inválida, `429` → lança `Exception('RATE_LIMIT: ...')`

### Símbolos reconhecidos no caderno

| Símbolo | Significado |
|---|---|
| `[ ]` | Tarefa pendente |
| `[x]` | Tarefa concluída |
| `( )` | Evento |
| `!` | Prioridade alta |
| `~` | Em andamento |

---

## Padrões importantes

### Toggle de tarefa
O toque no ícone alterna apenas `completed`. O campo `inProgress` **nunca** é alterado pelo toggle — somente pelo dialog de edição (toque longo na tarefa em `GroupDetailScreen`).

### Edição de tarefa (toque longo)
Bottom sheet com: texto editável, 3 botões de status (Pendente / Andamento / Concluída), toggle de prioridade, date picker de prazo, e seletor "Mover para grupo".

### Mover tarefa entre grupos
Em `GroupDetailScreen`, o bottom sheet de edição (toque longo) exibe chips de grupos. Selecionar outro grupo e salvar chama `_moveTask()`, que remove a tarefa do `ScanResult` pai e cria um novo `ScanResult` no grupo destino. `GroupDetailScreen` recebe `groups: List<ActivityGroup>` como parâmetro obrigatório.

### Criação manual
Scans criados manualmente têm `imagePaths: []`. O cabeçalho exibido em `GroupDetailScreen` é "Criado manualmente". O seletor de grupo aparece **sempre** (mesmo sem grupos criados) e inclui o chip `+ Criar grupo` que abre um AlertDialog inline sem sair do sheet.

### Callback `onSave` / `onAddManual`
`GroupDetailScreen` recebe `history` por referência. Após mutações, chama `widget.onSave()` para persistir. O botão `+` chama `widget.onAddManual(groupId)` → pop → `HomeScreen` abre o sheet de criação manual com grupo pré-selecionado.

### Seção "Vencendo" (`home_screen.dart`)
Aparece acima dos cards quando há tarefas não concluídas com `dueDate != null` e `dueDate <= hoje`. Calculada via getter `_overdueTasks`. Card com fundo vermelho claro.

### Prazo de tarefa (`dueDate`)
Badge abaixo do texto da tarefa em `GroupDetailScreen`: vermelho = vencida, laranja = vence hoje, cinza = futura. Disponível também na criação manual e na tela de revisão.

### Parser de data no scan (`ocr_service.dart`)
Após extrair o texto de cada tarefa, o método `_extractDueDate()` aplica regex `\s*-\s*(\d{1,2}/\d{1,2}(?:/\d{2,4})?)$` para detectar sufixo de data. Se encontrar, remove o sufixo do texto e popula `dueDate`. O prompt do Gemini (`ocr_service_web.dart`) instrui o modelo a preservar o sufixo `- dd/mm/aaaa` no campo `text` das tarefas.

### Galeria no Flutter Web (`home_screen.dart`)
`pickImage()` deve ser a **primeira** operação `await` dentro de `_scan()` — antes de qualquer outro await (incluindo `_checkApiKey()`). O browser só abre o seletor de arquivos em resposta direta a um gesto do usuário; qualquer `await` intermediário quebra o "trusted event context" e o seletor é silenciosamente bloqueado.

---

## Dependências relevantes

| Pacote | Versão (lock) | Uso |
|---|---|---|
| `shared_preferences` | 2.5.5 | Persistência local (localStorage no web via `shared_preferences_web` 2.4.3) |
| `image_picker` | — | Seleção de imagens (câmera / galeria) |
| `http` | — | Chamadas à API do Gemini |
| `uuid` | — | Geração de IDs únicos nos modelos |
| `intl` | 0.19.0 | Formatação de datas (`DateFormat`) |

---

## Armadilhas conhecidas

### `MissingPluginException` para `shared_preferences` no Flutter Web
**Causa:** A pasta de cache do build de release em `.dart_tool/flutter_build/<hash>/` pode ter um `web_plugin_registrant.dart` desatualizado (gerado antes de `shared_preferences` ser adicionado ao `pubspec.yaml`). O build incremental reutiliza essa pasta sem regenerar o registrante, então `SharedPreferencesPlugin.registerWith(registrar)` nunca é chamado — o fallback de MethodChannel é usado e não há handler no web, resultando na exceção.

**Fix:** Apagar `.dart_tool/flutter_build` inteiro antes de rebuildar:
```bash
rm -rf .dart_tool/flutter_build
flutter pub get
flutter build web --no-tree-shake-icons --release --pwa-strategy=none
```

### Service worker cacheando versão antiga
**Causa:** Flutter Web registra um service worker que armazena `main.dart.js` em cache. Mesmo após rebuildar, o browser pode servir o JS antigo.

**Fix:** Buildar com `--pwa-strategy=none` gera `flutter_service_worker.js` vazio e remove o `serviceWorkerSettings` do `flutter_bootstrap.js`. Para sessões de browser já abertas com SW ativo, usar **aba anônima** ou unregistrar o SW em DevTools → Application → Service Workers.

### `pickImage()` não abre o seletor de arquivos no web
**Causa:** O browser exige que `pickImage()` seja chamado diretamente no handler de gesto ("trusted event"). Qualquer `await` antes da chamada (ex: `_checkApiKey()`) invalida o contexto e o browser bloqueia silenciosamente.

**Fix:** `pickImage()` deve ser o **primeiro** `await` dentro de `_scan()`.

### `debugPrint` não aparece no console em builds de release
`debugPrint` é no-op em release. Usar `print()` para logs em `FlutterError.onError` e `runZonedGuarded`.
