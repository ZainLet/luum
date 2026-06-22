# Meta atualizada do Luum — handoff

Atualizada em 21 de junho de 2026, 23:42.

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
  - checkout anônimo: `401 Login Firebase obrigatório` (agora verificado antes do corpo);
  - cancelamento anônimo: `401 Login Firebase obrigatório`;
  - webhook sem assinatura: `400 Webhook signature verification failed`;
  - respostas com `Cache-Control: no-store, max-age=0`.
- Fronteira anônima de administração validada em produção: auth status, health, usuários, integrações e Stripe health retornam `401` com `no-store`.
- Configuração pública de integrações retorna `200` sanitizado; Google, Outlook, Notion, ClickUp, Linear e Zapier permanecem com `managedOAuth=false`.
- Suíte Node: 105 testes aprovados, zero falhas.
- `npm audit --omit=dev`: zero vulnerabilidades.
- Build macOS aprovado; `./script/build_and_run.sh --verify` validou o bundle, a assinatura ad-hoc, o lançamento e o processo ativo.
- PKG local `0.0.4-alpha` regenerado e verificado.
- Artefatos com worktree modificado recebem `-dirty` no nome e nas notas.
- Gatekeeper ainda rejeita app/PKG por falta de Developer ID e notarização; instalação em outro Mac pendente.
- XCTest ainda não executado: teste `signOutClearsWorkspaceConfigurationAndParticipation()` compilado mas não rodado (sem Xcode completo).
- Windows/Linux: auditados documentalmente; nenhum build ou teste .NET executado nesta máquina.
- Graphify: 1.659 nós, 3.851 relações, 53 comunidades.
- CLAUDE.md adicionado ao repositório com arquitetura, comandos e convenções.
- CodeRabbit instalado no repo `ZainLet/luum`; review automático ativo em PRs.

## Correções de segurança — LUUM-DIFF-001 (resolvido em 2026-06-21)

Achado original: ao sair da conta, chave e preferências do workspace permaneciam locais; próxima conta Equipes/Negócios poderia sincronizar usando workspace antigo.

Correções aplicadas no commit `1919d4d` (PR #13):

- `ActivityStore.signOut()`: remove `team-workspace-secret` do Keychain, limpa `workspaceID`, reseta `workspaceEndpointURL` para o padrão, desativa flags de sync, limpa ranking em memória e persiste preferências.
- `ActivityStore` auth refresh: condição `shouldSyncWorkspace` não exige mais `sharesAnonymousMetrics` (era incorreto — usuários com sync ativo mas métricas desativadas não sincronizavam).
- `ActivityStoreSignOutTests`: asserção `workspaceID.isEmpty` adicionada.
- `checkout.js`: token Firebase verificado antes de ler o corpo (proteção contra leitura de payload em requisição anônima).

Status: commit feito, push feito, **PR #13 aberto** em `https://github.com/ZainLet/luum/pull/13`. CodeRabbit review pendente.

Validação ainda pendente: `signOutClearsWorkspaceConfigurationAndParticipation()` precisa de Xcode completo para rodar.

## Última sessão de trabalho (2026-06-21, 23:42)

- Revisão de diff com `code-review` (7 ângulos, verify 3-state): 2 bugs confirmados, 1 plausível, ambos corrigidos.
- Commit `1919d4d` em `codex/cloud-sync-coalesce` com 13 arquivos, 1.118 inserções.
- PR #13 aberto no GitHub para revisão pelo CodeRabbit.

## Próxima ação objetiva

1. Aguardar e endereçar comentários do CodeRabbit no PR #13.
2. Executar `signOutClearsWorkspaceConfigurationAndParticipation()` com Xcode completo.
3. Fazer QA manual de logout no app: confirmar que Workspace ID some das preferências após sair da conta.

## Pendências obrigatórias da meta

1. Endereçar comentários do CodeRabbit no PR #13.
2. Validar Stripe real e controlado:
   - checkout autenticado;
   - webhook persistido no Firestore;
   - revalidação do plano no app;
   - cancelamento e acesso até o fim do período pago.
3. Testar administração autenticada e revalidação manual de planos.
4. Validar gates reais com contas de cada plano, além da matriz automatizada.
5. Configurar e testar Google Calendar, Notion, Outlook, ClickUp, Linear, Zapier, Gemini e Resend.
6. Executar XCTest com Xcode completo (teste de logout já escrito, aguarda runner).
7. QA manual de logout: confirmar que Workspace ID some das preferências.
8. Fazer QA prolongado de desempenho e revisão final de segurança.
9. Instalar e testar o PKG em outro Mac.
10. Finalizar documentação e validação para Windows e Linux.
11. Obter Apple Developer ID, assinar e notarizar.

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
