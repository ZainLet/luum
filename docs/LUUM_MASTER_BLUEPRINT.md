# Luum Master Product Blueprint

**Objetivo:** transformar o Luum em um app incrível, inspirado no que o Rize faz bem, mas com uma proposta mais forte: não ser apenas um rastreador de tempo, e sim um **Work Intelligence OS** para pessoas, freelancers, founders, agências e times que querem entender, planejar, executar e melhorar o trabalho com ajuda de IA.

**Fonte visual de referência:** PDF `rize.pdf` enviado com telas do Rize.

---

## 1. Resumo executivo

O Rize parece muito bom em três coisas:

1. **Onboarding guiado**
2. **Time tracking automático**
3. **Visualização de produtividade, atividades, calendário e relatórios**

Mas o Luum pode ir além. O espaço de oportunidade está em construir uma camada superior de inteligência:

* O Rize mostra **onde o tempo foi gasto**.
* O Luum deve explicar **por que isso aconteceu**.
* O Rize ajuda a revisar produtividade.
* O Luum deve ajudar a **tomar decisões e executar melhor**.
* O Rize rastreia.
* O Luum deve **orquestrar o trabalho**.

A visão recomendada:

> **Luum: seu sistema operacional inteligente de trabalho. Ele entende seu tempo, seus projetos, seus clientes, sua agenda e seu contexto para recomendar a próxima melhor ação.**

---

## 2. Posicionamento estratégico

### 2.1 O que o Luum não deve ser

* Um clone do Rize.
* Um app de timer.
* Um dashboard bonito de produtividade.
* Um app que só mostra gráficos.
* Um software que exige muito input manual.
* Um app que só funciona depois de semanas de dados.

### 2.2 O que o Luum deve ser

* Um **copiloto de produtividade e execução**.
* Um **time tracker inteligente**, mas não limitado a isso.
* Um **dashboard operacional** para pessoas e times.
* Um **assistente de decisão**.
* Um **sistema de contexto** conectado a calendário, tarefas, clientes, projetos, documentos e reuniões.
* Um app que transforma dados passivos em ações concretas.

### 2.3 Frase de posicionamento

> **Luum ajuda você a transformar tempo, contexto e trabalho em decisões melhores.**

---

## 3. Diferenciação vs Rize

| Dimensão | Rize | Luum |
|---|---|---|
| Pergunta central | Onde o tempo foi? | O que fazer agora? |
| Foco | Tracking e visualização | Decisão e execução |
| IA | Categorização | Copiloto proativo |
| Contexto | Apps e tempo | Calendário + tarefas + clientes + projetos |
| Output | Relatórios | Ações recomendadas |
| Memória | Sessão | Longo prazo |
| Linguagem | Métricas | Clareza narrativa |

---

## 4. Design System

### Paleta de cores

```css
:root {
  --background: #08090d;
  --surface-1: #101117;
  --surface-2: #171923;
  --surface-3: #202333;

  --border-subtle: #2a2d3a;
  --border-strong: #3a3f52;

  --text-primary: #f4f6fb;
  --text-secondary: #b7bccb;
  --text-muted: #777d91;

  --primary: #7c5cff;
  --primary-hover: #8b73ff;
  --primary-soft: rgba(124, 92, 255, 0.16);

  --accent-cyan: #38d5ff;
  --accent-green: #35e6a3;
  --accent-yellow: #ffd166;
  --accent-red: #ff4d6d;

  --focus: #41f0c4;
  --meeting: #7c5cff;
  --admin: #9aa4b2;
  --distraction: #ff4d6d;
}
```

### Tipografia

* Inter, Geist ou Satoshi
* Títulos: 600/700 weight
* Corpo: 400/500 weight
* Números: variante tabular

### Conceito visual

**"Calm Intelligence"** — escuro mas não pesado, alto contraste, muito espaço negativo, cards com hierarquia forte, microinterações suaves.

---

## 5. Módulos do produto

### 5.1 Home / Command Center

Cards principais:
* Próxima melhor ação
* Daily Brief (reuniões, prioridades, riscos)
* Work Health (foco, fragmentação, horas úteis)
* Project Radar
* Client Radar
* AI Chat

### 5.2 Calendar Intelligence

* Planejado vs executado
* Custo de reuniões
* Sugestão de blocos de foco
* Classificação de reuniões
* Detecção de reuniões que poderiam ser async

### 5.3 Focus Engine

Tipos de sessão: Coding, Writing, Design, Planning, Admin, Client work, Study, Review

Métricas: duração, tempo em contexto, trocas de janela, apps úteis vs distrativos

### 5.4 Activity Intelligence

Categorias: Focus work, Communication, Meetings, Planning, Admin, Research, Coding, Design, Writing, Learning, Entertainment, Unknown

Diferencial: classificar **intenção**, não apenas o app.

### 5.5 Client OS

Entidades: Client, Contact, Contract, Project, Invoice, Time entry, Meeting, Report, Health score

### 5.6 Project OS

Risk score baseado em: prazo próximo, baixa atividade, muitas reuniões, tarefas bloqueadas, orçamento vs progresso

### 5.7 Tasks

Campos: title, description, status, priority, estimate_minutes, actual_minutes, due_date, project_id, client_id, source, assignee_id, tags, ai_summary, risk_level

### 5.8 Revenue Intelligence

Alertas: margem baixa, orçamento estourado, horas não faturadas, forecast em queda

### 5.9 AI Reports

Tipos: Daily summary, Weekly review, Client report, Project status, Focus report, Revenue report, Team report, Meeting report, Retrospective

Formatos: In-app, PDF, Email, Markdown, Link compartilhável, Slack/Discord

### 5.10 AI Copilot

Perguntas suportadas:
* "O que eu fiz hoje?"
* "O que devo fazer agora?"
* "Qual projeto está em risco?"
* "Qual cliente foi menos rentável este mês?"
* "Gere um relatório para o cliente X."
* "Quais reuniões posso cancelar?"

---

## 6. Onboarding recomendado

**Aha moment desejado:** "O Luum entendeu meu trabalho e já montou uma central inteligente para mim."

Fluxo:
1. Promessa principal
2. Objetivo desejado (foco / projetos / clientes / relatórios / planejamento / time)
3. Perfil (solo / freelancer / agência / startup / time / estudante)
4. Conectar ferramentas
5. Explicação de privacidade
6. IA monta workspace
7. Recomendação personalizada
8. Primeiro plano do dia

---

## 7. Arquitetura técnica recomendada

### Stack web (nova plataforma)

Frontend: Next.js App Router, TypeScript, Tailwind CSS, shadcn/ui, Radix UI, Framer Motion, TanStack Query

Backend: Supabase Postgres, Supabase Auth, Supabase Realtime, Edge Functions

Jobs: Trigger.dev / Inngest / Supabase cron

IA: Claude/OpenAI, Embeddings, pgvector, Tool calling, Background agents

Analytics: PostHog, Sentry, OpenTelemetry

Desktop tracking: Electron ou Tauri

### Estrutura de monorepo

```
luum/
  apps/
    web/
    desktop/
    extension/
  packages/
    ui/
    db/
    ai/
    config/
    integrations/
    tracking/
    types/
  supabase/
    migrations/
    seed.sql
```

---

## 8. Schema SQL principal

Ver seção 7.5 do documento original para schema completo com tabelas:
- workspaces
- workspace_members
- clients
- projects
- tasks
- time_entries
- activity_events
- focus_sessions
- calendar_events
- ai_insights
- ai_memories

---

## 9. Roadmap de 6 meses

| Mês | Foco |
|---|---|
| 1 | Auth, workspace, onboarding, app shell, dashboard, CRUD, design system |
| 2 | Google Calendar, activity events, focus sessions, timeline, reports básicos, desktop alpha |
| 3 | AI daily summary, auto-categorization v1, AI chat, insights, weekly review |
| 4 | Project risk score, client profitability, budget tracking, AI project status |
| 5 | Rules engine, scheduled reports, meeting intelligence, task suggestions, focus planning |
| 6 | Team dashboard, permissions, client portal, revenue forecast, polishing |

---

## 10. Backlog priorizado

### P0 - MVP essencial
Auth, workspace, onboarding, dashboard, clientes, projetos, tarefas, time entries, activity timeline, focus sessions, relatórios básicos, AI daily summary

### P1 - Diferenciação forte
Auto-categorização por IA, project risk score, client profitability, AI reports, calendar intelligence, meeting classification, focus score, rules engine, import Linear/ClickUp/GitHub

### P2 - Produto premium
Agente semanal, planejamento automático, revenue forecast, portal do cliente, team analytics, Slack bot, Notion integration, voice input, mobile app

### P3 - Moat
Memória de longo prazo, personal work graph, modelos preditivos, benchmark anônimo, automação multi-agente, marketplace de templates, API pública

---

## 11. North Star Metric

**Weekly Meaningful Work Hours Organized** — horas semanais rastreadas, categorizadas, associadas a contexto e usadas em insight ou decisão.

---

## 12. Critérios de qualidade

Uma feature só deve ser lançada se cumprir pelo menos 3 destes:
* Reduz input manual
* Ajuda o usuário a decidir
* Melhora foco
* Recupera tempo ou dinheiro
* Explica um padrão
* Automatiza uma tarefa
* Conecta dados antes separados
* Gera clareza em menos de 30s

---

## 13. Conclusão

> **Rize mede trabalho. Luum entende trabalho.**
