# Meta atualizada do Luum — handoff

Atualizada em 21 de junho de 2026.

## Objetivo

Continuar o desenvolvimento do Luum com contexto curto, mudanças pequenas e validação objetiva. A meta só termina quando login, planos, administração, backup, Stripe, integrações, XCTest, desempenho, segurança e instalação em outro Mac estiverem comprovados por testes reais.

## Estado comprovado

- Login real validado: `app → site → Firebase → luum://auth → app`.
- Conta `oluum.app@gmail.com`, plano Equipes e sessão persistida após reabrir o app.
- Firebase Auth e Firestore permanecem como fontes de identidade e entitlement.
- Matriz server-side testada para trial, Essencial, Profissional, Equipes e Negócios.
- Workspace `oluum-app` criado; segredo salvo no cofre local; sync e ranking real com 1 membro validados.
- Correção local faz o ranking sincronizar imediatamente após revalidar a conta no lançamento.
- Backup e restauração reais no Firestore concluídos.
- Backend publicado em produção na Vercel:
  - deployment: `dpl_8y1RLPbTL2VRtufhWk9U8WjzHR8G`;
  - alias: `https://luum-app.vercel.app`;
  - estado: `Ready`.
- Limites Stripe validados em produção sem cobrança:
  - checkout anônimo: `401 Login Firebase obrigatório`;
  - cancelamento anônimo: `401 Login Firebase obrigatório`;
  - webhook sem assinatura: `400 Webhook signature verification failed`;
  - respostas com `Cache-Control: no-store, max-age=0`.
- Fronteira anônima de administração validada em produção: auth status, health, usuários, integrações e Stripe health retornam `401` com `no-store`.
- Configuração pública de integrações retorna `200` sanitizado, mas Google, Outlook, Notion, ClickUp, Linear e Zapier permanecem com `managedOAuth=false`; configuração e testes reais continuam pendentes.
- 32 testes focados Stripe/auth/entitlements aprovados.
- Suíte Node completa: 105 testes aprovados, zero falhas.
- `npm audit --omit=dev`: zero vulnerabilidades.
- Build macOS aprovado; `./script/build_and_run.sh --verify` validou o bundle, a assinatura ad-hoc, o lançamento e o processo ativo.
- QA visual somente leitura confirmou janela principal, sessão Equipes, captura ativa, resumo e busca local com resultados; Agenda, Equipe e Preferências ainda não foram comprovadas nessa rodada porque a automação perdeu acesso à janela, embora o processo tenha permanecido ativo.
- PKG local `0.0.4-alpha` regenerado e verificado: payload em `/Applications`, package id e checksums dos aliases estáveis aprovados.
- Artefatos gerados com worktree modificado agora recebem `-dirty` no nome e nas notas para não aparentarem corresponder exatamente ao commit.
- Gatekeeper ainda rejeita app/PKG por falta de Developer ID e notarização; instalação e QA em outro Mac continuam pendentes.
- XCTest ainda não foi executado; o teste focado de logout compilou, mas a instalação atual tem apenas Command Line Tools e não inclui o runner `xctest`.
- Windows/Linux auditados documentalmente: os projetos existentes são backend, cliente web e helper console legado; ainda não há WinUI/MSIX nem cliente/Flatpak Linux, e este Mac não possui toolchain .NET para executar build ou testes.
- Graphify atualizado: 1.659 nós, 3.851 relações e 53 comunidades.

## Revisão de segurança mais recente

- Foi executada uma auditoria formal do diff local com cobertura 3/3 dos arquivos-fonte alterados.
- Relatórios temporários:
  - `/tmp/codex-security-scans/luum/c6b877a_20260620T212930Z/report.md`;
  - `/tmp/codex-security-scans/luum/c6b877a_20260620T212930Z/report.html`.
- Um achado sobreviveu à validação:
  - `LUUM-DIFF-001` — baixo/P3, confiança 0,75;
  - ao sair da conta, a chave e as preferências do workspace permanecem locais;
  - a próxima conta Equipes/Negócios no mesmo usuário do macOS pode sincronizar automaticamente usando esse workspace antigo;
  - impacto limitado a métricas agregadas e ranking; não há exposição comprovada de tokens, atividade bruta ou billing.
- Correção local aplicada, ainda sem commit/push e pendente de execução com XCTest:
  - remover `team-workspace-secret` no logout;
  - desativar compartilhamento e sync automático;
  - limpar ranking em memória;
  - adicionar teste garantindo que o workspace deixa de estar configurado após logout.

## Alterações locais ainda sem commit/push

Branch: `codex/cloud-sync-coalesce`.

- `script/build_and_run.sh`
  - marca builds produzidas por worktree modificado com `-dirty` no identificador do artefato e nas notas.
- `src/LUUM.Mac/Sources/luum/Stores/ActivityStore.swift`
  - sync imediato do workspace após revalidação Firebase;
  - limpeza da chave, participação, sync e ranking do workspace no logout.
- `src/LUUM.Mac/Tests/luumTests/ActivityStoreSignOutTests.swift`
  - regressão focada garantindo que o workspace deixa de estar configurado após logout.
- `src/LUUM.Mac/Sources/luum/Views/SettingsView.swift`
  - logout com confirmação;
  - campos de Workspace ID e chave compartilhada.
- `website/api/checkout.js`
  - autenticação Firebase ocorre antes da validação do corpo.
- `website/test/auth-handlers.test.js`
  - regressão para checkout anônimo retornar `401` primeiro.
- `website/test/billing-cache.test.js`
  - contrato `401` e `no-store` atualizado.
- `website/test/entitlements.test.js`
  - matriz completa dos planos.
- `docs/META_LUUM_ATUALIZADA.md`
  - este handoff.

Não fazer commit, push ou PR sem pedido explícito. O backend publicado contém a correção de autenticação do checkout, mas as alterações Swift continuam apenas locais.

## Próxima ação objetiva

1. Executar `signOutClearsWorkspaceConfigurationAndParticipation()` com Xcode/XCTest completo.
2. Se o teste passar, fazer a revisão final de `LUUM-DIFF-001`.
3. Somente depois, pedir autorização para commit/push.

## Pendências obrigatórias da meta

1. Validar Stripe real e controlado:
   - checkout autenticado;
   - webhook persistido no Firestore;
   - revalidação do plano no app;
   - cancelamento e acesso até o fim do período pago.
2. Testar administração autenticada e revalidação manual de planos.
3. Validar gates reais com contas de cada plano, além da matriz automatizada.
4. Configurar e testar Google Calendar, Notion, Outlook, ClickUp, Linear, Zapier, Gemini e Resend.
5. Executar XCTest com Xcode completo.
6. Fazer QA prolongado de desempenho e revisão final de segurança.
7. Instalar e testar o PKG em outro Mac.
8. Finalizar documentação e validação para Windows e Linux.
9. Posteriormente obter Apple Developer ID, assinar e notarizar.

## Regras operacionais

- Ler `graphify-out/GRAPH_REPORT.md` antes de arquitetura ou busca ampla.
- Usar `graphify update .` após alterações de código.
- Usar Distill somente para saídas longas; repetir comando estreito se o resumo falhar.
- Consultar no máximo 3 a 6 arquivos antes do primeiro patch.
- Preservar alterações existentes e não relacionadas.
- Não registrar tokens, segredos, payloads privados ou chaves de workspace.
- Não confiar em gates apenas na interface.
- Distinguir testes compilados de testes realmente executados.
- Não marcar a meta como concluída enquanto houver qualquer pendência obrigatória sem prova real.

## Troca de chat / rollover

Quando o contexto estiver perto do limite, ou quando for hora de mudar para outro chat:

1. Parar qualquer exploração nova.
2. Finalizar só o micro-passo atual.
3. Rodar `graphify update .` se houver mudança de código.
4. Atualizar `HANDOFF.md` com:
   - objetivo atual;
   - última mudança;
   - bloqueador atual;
   - próximo passo;
   - arquivos em jogo.
5. Atualizar esta meta se o estado comprovado, pendências ou próxima ação mudarem.
6. Gerar um prompt curto para o próximo chat.

Para retomada:
- `luum-handoff` quando quiser o reinício mais barato possível.
- `luum-continue` quando quiser seguir com um handoff curto.
- `luum-checkin` quando quiser um status rápido sem auditoria.
- `luum-rollover` quando o chat estiver chegando no limite e precisar salvar o estado.
