#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_PROJECT="$ROOT_DIR/src/LUUM.API/LUUM.API.csproj"

if ! command -v dotnet >/dev/null 2>&1; then
  echo "dotnet nao encontrado. Instale o .NET 8 SDK para rodar a API local." >&2
  exit 1
fi

export ASPNETCORE_ENVIRONMENT="${ASPNETCORE_ENVIRONMENT:-Development}"
export Firestore__ProjectId="${Firestore__ProjectId:-luum-94e83}"
export Firestore__UseEmulator="${Firestore__UseEmulator:-true}"
export Firestore__EmulatorHost="${Firestore__EmulatorHost:-127.0.0.1}"
export Firestore__EmulatorPort="${Firestore__EmulatorPort:-8082}"

dotnet run --project "$API_PROJECT"
