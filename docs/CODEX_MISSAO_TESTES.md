# Missão Codex — Testes Físicos do Luum

Atualizado em 2026-06-22.

## Contexto

O Claude Code cuida de programação, correções e implementações. O Codex é responsável pelos **testes físicos** — ações que exigem o Mac, o app rodando, Xcode completo ou cartão Stripe real. Ao terminar cada bloco de testes, o Codex entrega um relatório no formato definido na seção **Formato de entrega** para que o Claude Code possa corrigir os problemas encontrados.

---

## Bloco 1 — QA de logout

**O que testar:**

1. Abrir o Luum e confirmar que está logado (conta visível nas preferências)
2. Ir em **Preferências → aba de conta** e clicar em "Sair desta conta"
3. Confirmar o dialog
4. Verificar o arquivo de preferências persistido:
   ```bash
   cat ~/Library/Application\ Support/luum/monitoring-preferences.json | python3 -m json.tool | grep -E "workspaceID|workspaceMemberID|workspaceSecret|automaticallySyncWorkspace"
   ```
5. Reabrir o app e confirmar que volta para a tela de login

**O que capturar:**

- Conteúdo completo do JSON de preferências antes e depois do logout
- Se o botão "Sair desta conta" apareceu corretamente (ou estava oculto)
- Se o app voltou para a tela de login após sair
- Qualquer erro no console do sistema:
  ```bash
  log show --last 2m --predicate 'process == "luum"' --style compact 2>/dev/null | tail -30
  ```

---

## Bloco 2 — XCTest com Xcode completo

**O que executar:**

```bash
cd /Users/zainlet/Desktop/APP\ LUUM/luum
xcodebuild test \
  -scheme luum \
  -destination 'platform=macOS' \
  -resultBundlePath /tmp/luum-test-results \
  2>&1 | tee /tmp/luum-xctests.log
```

Ou via Swift Package Manager se o scheme não existir:
```bash
swift test --package-path src/LUUM.Mac 2>&1 | tee /tmp/luum-swift-tests.log
```

**O que capturar:**

- Saída completa do teste (stdout + stderr)
- Número de testes: passou / falhou / ignorado
- Mensagem completa de cada falha (arquivo, linha, asserção)
- Especificamente o resultado de `signOutClearsWorkspaceConfigurationAndParticipation()`

---

## Bloco 3 — Stripe real

**Pré-requisitos:**

- Estar logado no app com a conta `oluum.app@gmail.com`
- Ter um cartão de teste Stripe disponível (ex: `4242 4242 4242 4242`)
- Backend Vercel em produção (`https://luum-app.vercel.app`) já está ativo

**O que testar:**

### 3a. Checkout autenticado

1. No app, clicar em qualquer feature bloqueada (ex: Backup) → botão "Ver planos"
2. Completar o checkout com cartão de teste
3. Após o pagamento, voltar ao app e clicar em "Revalidar plano"
4. Verificar se o plano mudou no app

**Capturar:** plano antes, plano depois, qualquer erro do app ou do site.

### 3b. Webhook persistido no Firestore

Após o checkout:
```bash
curl -s -X GET "https://luum-app.vercel.app/api/auth/status" \
  -H "Authorization: Bearer <SEU_FIREBASE_ID_TOKEN>" | python3 -m json.tool
```

**Capturar:** resposta JSON completa (sem expor o token no relatório — substituir por `[REDACTED]`).

### 3c. Revalidação do plano no app

- Fechar e reabrir o app
- Verificar se o plano correto ainda aparece sem precisar revalidar manualmente

**Capturar:** plano exibido, se houve ou não prompt de revalidação.

### 3d. Cancelamento

- No site Luum, cancelar a assinatura
- No app, clicar em "Revalidar plano"
- Verificar se o acesso ainda funciona até o fim do período pago

**Capturar:** comportamento do app após cancelamento, mensagem exibida.

---

## Bloco 4 — Gates reais por plano

**O que testar:**

Com a conta atual (após testes do Bloco 3), navegar para cada seção do app e anotar o que está **bloqueado** vs **liberado**:

| Seção | Plano mínimo esperado | Status real |
|---|---|---|
| Resumo | Essencial | ? |
| Busca | Essencial | ? |
| Agenda | Essencial | ? |
| Apps / Sites | Essencial | ? |
| Clientes | Profissional | ? |
| Equipe | Equipes | ? |
| Foco | Profissional | ? |
| Lembretes | Essencial | ? |
| Relatórios | Profissional | ? |
| Backup na nuvem | Profissional | ? |

**Capturar:** tabela preenchida + qualquer discrepância (seção liberada sem o plano correto, ou bloqueada incorretamente).

---

## Bloco 5 — PKG em outro Mac

**O que testar:**

1. Copiar `dist/releases/Luum-0.1.0-alpha.pkg` para outro Mac
2. Tentar instalar — Gatekeeper deve bloquear (sem Developer ID)
3. Instalar mesmo assim via **clique direito → Abrir** ou:
   ```bash
   sudo installer -pkg /path/to/Luum-0.1.0-alpha.pkg -target /
   ```
4. Abrir o app instalado e verificar se inicia normalmente

**Capturar:**

- Mensagem exata do Gatekeeper
- Se a instalação manual funcionou
- Se o app abriu sem crash
- Versão exibida no "Sobre o Luum"

---

## Formato de entrega

Ao concluir um ou mais blocos, criar um arquivo em:

```
/Users/zainlet/Desktop/APP LUUM/luum/docs/CODEX_RELATORIO_[BLOCO].md
```

Exemplo: `CODEX_RELATORIO_LOGOUT.md`, `CODEX_RELATORIO_STRIPE.md`

### Estrutura obrigatória do relatório

```markdown
# Relatório Codex — [Nome do Bloco]
Data: YYYY-MM-DD HH:MM

## Resultado geral
PASSOU / FALHOU / PARCIAL

## Itens testados

### [Nome do item]
- Status: PASSOU | FALHOU | NÃO TESTADO
- Comportamento observado: (descrição curta)
- Comportamento esperado: (o que deveria acontecer)
- Evidência:
  ```
  [log, saída de terminal, JSON, ou descrição do que foi visto na tela]
  ```

## Erros e crashes

[Lista de erros encontrados, com arquivo/linha se disponível]

## Arquivos suspeitos

[Quaisquer arquivos de log, JSON de preferências ou saída de build relevante]

## Próximo passo sugerido

[O que o Codex acha que o Claude Code deve corrigir primeiro]
```

### Regras do relatório

- **Nunca incluir tokens, senhas, chaves de API ou segredos** — substituir por `[REDACTED]`
- Incluir saídas de terminal literais, não paráfrases
- Se um teste não pôde ser executado, explicar o bloqueador
- Um arquivo por bloco — não misturar Stripe com logout no mesmo relatório

---

## Ordem sugerida de execução

1. **Bloco 1** (logout) — mais rápido, valida correção já commitada
2. **Bloco 2** (XCTest) — independente, pode rodar em paralelo
3. **Bloco 3** (Stripe) — depende de ter cartão disponível
4. **Bloco 4** (gates) — depende do Bloco 3 para testar planos pagos
5. **Bloco 5** (PKG) — depende de ter acesso a outro Mac

---

## O que o Claude Code faz com o relatório

Assim que um `CODEX_RELATORIO_*.md` for salvo na pasta `docs/`, o Claude Code:

1. Lê o relatório
2. Localiza os arquivos e linhas correspondentes aos erros
3. Aplica as correções
4. Atualiza a `META_LUUM_ATUALIZADA.md` com o que foi validado
5. Faz commit das correções com referência ao relatório do Codex
