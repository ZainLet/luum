# Manual inicial para distribuicao Windows e estudo Linux

Atualizado em 2026-06-12.

Este manual nao substitui o trabalho de portabilidade. Ele define o caminho tecnico para transformar o Luum, hoje macOS/SwiftUI, em um produto nativo para Windows e em uma possibilidade futura para Linux.

## Decisao principal

Nao portar SwiftUI diretamente. O Luum depende de comportamento nativo do sistema operacional:

- detectar app em foco
- ler URL/titulo de navegadores
- lidar com permissoes locais
- emitir notificacoes
- rodar em background
- empacotar com identidade de app
- proteger sessao, plano e dispositivo

Por isso, o caminho recomendado para Windows e um cliente nativo separado, reaproveitando backend, contratos JSON e regras de produto.

## Stack recomendada para Windows

- UI: WinUI 3 com Windows App SDK.
- Linguagem/runtime: C# e .NET 8+.
- Empacotamento: MSIX.
- Backend compartilhado: Vercel/Firebase/Stripe ja existentes.
- Auth: abrir login web e receber callback por protocolo customizado, equivalente ao `luum://auth` do macOS.

Referencias oficiais:

- Windows App SDK: https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/
- WinUI 3: https://learn.microsoft.com/en-us/windows/apps/winui/winui3/
- Criar primeiro projeto WinUI: https://learn.microsoft.com/en-us/windows/apps/get-started/start-here
- Deployment Windows App SDK: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/deploy-overview
- Deploy self-contained: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/self-contained-deploy/deploy-self-contained-apps
- MSIX: https://learn.microsoft.com/en-us/windows/msix/overview

## O que pode ser compartilhado

Compartilhar por contrato, nao copiando UI:

- modelos de plano: `trial`, `essencial`, `profissional`, `equipes`, `negocios`
- matriz de recursos: tracking, busca, agenda, backup, raw backup, workspace
- payload de auth: token Firebase, refresh token, UID
- contrato de `/api/auth/status`
- contrato de `/api/sync/{uid}`
- contrato de workspace/ranking
- regras de backup sanitizado
- catalogo inicial de categorias, apps ignorados e dominios ignorados

Arquivos do repo que servem como fonte de contrato:

- `src/LUUM.Mac/Sources/luum/Models/AuthModels.swift`
- `src/LUUM.Mac/Sources/luum/Services/FirebaseAuthService.swift`
- `src/LUUM.Mac/Sources/luum/Services/CloudSyncService.swift`
- `website/api/_entitlements.js`
- `website/api/sync/[backupID].js`
- `website/api/auth/status.js`

## O que precisa ser refeito nativo no Windows

### Monitoramento de app ativo

Criar um servico local para capturar:

- processo ativo
- titulo da janela ativa
- bundle equivalente: no Windows, nome do executavel, caminho assinado e AppUserModelID quando existir
- duracao por janela/app
- inatividade

### Navegadores

O macOS usa Automacao/AppleScript. No Windows, isso precisa ser redesenhado:

- Chrome/Edge/Brave/Arc/Opera: avaliar extensao de navegador ou Native Messaging
- Firefox: avaliar extensao separada
- alternativa limitada: capturar apenas titulo da janela e dominio quando exposto no titulo

Para produto confiavel, prefira extensao oficial + Native Messaging, porque ler URL diretamente de outro processo e fragil e sensivel a permissao/seguranca.

### Notificacoes e background

Implementar:

- notificacoes nativas do Windows
- startup opcional com o usuario
- processo em background ou tray app
- pausa/retomada de monitoramento
- estado visual claro quando o app esta capturando

### Cofre local

No Windows, nao usar o cofre local cifrado do macOS. Usar:

- Windows Credential Manager ou DPAPI para segredos locais
- fallback cifrado por instalacao apenas se Credential Manager falhar
- device ID derivado de segredo local, sem expor hardware ID puro

O contrato com o backend deve continuar igual: enviar `X-Luum-Device-ID` em `/api/auth/status`.

## Login no Windows

Fluxo recomendado:

1. App abre `https://luum-app.vercel.app/login.html?app=windows`.
2. Site autentica via Firebase.
3. Site chama `/api/auth/upsert-user`.
4. Site abre protocolo customizado, por exemplo `luum://auth?...`.
5. App valida:
   - scheme e host
   - token presente
   - UID do callback igual ao UID do Firebase ID token
   - projeto Firebase oficial
6. App chama `/api/auth/status` no backend oficial.
7. App salva sessao local em cofre do Windows.
8. App aplica gates por plano.

Importante: nao liberar recursos pagos apenas pelo callback. O callback cria uma sessao inicial, mas o acesso vem do backend.

## Backup no Windows

Reaproveitar o mesmo contrato:

- `PUT /api/sync/{uid}` para enviar backup
- `POST /api/sync/{uid}` para restaurar
- `Authorization: Bearer {firebase_id_token}`
- `payload.account.uid` precisa bater com UID verificado

O cliente Windows deve sanitizar antes de enviar:

- remover tokens OAuth
- remover webhooks completos
- remover segredos locais
- enviar metadados de integracao, categorias, regras e resumos

## Empacotamento Windows

Ordem recomendada:

1. Criar projeto WinUI 3.
2. Implementar login e `/api/auth/status`.
3. Implementar shell principal com telas bloqueadas por plano.
4. Implementar captura de app ativo.
5. Implementar persistencia local.
6. Implementar backup Firebase.
7. Implementar notificacoes.
8. Implementar extensao/Native Messaging para navegadores.
9. Criar MSIX.
10. Assinar pacote com certificado de code signing.
11. Testar instalacao em Windows limpo.
12. Decidir distribuicao:
    - download direto com MSIX
    - Microsoft Store
    - instalador empresarial

MSIX e importante porque entrega identidade de pacote, instalacao/remocao limpa, atualizacao e acesso a recursos de plataforma que dependem de identidade.

## Checklist minimo da versao Windows alpha

- [ ] Login Firebase abre navegador e retorna ao app.
- [ ] `/api/auth/status` valida plano.
- [ ] Sessao expira offline depois da janela definida.
- [ ] Gates de plano bloqueiam UI e acoes sensiveis.
- [ ] App ativo e duracao sao capturados.
- [ ] Historico local persiste.
- [ ] Backup envia payload sanitizado.
- [ ] Restore nao restaura tokens.
- [ ] Notificacoes funcionam.
- [ ] Instalacao MSIX funciona em maquina limpa.
- [ ] Desinstalacao remove app sem apagar dados sem aviso.

## Estudo Linux

Linux deve ser tratado como pesquisa separada, nao como promessa de produto no curto prazo.

Desafios:

- diversidade de ambientes desktop
- Wayland restringe captura global por seguranca
- X11 permite mais inspecao, mas e menos moderno
- leitura de URL de navegadores quase certamente exige extensao
- notificacoes variam por ambiente
- auto-start e permissoes variam por distribuicao

Stack possivel:

- UI: Avalonia UI ou Qt.
- Runtime: .NET 8+ se quiser reaproveitar parte do cliente Windows.
- Distribuicao: Flatpak para caminho mais uniforme entre distros.

Referencia oficial:

- Flatpak: https://docs.flatpak.org/en/latest/introduction.html
- .NET publishing: https://learn.microsoft.com/en-us/dotnet/core/deploying/

Checklist de pesquisa Linux:

- [ ] Prototipar captura de app ativo em GNOME Wayland.
- [ ] Prototipar captura em KDE Wayland.
- [ ] Prototipar fallback X11.
- [ ] Validar Native Messaging para Chrome/Firefox.
- [ ] Validar notificacoes desktop.
- [ ] Validar empacotamento Flatpak.
- [ ] Decidir se Linux sera oficialmente suportado ou apenas experimental.

## Ordem recomendada apos macOS ficar estavel

1. Congelar contratos JSON no backend.
2. Criar fixtures de auth/status/sync compartilhadas.
3. Criar projeto Windows minimo.
4. Portar modelos de plano e gates.
5. Implementar login.
6. Implementar captura local.
7. Implementar backup.
8. Empacotar MSIX alpha.
9. Testar em Windows 11 limpo.
10. So depois estudar Linux.

