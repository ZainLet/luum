# Meta atualizada do Luum — Claude Code handoff

Atualizada em 21 de junho de 2026.

## Objetivo

Continuar o desenvolvimento do Luum no Claude Code com contexto curto, mudanças pequenas, uso disciplinado de skills e validação objetiva.

A meta só termina quando login, planos, administração, backup, Stripe, integrações, XCTest, desempenho, segurança e instalação em outro Mac estiverem comprovados por testes reais.

O foco atual é concluir a v1.0.0 macOS com estabilidade, segurança e provas reais, sem abrir refatorações grandes ou novas frentes desnecessárias.

## Ambiente-alvo

Ferramenta principal agora: Claude Code.

Usar Claude Code com estas prioridades:

1. Economizar tokens.
2. Evitar exploração ampla do projeto.
3. Usar Graphify antes de busca grande.
4. Fazer patches pequenos.
5. Rodar validação real com `/run` e `/verify`.
6. Revisar diff antes de qualquer commit.
7. Não fazer commit, push ou PR sem pedido explícito.

## Skills disponíveis e uso recomendado

### Skills principais

* `graphify`
  Usar antes de arquitetura, busca ampla ou investigação em área desconhecida.
  Preferir consultar o grafo e o `graphify-out/GRAPH_REPORT.md` antes de abrir muitos arquivos.

* `caveman`
  Usar para respostas curtas e economia de tokens.
  Usar especialmente em status, check-ins, revisões rápidas e handoffs.

* `karpathy-guidelines`
  Usar para mudanças pequenas, verificáveis e sem overengineering.
  Deve ser padrão em implementação.

* `systematic-debugging`
  Usar em bugs, falhas de teste, crashes ou comportamento inconsistente.
  Não editar antes de levantar hipótese e causa raiz.

* `run`
  Usar para iniciar e interagir com o app do projeto.

* `verify`
  Usar depois de qualquer alteração relevante para comprovar que a mudança funciona na prática.

* `code-review`
  Usar antes de commit local ou encerramento de microetapa.
  Foco em diff atual, bugs e regressões reais.

* `code-review-and-quality`
  Usar em revisão mais pesada antes de release, merge grande ou fechamento de milestone.

* `security-review`
  Usar sempre que a mudança tocar login, planos, workspace, sync, Firestore, Stripe, backup, integrações, logs, tokens, segredos ou dados locais.

* `frontend-design`
  Usar somente para polimento visual.
  Não alterar lógica, dados, permissões ou arquitetura durante uso dessa skill.

### Skills de uso controlado

* `simplify`
  Usar apenas em escopo pequeno e depois que a feature estiver funcionando.
  Não usar para refatoração ampla antes da v1.

* `claude-in-chrome`
  Usar só para testes visuais/controlados em browser, se necessário.
  Não preencher dados sensíveis, não alterar produção sem autorização e não executar compras reais.

### Skills de baixa prioridade agora

* `loop`
* `schedule`
* `claude-api`
* `find-skills`
* `init`
* `update-config`
* `keybindings-help`
* `review`
* `fewer-permission-prompts`

Não usar essas skills durante a reta final da v1, salvo pedido explícito.

## Fluxo padrão no Claude Code

### Para implementar mudança

Usar este padrão:

```text
Use graphify + karpathy-guidelines + caveman.
Primeiro identifique a área do projeto relacionada à tarefa.
Consulte o grafo antes de abrir arquivos.
Leia no máximo 3 a 6 arquivos antes do primeiro patch.
Faça a menor mudança possível.
Depois rode /run e /verify.
No final use code-review no diff atual.
```

### Para corrigir bug

Usar este padrão:

```text
Use systematic-debugging + graphify + caveman.
Não edite nada ainda.
Primeiro encontre a causa raiz.
Depois aplique a menor correção possível.
Rode /verify.
Revise o diff com code-review.
```

### Para mudança em login, planos, sync, workspace, backup ou Stripe

Usar este padrão:

```text
Use graphify + karpathy-guidelines + security-review.
Faça patch pequeno.
Não registre tokens, segredos, payloads privados nem chaves de workspace.
Não confie em gates apenas na interface.
Depois rode testes relevantes, /verify e security-review.
```

### Para revisão antes de release

Usar este padrão:

```text
Use code-review-and-quality + security-review + verify.
Liste apenas bloqueadores reais para release.
Não sugerir refatorações grandes.
Classificar cada item como: bloqueador, importante, opcional ou pós-v1.
```

### Para UI

Usar este padrão:

```text
Use frontend-design somente para polimento visual.
Não alterar lógica, dados, storage, permissões, sync ou arquitetura.
Manter o comportamento atual.
```

## Estado comprovado

Login real validado:

* app → site → Firebase → luum://auth → app.
* Conta `oluum.app@gmail.com`.
* Plano Equipes.
* Sessão persistida após reabrir o app.

Firebase Auth e Firestore permanecem como fontes de identidade e entitlement.

Matriz server-side testada para trial, Essencial, Profissional, Equipes e Negócios.

Workspace `oluum-app` criado. Segredo salvo no cofre local. Sync e ranking com 1 membro validados.

Backup e restauração reais no Firestore concluídos.

Backend Vercel:

* deployment: `dpl_8y1RLPbTL2VRtufhWk9U8WjzHR8G`;
* alias: `https://luum-app.vercel.app`;
* estado: Ready.

Checkout anônimo: `401` verificado antes do corpo (corrigido em 2026-06-21).

Suíte Node: 105 testes aprovados, zero falhas.

Build macOS aprovado. PKG `0.0.4-alpha` verificado.

Gatekeeper rejeita por falta de Developer ID; instalação em outro Mac pendente.

XCTest: teste de logout escrito, não executado (sem Xcode completo).

Windows/Linux: auditados documentalmente; nenhum build .NET executado.

Graphify: 1.659 nós, 3.851 relações, 53 comunidades.

CodeRabbit instalado no repo `ZainLet/luum`.

CLAUDE.md adicionado ao repositório.

## Correções de segurança — LUUM-DIFF-001 resolvido

Commit `1919d4d`, PR #13: `https://github.com/ZainLet/luum/pull/13`

* `signOut()`: limpa `workspaceID`, `workspaceEndpointURL`, chave do Keychain e flags de sync.
* Auth refresh: `shouldSyncWorkspace` não exige mais `sharesAnonymousMetrics` (era incorreto).
* Teste: `workspaceID.isEmpty` adicionado em `ActivityStoreSignOutTests`.
* `checkout.js`: token verificado antes de ler o corpo.

Status: commitado, PR aberto. CodeRabbit review pendente.

## Próxima ação objetiva

1. Endereçar comentários do CodeRabbit no PR #13.
2. Executar `signOutClearsWorkspaceConfigurationAndParticipation()` com Xcode completo.
3. QA manual de logout: Workspace ID deve sumir das preferências.

## Pendências obrigatórias da meta

### Stripe real e controlado

Validar:

* checkout autenticado;
* webhook persistido no Firestore;
* revalidação do plano no app;
* cancelamento;
* acesso até o fim do período pago.

### Administração

Testar:

* administração autenticada;
* revalidação manual de planos;
* permissões reais;
* respostas sem exposição indevida de dados.

### Planos

Validar gates reais com contas de cada plano, além da matriz automatizada.

Planos obrigatórios:

* trial;
* Essencial;
* Profissional;
* Equipes;
* Negócios.

### Integrações

Configurar e testar:

* Google Calendar;
* Notion;
* Outlook;
* ClickUp;
* Linear;
* Zapier;
* Gemini;
* Resend.

### XCTest

Executar XCTest com Xcode completo.

Distinguir teste compilado de teste realmente executado.

### Desempenho

Fazer QA prolongado de desempenho.

Validar:

* uso de CPU;
* uso de memória;
* captura prolongada;
* sync prolongado;
* abertura e fechamento do app;
* comportamento após sleep/wake;
* comportamento após perda de rede.

### Segurança

Fazer revisão final de segurança.

Validar especialmente:

* logout;
* troca de conta;
* workspace;
* chaves locais;
* Firestore;
* Stripe;
* logs;
* backup;
* integrações;
* permissões macOS.

### Instalação em outro Mac

Instalar e testar o PKG em outro Mac.

Validar:

* primeira abertura;
* permissões;
* login;
* captura;
* persistência de sessão;
* backup;
* restauração;
* desinstalação básica;
* comportamento do Gatekeeper.

### Windows/Linux

Finalizar documentação e validação para Windows e Linux.

Ainda não marcar como pronto enquanto não houver:

* plano técnico claro;
* toolchain validado;
* build validado;
* pacote validado;
* testes básicos validados.

### Apple Developer

Posteriormente obter Apple Developer ID, assinar e notarizar.

Não tratar assinatura ad-hoc como equivalente a distribuição real.

## Regras operacionais obrigatórias

1. Ler `graphify-out/GRAPH_REPORT.md` antes de arquitetura ou busca ampla.
2. Usar `graphify update .` após alterações de código.
3. Consultar no máximo 3 a 6 arquivos antes do primeiro patch.
4. Preservar alterações existentes e não relacionadas.
5. Não registrar tokens, segredos, payloads privados ou chaves de workspace.
6. Não confiar em gates apenas na interface.
7. Distinguir testes compilados de testes realmente executados.
8. Não marcar a meta como concluída enquanto houver qualquer pendência obrigatória sem prova real.
9. Não fazer commit, push ou PR sem autorização explícita.
10. Não abrir refatorações grandes antes da v1.
11. Não instalar novas dependências sem justificar necessidade, risco e alternativa.
12. Não alterar fluxo de billing, auth ou sync sem teste real.
13. Não usar `simplify` em escopo amplo.
14. Não usar `frontend-design` para alterar lógica.
15. Não usar `loop` ou `schedule` durante a reta final sem autorização.

## Critério de patch

Cada patch deve ter:

* objetivo;
* arquivos tocados;
* motivo;
* risco;
* validação feita;
* validação pendente.

Antes de editar, o Claude deve responder:

```text
Arquivos que pretendo tocar:
1.
2.
3.

Motivo:
Risco:
Validação planejada:
```

Depois de editar, o Claude deve responder:

```text
Mudança feita:
Arquivos alterados:
Validação executada:
Resultado:
Riscos restantes:
Próximo passo objetivo:
```

## Comandos/pedidos curtos para usar no Claude Code

### Retomada barata

```text
luum-handoff
Use caveman + graphify. Leia esta meta e o GRAPH_REPORT.md. Dê apenas o próximo passo objetivo, sem auditoria ampla.
```

### Continuar desenvolvimento

```text
luum-continue
Use graphify + karpathy-guidelines + caveman. Continue do próximo passo objetivo. Leia no máximo 3 a 6 arquivos antes do patch.
```

### Status rápido

```text
luum-checkin
Use caveman. Diga: estado atual, bloqueador, próximo passo, arquivos em jogo e validação pendente.
```

### Rollover

```text
luum-rollover
Pare exploração nova. Finalize só o micro-passo atual. Rode graphify update . se houve mudança de código. Atualize HANDOFF.md e esta meta com estado comprovado, última mudança, bloqueador, próximo passo e arquivos em jogo. Gere prompt curto para próximo chat.
```

### Bug

```text
Use systematic-debugging + graphify + caveman. Não edite ainda. Encontre causa raiz, liste hipótese principal, arquivos relevantes e validação mínima.
```

### Patch pequeno

```text
Use graphify + karpathy-guidelines + caveman. Faça a menor mudança possível. Não refatore. Mostre arquivos antes de editar. Depois rode /verify.
```

### Revisão de diff

```text
Use code-review no diff atual. Foque só em bugs, regressões e riscos reais. Não sugerir refatoração grande.
```

### Segurança

```text
Use security-review no diff atual. Foque em tokens, segredos, workspace, logs, Firestore, Stripe, backup, auth e troca de conta.
```

### Release

```text
Use code-review-and-quality + security-review + verify. Liste somente bloqueadores reais para v1.0.0 macOS.
```

## Troca de chat / rollover

Quando o contexto estiver perto do limite, ou quando for hora de mudar para outro chat:

1. Parar qualquer exploração nova.
2. Finalizar só o micro-passo atual.
3. Rodar `graphify update .` se houver mudança de código.
4. Atualizar `HANDOFF.md`.
5. Atualizar esta meta se o estado comprovado, pendências ou próxima ação mudarem.
6. Gerar um prompt curto para o próximo chat.

O `HANDOFF.md` deve conter:

* objetivo atual;
* última mudança;
* bloqueador atual;
* próximo passo;
* arquivos em jogo;
* validação feita;
* validação pendente;
* riscos conhecidos;
* comando recomendado para retomada.

## Prompt curto para próximo chat

```text
Estamos no Luum v1 macOS, usando Claude Code. Leia docs/META_LUUM_ATUALIZADA.md e graphify-out/GRAPH_REPORT.md. Use graphify + caveman + karpathy-guidelines. Não faça commit/push/PR sem autorização. PR #13 aberto em github.com/ZainLet/luum/pull/13, CodeRabbit review pendente. Próxima ação: endereçar comentários do CodeRabbit; depois executar signOutClearsWorkspaceConfigurationAndParticipation() com Xcode completo. Patches pequenos, máximo 3-6 arquivos antes de editar, /verify depois.
```
