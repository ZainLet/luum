# Plano Plataformas Nativas — Windows e Linux

**Data:** 2026-06-23  
**Autor:** OpenCode/DeepSeek (#76)

---

## Stack recomendada: **Tauri** (Rust + WebView)

| Critério | Tauri | Electron | .NET MAUI | Flutter | Avalonia |
|----------|-------|----------|-----------|---------|----------|
| Bundle | ~5 MB | ~150 MB | ~100 MB | ~25 MB | ~15 MB |
| Acesso a APIs nativas | Rust direto | Node native | .NET direto | FFI/Platform channels | .NET direto |
| Tray/menu bar | ✅ | ✅ | ⚠️ Windows OK, Linux limitado | ✅ | ⚠️ experimental |
| Monitoramento janelas | Rust `windows-rs` / `xcb` | Native addon | WinRT/UIA | FFI | WinRT/UIA |
| Linux real | ✅ AppImage/Flatpak | ✅ | ❌ sem suporte oficial | ✅ | ✅ X11/Wayland |
| Curva | Média (Rust) | Baixa (JS) | Média (C#) | Baixa (Dart) | Média (C#) |
| Firebase SDK | REST + Rust | ✅ | ✅ | ✅ | REST + .NET |

**Justificativa:** Tauri oferece o bundle mais leve, acesso direto a APIs de sistema via Rust (essencial para monitoramento de janelas e idle time), suporte real a Linux (AppImage + Flatpak), e crescente adoção em ferramentas desktop produtivas.

---

## Mapa de equivalências

| Funcionalidade | macOS (atual) | Windows | Linux |
|---|---|---|---|
| **Monitoramento app/janela** | `NSWorkspace.shared.runningApplications` + `frontmostApplication` | `GetForegroundWindow` + `GetWindowText` (win32) | `xcb_query_tree` (X11) / `ext_foreign_toplevel_handle` (Wayland) |
| **Idle time** | `CGEventSourceSecondsSinceLastEventType` | `GetLastInputInfo` | `XScreenSaverQueryInfo` ou `idle-inhibit` |
| **Título da janela** | `frontmostApplication.localizedName` | `GetWindowTextLength` + `GetWindowText` | `_NET_WM_NAME` (X11) / `xdg-shell` (Wayland) |
| **URL do navegador** | AppleScript | UIAutomation + `AccessibleObjectFromWindow` | `xdotool` + DBus (chrome-gnome-shell) |
| **Inicialização** | LaunchAgent plist | Task Scheduler / Registro `Run` | systemd user unit / `.desktop` autostart |
| **Tray/system tray** | `NSStatusItem` | `Shell_NotifyIcon` (win32) | `libappindicator-gtk3` / StatusNotifierItem |
| **Notificações** | `UNUserNotificationCenter` | `ToastNotification` (WinRT) | `GNotification` / `libnotify` |
| **Keychain** | Security.framework | `CredWriteW` (Credential Manager) | `libsecret` (Secret Service API) |
| **Auto-update** | Sparkle | Squirrel.Windows | AppImageUpdate / Flatpak update |
| **Crash reporter** | `NSSetUncaughtExceptionHandler` + signal | `SetUnhandledExceptionFilter` + `MiniDumpWriteDump` | `sigaction` + `breakpad` |
| **Firebase Auth** | `firebase-ios-sdk` | `firebase-auth` (C++ SDK) | `firebase-auth` (C++ SDK) |
| **Firestore** | `firebase-ios-sdk` | REST API via `reqwest` (Rust) | REST API via `reqwest` (Rust) |
| **Classificação** | `ClassificationEngine` (regras) e `AIClassificationService` (Gemini) | Core compartilhado (Rust) | Core compartilhado (Rust) |
| **Persistência** | JSON cache + Keychain tokens | JSON cache + Credential Manager | JSON cache + libsecret |

---

## Estimativa por fase

### Fase 1 — Core compartilhado (8-10 semanas)
| Módulo | Esforço | Descrição |
|--------|---------|-----------|
| Engine de classificação (regras) | 2-3 sem | Mover `ClassificationEngine` para lógica pura Rust (sem dependência macOS) |
| Gemini client | 1-2 sem | Cliente HTTP Rust para Gemini API |
| Modelos de dados | 1 sem | `ActivitySample`, `DailySummary`, `ActivityCategory` como structs Rust |
| Persistência JSON | 1 sem | Cache local com serialização serde |
| Firebase Auth (REST) | 2 sem | Login com email/senha e Google OAuth via `reqwest` |
| Firestore (REST) | 1-2 sem | CRUD via REST API |

### Fase 2 — MVP Windows (10-12 semanas)
| Módulo | Esforço | Descrição |
|--------|---------|-----------|
| Monitoramento de janelas | 3-4 sem | FFI para win32 `GetForegroundWindow`, polling loop |
| Idle time | 1 sem | `GetLastInputInfo` via FFI |
| Tray + dashboard inicial | 3-4 sem | Tray com ícone, dashboard webview básico |
| Auto-update | 2 sem | Squirrel.Windows |
| QA Windows | 1-2 sem | Testes em Win10, Win11 |

### Fase 3 — MVP Linux (6-8 semanas após Fase 2)
| Módulo | Esforço | Descrição |
|--------|---------|-----------|
| Monitoramento janelas (X11) | 2-3 sem | `xcb` bindings, polling loop |
| Suporte Wayland | 2 sem | `ext_foreign_toplevel_handle` protocol |
| Tray + notificações | 1-2 sem | `libappindicator`, `libnotify` |
| Empacotamento | 1 sem | AppImage + Flatpak |

### Fase 4 — Paridade funcional (contínuo)
- Outlook/Notion/ClickUp/Linear integrations
- Google Calendar sync
- Weekly email reports
- Zapier webhooks

---

## Dependências e riscos

### Alto
| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| **Monitoramento Wayland** sem protocolo estável | Bloqueio em distros Wayland-only (Fedora, Ubuntu >24.04) | Priorizar X11 primeiro; fallback para polling via `ext_foreign_toplevel_handle` |
| **Firebase C++ SDK** descontinuado | Auth + Firestore sem SDK oficial | REST API direta (já testada no backend Vercel) |
| **URL de navegador** no Windows | Bloqueia classificação de domínio | UIAutomation para Chrome/Edge; extensão navegador como alternativa |

### Médio
| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| **Manutenção de bindings Rust** para win32 | Código boilerplate alto | Usar crate `windows-rs` oficial da Microsoft |
| **Curva Rust** para devs JS/TS | Velocidade inicial menor | Core em Rust isolado; UI em webview (TS/HTML) |
| **Testes em múltiplas distros Linux** | Fragilidade | CI com Fedora + Ubuntu + Arch |

### Baixo
| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| **Tamanho do time** | Progresso lento | Foco em Windows primeiro (maior mercado) |
| **Revisão de código** entre plataformas | Context switching | Core Rust validado com testes unitários |

---

## Arquitetura proposta

```
┌─────────────────────────────────────────┐
│         Tauri WebView (UI)               │
│  Dashboard, Settings, Timeline — HTML/JS │
└────────────────┬────────────────────────┘
                 │ IPC (invoke)
┌────────────────┴────────────────────────┐
│         Tauri Rust Backend               │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐  │
│  │ Engine   │ │ Monitor  │ │ Firebase │  │
│  │ (classif)│ │ (janela) │ │ Auth/REST│  │
│  └─────────┘ └──────────┘ └──────────┘  │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐  │
│  │ Gemini  │ │ Keychain │ │ Persist  │  │
│  │ client  │ │ (OS dep) │ │ (JSON)   │  │
│  └─────────┘ └──────────┘ └──────────┘  │
└─────────────────────────────────────────┘
```

- **UI:** Webview (HTML/JS/Tailwind) — não compartilha código com SwiftUI atual
- **Lógica de negócio:** Rust puro — engine de classificação, modelos, persistência
- **APIs nativas:** Rust FFI (win32, xcb, libsecret) — específico por plataforma
- **Firebase:** REST API (compartilha HTTP client, difere auth flow)
