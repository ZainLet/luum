# Testes de Carga — k6

## Requisitos

- [k6](https://k6.io/docs/getting-started/installation/) — `brew install k6`
- Servidor local da API rodando (Vercel dev ou emulador)

## Como rodar

### 1. Iniciar servidor local

```bash
npx vercel dev --listen 3000
```

Ou usar Firebase Emulator Suite + mock do Gemini:

```bash
firebase emulators:start
```

### 2. Executar teste de carga

```bash
cd website
k6 run test/load/k6-basic.mjs
```

Com variáveis de ambiente customizadas:

```bash
k6 run -e BASE_URL=http://localhost:3000 \
       -e AUTH_TOKEN=seu-token-firebase \
       -e USER_ID=load-test-user-001 \
       test/load/k6-basic.mjs
```

### 3. Executar com saída detalhada

```bash
k6 run --summary-trend-stats="med,p(90),p(95),p(99)" test/load/k6-basic.mjs
```

## Endpoints testados

| Grupo | Método | Threshold p95 |
|-------|--------|---------------|
| `/api/auth/status` | GET | < 800ms |
| `/api/sync/:uid` | POST (upload) | < 2s |
| `/api/sync/:uid` | GET (download) | < 2s |
| `/api/ai/classify` | POST | < 2s |

## Critérios de aceite

- p95 latência < 800ms em `/api/auth/status`
- p95 latência < 2s em `/api/ai/classify`
- Taxa de erro < 1% em todos os endpoints

## Resultados de referência

| Data | Execução | auth_status p95 | classify p95 | Erro |
|------|----------|-----------------|--------------|------|
| — | — | — | — | — |

## Notas

- **Nunca rodar contra produção.** Sempre usar emulador local ou ambiente de staging.
- O teste de `classify` aceita tanto 200 quanto 503 porque a chave Gemini pode não estar configurada localmente.
- O teste simula 50 usuários simultâneos com rampa de 10s de aquecimento e 10s de desaquecimento.
