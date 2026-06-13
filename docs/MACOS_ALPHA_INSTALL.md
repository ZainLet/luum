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

O script gera três arquivos em `dist/releases/`:

- `Luum-...zip`: app compactado.
- `Luum-...zip.sha256`: checksum para conferir integridade.
- `Luum-...zip.txt`: notas rápidas da build.

## Instalar em outro Mac

1. Transfira o `.zip` para o Mac de teste.
2. Abra o `.zip`.
3. Arraste `Luum.app` para `Aplicativos`.
4. No primeiro uso, abra com `Control-click > Abrir`.
5. Entre pelo app e finalize o login no site quando o navegador abrir.
6. Quando o macOS pedir Automação para o navegador, permita. Essa permissão é necessária para ler a aba ativa.

## Se o macOS bloquear a abertura

Sem Apple Developer ID, o Gatekeeper pode bloquear o primeiro launch. Primeiro tente:

1. `Control-click` no `Luum.app`.
2. Clique em `Abrir`.
3. Confirme `Abrir` de novo.

Se isso ainda falhar em um Mac de teste interno, remova a quarentena manualmente:

```bash
xattr -dr com.apple.quarantine /Applications/Luum.app
```

Depois abra o app novamente.

## Validar o app instalado

No Mac de teste:

```bash
codesign --verify --deep --strict --verbose=2 /Applications/Luum.app
spctl --assess --type execute --verbose=4 /Applications/Luum.app
```

Com assinatura ad-hoc, `codesign --verify` deve passar. O `spctl` pode rejeitar por falta de notarização; isso é esperado nesta alpha sem Apple Developer ID.

## Quando isso muda

Para distribuição pública sem alerta de segurança, ainda falta:

- Apple Developer Program.
- Certificado Developer ID Application.
- Hardened runtime.
- Notarização com `notarytool`.
- `stapler` no artefato final.
- Teste em Mac limpo.
