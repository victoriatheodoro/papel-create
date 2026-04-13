# Papel & Create — CLAUDE.md

## Visão geral

Aplicativo Flutter da marca **Papel & Create** que digitaliza páginas de cadernos físicos via OCR (Gemini API), extrai tarefas e eventos estruturados, e os organiza em grupos. Roda como **web app** (Flutter Web).

---

## Como rodar

```bash
# Build local (SEMPRE usar estas flags)
cd H:\Claude\Papelaria\analog_sync_project
rm -rf .dart_tool/flutter_build
powershell.exe -Command "& 'C:\Users\jhona\.puro\envs\stable\flutter\bin\flutter.bat' pub get"
powershell.exe -Command "& 'C:\Users\jhona\.puro\envs\stable\flutter\bin\flutter.bat' build web --no-tree-shake-icons --release --pwa-strategy=none"

# Servidor local (após o build)
cd build/web && python -m http.server 8080
# Acesse: http://localhost:8080
```

> **Teste em aba anônima** na primeira abertura após um novo build para evitar interferência de service worker antigo no cache do browser.

## Deploy no GitHub Pages

```bash
# 1. Build com base-href + chave Gemini embutida (OBRIGATÓRIO para GitHub Pages)
# Substitua SUA_CHAVE_AQUI pela chave real (não commitar no repositório!)
powershell.exe -Command "& 'C:\Users\jhona\.puro\envs\stable\flutter\bin\flutter.bat' build web --no-tree-shake-icons --release --pwa-strategy=none '--base-href=/papel-create/' '--dart-define=GEMINI_KEY=SUA_CHAVE_AQUI'"

# 2. Copiar build para FORA do repo (ao trocar branch o build some pois build/ é gitignored)
rm -rf C:/Users/jhona/AppData/Local/Temp/papel-deploy
powershell.exe -Command "Copy-Item -Path 'H:\Claude\Papelaria\analog_sync_project\build\web' -Destination 'C:\Users\jhona\AppData\Local\Temp\papel-deploy' -Recurse -Force"

# 3. Deploy
git stash
git checkout gh-pages
powershell.exe -Command "Copy-Item -Path 'C:\Users\jhona\AppData\Local\Temp\papel-deploy\*' -Destination 'H:\Claude\Papelaria\analog_sync_project' -Recurse -Force"
git add -A
git commit -m "deploy: <descrição>"
git push origin gh-pages
git checkout main
git stash pop
```

- **URL pública:** `https://victoriatheodoro.github.io/papel-create/`
- **Repositório:** `github.com/victoriatheodoro/papel-create`
- Branch `main` = código-fonte | Branch `gh-pages` = build web publicado
- **IMPORTANTE:** build local usa sem `--base-href`; deploy GitHub Pages usa `--base-href '/papel-create/'`. Sem essa flag o app abre em branco no GitHub Pages.

---

## Estrutura de arquivos

```
lib/
├── main.dart                        # Ponto de entrada, rotas, tema, WidgetsFlutterBinding.ensureInitialized()
├── models/
│   ├── scan_result.dart             # TaskItem, EventItem, ScanResult
│   └── activity_group.dart          # ActivityGroup (grupos/blocos)
├── screens/
│   ├── splash_screen.dart           # Splash: logo sobre fundo escuro por 2s → redireciona para /login ou /
│   ├── login_screen.dart            # Login com Google (Firebase Auth) ou continuar sem conta
│   ├── home_screen.dart             # Tela principal: logo, "Vencendo", grupos, busca, sync, AppBar mobile
│   ├── group_detail_screen.dart     # Detalhe de um grupo: tarefas e eventos
│   ├── review_screen.dart           # Revisão de scan antes de salvar
│   ├── history_screen.dart          # Histórico de scans
│   ├── search_screen.dart           # Busca por palavra-chave em tarefas e eventos (ícone lupa na AppBar)
│   └── settings_screen.dart        # Configurações (Gemini API key oculta se embutida, Todoist, logout)
├── services/
│   ├── ocr_service.dart             # Fachada com import condicional
│   ├── ocr_service_web.dart         # OCR via Gemini API (web) — modelo gemini-2.5-flash
│   ├── ocr_service_mobile.dart      # OCR via ML Kit (mobile — não usado na web)
│   ├── auth_service.dart            # Firebase Auth: signInWithPopup(GoogleAuthProvider), signOut
│   ├── firestore_service.dart       # Firestore: load/save de groups e scans por uid
│   └── todoist_service.dart         # Integração Todoist REST API v2 (push/pull bidirecional)
└── widgets/
    ├── mini_calendar.dart           # Mini-calendário flutuante; CalendarEvent (event + groupId + groupName)
    ├── onboarding_overlay.dart      # Tutorial overlay 6 passos (exibido na primeira abertura)
    └── search_screen.dart           # (em lib/screens/) Busca por palavra-chave em tarefas e eventos

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
| `todoistId` | `String?` | ID da tarefa no Todoist (null = não sincronizada) |

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

## Persistência

### SharedPreferences (localStorage no web)
Dados locais por dispositivo/browser.

| Chave | Conteúdo |
|---|---|
| `scan_history` | JSON de `List<ScanResult>` |
| `activity_groups` | JSON de `List<ActivityGroup>` |
| `gemini_api_key` | String da API key do Gemini (ignorada se `GEMINI_KEY` embutida no build) |
| `todoist_token` | String do token pessoal do Todoist |
| `onboarding_done` | `'true'` após o tutorial ser concluído |

### Firestore (sincronização entre dispositivos)
Disponível quando o usuário está logado com Google. Coleções:
- `users/{uid}/groups/{groupId}` — grupos do usuário
- `users/{uid}/scans/{scanId}` — histórico de scans (ordenado por `scannedAt` desc)

**Estratégia de carga (`home_screen.dart`):**
1. Se logado → tenta carregar do Firestore
2. Se Firestore vazio E localStorage tem dados → migra localStorage → Firestore (primeira vez)
3. Se não logado → carrega só do localStorage

**Estratégia de escrita:** salva em localStorage E Firestore simultaneamente quando logado.

---

## Rotas (`main.dart`)

| Rota | Widget | Argumentos |
|---|---|---|
| `/splash` | `SplashScreen` | — (rota inicial) |
| `/login` | `LoginScreen` | — |
| `/` | `HomeScreen` | — |
| `/review` | `ReviewScreen` | `Map<String, dynamic>` com `result: ScanResult` e `groups: List<ActivityGroup>` |

**Fluxo de autenticação:** Splash → verifica `AuthService.isLoggedIn` → se não logado vai para `/login`, se logado vai para `/`. `LoginScreen` oferece "Entrar com Google" (Firebase Auth) e "Continuar sem conta" (vai para `/` sem login).

---

## OCR (Gemini API)

- **Modelo:** `gemini-2.5-flash` (trocado de `gemini-2.0-flash` que foi descontinuado para novas chaves)
- **Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=API_KEY`
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

## Integração Todoist (`todoist_service.dart`)

- **API:** REST v2 — `https://api.todoist.com/rest/v2/`
- **Auth:** `Authorization: Bearer TOKEN` (token salvo em `todoist_token` no SharedPreferences)
- **Push:** tarefas sem `todoistId` são criadas no Todoist; tarefas concluídas com `todoistId` são fechadas
- **Pull:** tarefas ativas do Todoist sem correspondente local são importadas num grupo "Todoist"
- **Botão:** ícone `↻` no AppBar da HomeScreen; mostra spinner enquanto sincroniza
- **Token:** configurado em Configurações → campo "Todoist Token"
  - Obter em: todoist.com → Configurações → Integrações → Token da API

---

## Padrões importantes

### Toggle de tarefa
Ciclo circular de 3 estados via clique no ícone (`group_detail_screen.dart`, `_toggleTask()`):
- **Aberta** (completed=false, inProgress=false) → **Em andamento** (inProgress=true) → **Concluída** (completed=true) → **Aberta**

O campo `inProgress` também pode ser alterado pelo dialog de edição (toque longo).

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

### AppBar mobile (`home_screen.dart`)
Sem título (logo fica no body). Ações: avatar (se logado) → ícone lupa (busca) → menu `⋮` (histórico + sync Todoist) → ícone configurações → ícone `+`. `leadingWidth: 96` com texto "Legenda". Evitar adicionar mais ações — a barra já está compacta no mobile.

### Tutorial de onboarding (`onboarding_overlay.dart`)
6 passos. Exibido na primeira abertura (chave `onboarding_done` no SharedPreferences). Pode ser revisto em Configurações → "Ver tutorial novamente" (remove a chave).

**Posicionamento dos balões:**
- `alignTop: true, verticalFraction: X` → topo do balão em `X * screenHeight` do topo
- `alignTop: false, verticalFraction: X` → fundo do balão em `X * screenHeight` do topo
- Para balões sempre visíveis no mobile (800px, balão ~200px), usar `alignTop: true` com fração entre 0.09 e 0.55

**Spotlights (Alignment → coordenadas na tela 360×800px):**
- `x = W/2 * (1 + dx)`, `y = H/2 * (1 + dy)`
- Botão `+` (AppBar): `Alignment(0.88, -0.86)` → (~338px, ~56px)
- Lupa (AppBar): `Alignment(0.48, -0.86)` → (~266px, ~56px)
- Logo: `Alignment(0, -0.65)` → (180px, ~140px)
- Calendário (bottom-left): `Alignment(-0.60, 0.90)` → (~72px, ~760px)

### Busca (`search_screen.dart`)
Recebe `history: List<ScanResult>` e `groups: List<ActivityGroup>`. Busca em tempo real por `task.text` e `event.text`. Toque no resultado chama `widget.onGroupOpen(group)` após `Navigator.pop()`.

### Galeria no Flutter Web (`home_screen.dart`)
`pickImage()` deve ser a **primeira** operação `await` dentro de `_scan()` — antes de qualquer outro await (incluindo `_checkApiKey()`). O browser só abre o seletor de arquivos em resposta direta a um gesto do usuário; qualquer `await` intermediário quebra o "trusted event context" e o seletor é silenciosamente bloqueado.

---

## Dependências relevantes

| Pacote | Versão (lock) | Uso |
|---|---|---|
| `shared_preferences` | 2.5.5 | Persistência local (localStorage no web via `shared_preferences_web` 2.4.3) |
| `firebase_core` | ^3.6.0 | Inicialização do Firebase (`Firebase.initializeApp`) |
| `firebase_auth` | ^5.3.0 | Autenticação Google via `signInWithPopup` |
| `cloud_firestore` | ^5.4.0 | Sincronização de dados entre dispositivos |
| `image_picker` | — | Seleção de imagens (câmera / galeria) |
| `http` | — | Chamadas à API do Gemini e Todoist |
| `uuid` | — | Geração de IDs únicos nos modelos |
| `intl` | 0.19.0 | Formatação de datas (`DateFormat`) |

**IMPORTANTE:** NÃO usar `google_sign_in` — retorna `null` no Flutter Web. Usar `signInWithPopup(GoogleAuthProvider())` do `firebase_auth` diretamente.

---

## Armadilhas conhecidas

### Tela em branco no GitHub Pages
**Causa:** Build sem `--base-href` faz o app tentar carregar assets de `/` em vez de `/papel-create/`.

**Fix:** Sempre usar `--base-href '/papel-create/'` no build de deploy. Build local não precisa da flag.

### `MissingPluginException` para `shared_preferences` no Flutter Web
**Causa:** Cache desatualizado em `.dart_tool/flutter_build/<hash>/web_plugin_registrant.dart`.

**Fix:**
```bash
rm -rf .dart_tool/flutter_build
flutter pub get
flutter build web --no-tree-shake-icons --release --pwa-strategy=none
```

### Service worker cacheando versão antiga
**Causa:** Flutter Web registra um service worker que armazena `main.dart.js` em cache.

**Fix:** Buildar com `--pwa-strategy=none`. Para sessões já abertas, usar **aba anônima** ou unregistrar o SW em DevTools → Application → Service Workers.

### `pickImage()` não abre o seletor de arquivos no web
**Causa:** Qualquer `await` antes de `pickImage()` invalida o contexto de gesto do browser.

**Fix:** `pickImage()` deve ser o **primeiro** `await` dentro de `_scan()`.

### `debugPrint` não aparece no console em builds de release
`debugPrint` é no-op em release. Usar `print()` para logs em `FlutterError.onError` e `runZonedGuarded`.

### Modelo Gemini descontinuado para novas chaves
`gemini-2.0-flash` e `gemini-1.5-flash` retornam 404 para chaves novas. Usar `gemini-2.5-flash`.
Para verificar modelos disponíveis na chave:
```bash
curl "https://generativelanguage.googleapis.com/v1beta/models?key=SUA_KEY"
```

### Google Sign-In retorna null no Flutter Web
**NÃO usar** o pacote `google_sign_in` — `googleUser.authentication` retorna `accessToken: null` no web.
**Fix:** usar `FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())` diretamente (`auth_service.dart`).

### Deploy — pasta `build/` fica com arquivos extras
Ao usar `git rm -rf .` na branch `gh-pages` e depois `cp -r build/web/.`, certificar-se de NÃO incluir `.dart_tool/`, `build/` aninhado ou `c/` (SDK Flutter). Usar `git add` com arquivos específicos:
```bash
git add index.html main.dart.js flutter.js flutter_bootstrap.js flutter_service_worker.js favicon.png manifest.json version.json assets/ canvaskit/ icons/
git add -u  # para staged deletions dos arquivos antigos
```
