# Instalação da alpha macOS

Este guia é para testar o Luum em outro Mac antes de termos Apple Developer ID, assinatura Developer ID e notarização.

## Requisitos

- macOS 26 ou superior.
- Conta Luum/Firebase criada pelo site oficial.
- Acesso a `https://luum-app.web.app` e `https://luum-app.vercel.app`.

## Gerar o pacote

No Mac de desenvolvimento:

```bash
./script/build_and_run.sh --package
```

O script gera os artefatos em `dist/releases/`. Para teste em outro Mac, prefira o `.pkg`: ele instala `luum.app` em `/Applications` com duplo clique, sem terminal.

- `Luum-...pkg`: instalador simples da alpha.
- `Luum-...pkg.sha256`: checksum do instalador.
- `Luum-...pkg.txt`: notas rápidas do instalador.
- `Luum-...zip`: fallback técnico com o app bundle completo `luum.app`, não arquivos soltos.
- `Luum-...zip.sha256`: checksum para conferir integridade.
- `Luum-...zip.txt`: notas rápidas da build.

## Versoes alpha

Durante a fase alpha, avance o ultimo digito para builds pequenos de teste, por exemplo `v0.0.3`, `v0.0.4` e `v0.0.5`. Reserve o digito do meio para mudancas grandes que precisam ficar faceis de identificar, como a reformulacao de UI/UX: `v0.1.0`. A versao `v1.0.0` fica reservada para o lancamento final/publico.

## Instalar em outro Mac

1. Transfira o `.pkg` para o Mac de teste.
2. Abra o `.pkg` com duplo clique.
3. Siga o instalador para colocar `luum.app` em `Aplicativos`.
4. No primeiro uso, abra com `Control-click > Abrir`.
5. Entre pelo app e finalize o login no site quando o navegador abrir.
6. Quando o macOS pedir Automação para o navegador, permita. Essa permissão é necessária para ler a aba ativa.

Se estiver usando o `.zip` fallback, abra o zip e arraste `luum.app` manualmente para `Aplicativos`.

## Se o macOS bloquear a abertura

Sem Apple Developer ID, o Gatekeeper pode bloquear o primeiro launch. Primeiro tente:

1. `Control-click` no `luum.app`.
2. Clique em `Abrir`.
3. Confirme `Abrir` de novo.

Se isso ainda falhar em um Mac de teste interno, remova a quarentena manualmente:

```bash
xattr -dr com.apple.quarantine /Applications/luum.app
```

Depois abra o app novamente.

## Se aparecer prompt das Chaves do macOS

A alpha atual salva sessão e tokens em um cofre local cifrado, sem usar as Chaves do macOS por padrão. Isso evita o prompt repetido causado por builds ad-hoc com assinatura diferente.

Se um Mac que já testou builds antigos ainda mostrar uma janela pedindo senha para acessar o item `login` em `com.zainlet.luum`, feche o app e limpe o item legado:

```bash
security delete-generic-password -s com.zainlet.luum -a login 2>/dev/null || true
```

Depois abra o Luum novamente. O app também tenta limpar esse item silenciosamente no início, mas esse comando ajuda quando o macOS já deixou a janela de permissão pendente.

## Validar o app instalado

No Mac de teste:

```bash
codesign --verify --deep --strict --verbose=2 /Applications/luum.app
spctl --assess --type execute --verbose=4 /Applications/luum.app
```

Com assinatura ad-hoc, `codesign --verify` deve passar. O `spctl` pode rejeitar por falta de notarização; isso é esperado nesta alpha sem Apple Developer ID. O instalador `.pkg` também fica sem assinatura/notarização nesta fase.

## Quando isso muda

Para distribuição pública sem alerta de segurança, ainda falta:

- Apple Developer Program.
- Certificado Developer ID Application.
- Hardened runtime.
- Notarização com `notarytool`.
- `stapler` no artefato final.
- Teste em Mac limpo.
