#!/usr/bin/env bash
# Instalação dos 10 repositórios — Maffei
# Uso:  bash instalar-repos.sh
#       bash instalar-repos.sh --so-clone     (só baixa, não instala nada)

set -uo pipefail

BASE="${HOME}/github"
SKILLS_DIR="${HOME}/.claude/skills"
SO_CLONE=0
[ "${1:-}" = "--so-clone" ] && SO_CLONE=1

ok()    { printf '  \033[32m✓\033[0m %s\n' "$1"; }
aviso() { printf '  \033[33m!\033[0m %s\n' "$1"; }
erro()  { printf '  \033[31m✗\033[0m %s\n' "$1"; }
titulo(){ printf '\n\033[1m== %s\033[0m\n' "$1"; }

PENDENTES=()

tem() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- pré-requisitos
titulo "Pré-requisitos"
tem git || { erro "git não encontrado — instale antes de continuar."; exit 1; }
ok "git $(git --version | awk '{print $3}')"

for c in node npm pnpm python3 docker claude; do
  if tem "$c"; then ok "$c"; else aviso "$c ausente (alguns passos serão pulados)"; fi
done

# ---------------------------------------------------------------- clone
clonar() {
  local url="$1" nome="$2"
  if [ -d "${BASE}/${nome}/.git" ]; then
    ok "${nome} já existe — atualizando"
    git -C "${BASE}/${nome}" pull --ff-only -q 2>/dev/null || aviso "${nome}: pull falhou, mantendo versão local"
  elif git clone --depth 1 -q "$url" "${BASE}/${nome}"; then
    ok "${nome} clonado"
  else
    erro "${nome}: clone falhou"
    return 1
  fi
}

titulo "Clonando em ${BASE}"
mkdir -p "$BASE"
clonar https://github.com/Egonex-AI/Understand-Anything.git          Understand-Anything
clonar https://github.com/anthropics/knowledge-work-plugins.git      knowledge-work-plugins
clonar https://github.com/mukul975/Anthropic-Cybersecurity-Skills.git Anthropic-Cybersecurity-Skills
clonar https://github.com/hardikpandya/stop-slop.git                 stop-slop
clonar https://github.com/Leonxlnx/taste-skill.git                   taste-skill
clonar https://github.com/colbymchenry/codegraph.git                 codegraph
clonar https://github.com/microsoft/markitdown.git                   markitdown
clonar https://github.com/rohitg00/ai-engineering-from-scratch.git   ai-engineering-from-scratch
clonar https://github.com/deepseek-ai/deepseek-harness.git           deepseek-harness
clonar https://github.com/harry0703/MoneyPrinterTurbo.git            MoneyPrinterTurbo

if [ "$SO_CLONE" = "1" ]; then
  titulo "Pronto (modo --so-clone)"; exit 0
fi

# ---------------------------------------------------------------- plugins Claude Code
titulo "Plugins do Claude Code"
if tem claude; then
  for p in Understand-Anything knowledge-work-plugins Anthropic-Cybersecurity-Skills; do
    if claude plugin marketplace add "${BASE}/${p}" >/dev/null 2>&1; then
      ok "marketplace ${p} adicionado"
    else
      aviso "${p}: já adicionado ou falhou"
    fi
  done
  # Understand-Anything expõe um plugin único; os outros dois têm vários.
  claude plugin install understand-anything >/dev/null 2>&1 \
    && ok "understand-anything instalado" \
    || aviso "understand-anything: instale manualmente"
  PENDENTES+=("Escolher plugins: claude plugin install marketing@knowledge-work-plugins (e sales, small-business)")
  PENDENTES+=("Skills de segurança: claude plugin install cybersecurity-skills@anthropic-cybersecurity-skills")
else
  aviso "CLI 'claude' ausente — pulando marketplaces"
  PENDENTES+=("Instalar Claude Code e rodar: claude plugin marketplace add ${BASE}/<repo>")
fi

# ---------------------------------------------------------------- skills avulsas
titulo "Skills avulsas"
mkdir -p "$SKILLS_DIR"
if [ -d "${BASE}/stop-slop" ]; then
  rm -rf "${SKILLS_DIR}/stop-slop"
  cp -r "${BASE}/stop-slop" "${SKILLS_DIR}/stop-slop"
  rm -rf "${SKILLS_DIR}/stop-slop/.git"
  ok "stop-slop → ${SKILLS_DIR}/stop-slop"
fi

if tem npx; then
  if npx -y skills add https://github.com/Leonxlnx/taste-skill; then
    ok "taste-skill instalado (10 skills)"
  else
    aviso "taste-skill: falhou"
    PENDENTES+=("npx skills add https://github.com/Leonxlnx/taste-skill")
  fi
else
  PENDENTES+=("npx skills add https://github.com/Leonxlnx/taste-skill")
fi

# ---------------------------------------------------------------- codegraph
titulo "CodeGraph"
if tem npm; then
  if npm i -g @colbymchenry/codegraph >/dev/null 2>&1; then
    ok "codegraph instalado globalmente"
    PENDENTES+=("Conectar ao agente:  npx @colbymchenry/codegraph")
    PENDENTES+=("Indexar cada projeto: cd <projeto> && codegraph init")
  else
    aviso "npm -g falhou (talvez precise de sudo)"
    PENDENTES+=("sudo npm i -g @colbymchenry/codegraph")
  fi
else
  PENDENTES+=("npm i -g @colbymchenry/codegraph")
fi

# ---------------------------------------------------------------- markitdown
titulo "MarkItDown"
if tem python3; then
  # venv dedicada — evita mexer no Python do sistema
  VENV="${BASE}/.venv-markitdown"
  python3 -m venv "$VENV" 2>/dev/null
  if [ -x "${VENV}/bin/pip" ]; then
    "${VENV}/bin/pip" install -q --upgrade pip
    if "${VENV}/bin/pip" install -q -e "${BASE}/markitdown/packages/markitdown[all]"; then
      ok "markitdown instalado em ${VENV}"
      PENDENTES+=("Usar markitdown:  ${VENV}/bin/markitdown arquivo.pdf > saida.md")
    else
      erro "markitdown: instalação falhou"
    fi
  else
    aviso "venv falhou — instale o pacote python3-venv"
    PENDENTES+=("pip install 'markitdown[all]'")
  fi
else
  PENDENTES+=("pip install 'markitdown[all]'")
fi

# ---------------------------------------------------------------- deepseek-harness
titulo "DeepSeek Harness"
if tem pnpm; then
  ( cd "${BASE}/deepseek-harness" && pnpm install --silent && pnpm run build ) \
    && { ok "build concluído"; PENDENTES+=("Rodar a Web UI: cd ${BASE}/deepseek-harness && pnpm dsh web"); } \
    || { aviso "build falhou"; PENDENTES+=("Alternativa sem build: npx @deepseek-ai/dsh web"); }
else
  aviso "pnpm ausente"
  PENDENTES+=("npm i -g pnpm  →  cd ${BASE}/deepseek-harness && pnpm install && pnpm run build")
fi

# ---------------------------------------------------------------- MoneyPrinterTurbo
titulo "MoneyPrinterTurbo"
if [ -f "${BASE}/MoneyPrinterTurbo/config.example.toml" ] && [ ! -f "${BASE}/MoneyPrinterTurbo/config.toml" ]; then
  cp "${BASE}/MoneyPrinterTurbo/config.example.toml" "${BASE}/MoneyPrinterTurbo/config.toml"
  ok "config.toml criado"
fi
aviso "precisa das chaves de API no config.toml antes de subir"
PENDENTES+=("cd ${BASE}/MoneyPrinterTurbo && docker compose -f docker-compose.release.yml up")

# ---------------------------------------------------------------- ai-engineering
titulo "AI Engineering from Scratch"
ok "material de leitura em ${BASE}/ai-engineering-from-scratch (sem instalação)"

# ---------------------------------------------------------------- resumo
titulo "Falta fazer manualmente"
if [ ${#PENDENTES[@]} -eq 0 ]; then
  ok "nada pendente"
else
  for p in "${PENDENTES[@]}"; do printf '  → %s\n' "$p"; done
fi
printf '\nEspaço usado: %s\n' "$(du -sh "$BASE" 2>/dev/null | cut -f1)"
