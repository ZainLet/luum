#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${FIRESTORE_PROJECT_ID:-luum-94e83}"
API_SCRIPT="$ROOT_DIR/script/run_api.sh"

if ! command -v firebase >/dev/null 2>&1; then
  echo "firebase nao encontrado. Instale o Firebase CLI para subir o Firestore Emulator." >&2
  exit 1
fi

if ! command -v dotnet >/dev/null 2>&1; then
  echo "dotnet nao encontrado. Instale o .NET 8 SDK para rodar a API local." >&2
  exit 1
fi

cd "$ROOT_DIR"
firebase emulators:exec --only firestore --project "$PROJECT_ID" "$API_SCRIPT"
