#!/usr/bin/env bash
set -uo pipefail
# set -e 제거 — 개별 실패를 직접 처리, 스크립트 중단 방지

# ============================================================
# AccelixGames 팀 온보딩 스크립트
# 신규 팀원이 1회 실행하면 Claude Code 환경이 세팅됩니다.
# 이미 설치된 항목은 자동 스킵하고, 구버전은 업데이트합니다.
# 몇 번을 돌려도 안전합니다 (멱등성 보장).
# ============================================================

ERRORS=0

echo "=== AccelixGames Team Setup ==="
echo ""

# ── 0. 전제조건 확인 ──────────────────────────────────────
check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "❌ $1 이(가) 설치되어 있지 않습니다."
    echo "   설치: $2"
    ERRORS=$((ERRORS + 1))
    return 1
  fi
  echo "✅ $1 확인됨"
  return 0
}

check_cmd "node"   "https://nodejs.org (v20+)"
check_cmd "npm"    "Node.js 설치 시 함께 설치됩니다"
check_cmd "git"    "https://git-scm.com"
check_cmd "claude" "https://docs.anthropic.com/en/docs/claude-code"

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "⛔ 전제조건 ${ERRORS}개 미충족. 위 안내에 따라 설치 후 다시 실행해주세요."
  exit 1
fi

echo ""

# ── 1. 마켓플레이스 등록 ──────────────────────────────────
echo "--- 마켓플레이스 등록 ---"

register_marketplace() {
  local name="$1" repo="$2" desc="$3"
  echo "📦 $name ($desc)"
  if claude plugin marketplace add "$repo" 2>&1 | grep -qi "already"; then
    echo "   (이미 등록됨)"
  elif [ $? -ne 0 ]; then
    echo "   ⚠️  등록 실패 — 수동 확인 필요: claude plugin marketplace add $repo"
    ERRORS=$((ERRORS + 1))
  fi
}

register_marketplace "claude-plugins-official" "anthropics/claude-plugins-official" "Anthropic 공식"
register_marketplace "accelix-ai-plugins"      "AccelixGames/accelix-ai-plugins"    "팀 전용"

echo ""

# ── 2. 플러그인 설치/업데이트 ────────────────────────────
echo "--- 플러그인 설치 ---"

install_plugin() {
  local plugin="$1" marketplace="$2" label="$3"
  local full="${plugin}@${marketplace}"
  echo "📥 $plugin ($label)"

  # 설치 시도 — 이미 있으면 update
  output=$(claude plugin install "$full" 2>&1) || true

  if echo "$output" | grep -qi "already installed\|already exists"; then
    # 이미 설치됨 → 업데이트 시도
    update_output=$(claude plugin update "$full" 2>&1) || true
    if echo "$update_output" | grep -qi "up to date\|no update"; then
      echo "   ✅ 최신 버전"
    elif echo "$update_output" | grep -qi "updated\|success"; then
      echo "   🔄 업데이트 완료"
    else
      echo "   ✅ 설치됨"
    fi
  elif echo "$output" | grep -qi "success\|installed"; then
    echo "   ✅ 새로 설치 완료"
  else
    echo "   ⚠️  설치 실패 — 수동 확인: claude plugin install $full"
    ERRORS=$((ERRORS + 1))
  fi
}

# 공식 플러그인
install_plugin "superpowers"     "claude-plugins-official" "공식"
install_plugin "frontend-design" "claude-plugins-official" "공식"
install_plugin "skill-creator"   "claude-plugins-official" "공식"
install_plugin "figma"           "claude-plugins-official" "공식"
install_plugin "notion"          "claude-plugins-official" "공식"

# 팀 플러그인
install_plugin "claude-plastic-scm" "accelix-ai-plugins" "팀"
install_plugin "generate-image"     "accelix-ai-plugins" "팀"
install_plugin "win-file-tools"     "accelix-ai-plugins" "팀"
install_plugin "discord-webhook"    "accelix-ai-plugins" "팀"
install_plugin "prof-oak-explain"   "accelix-ai-plugins" "팀"
install_plugin "chatgpt-agent"      "accelix-ai-plugins" "팀"

echo ""

# ── 3. CLI 도구 설치 ─────────────────────────────────────
echo "--- CLI 도구 설치 ---"

install_npm_global() {
  local name="$1" package="$2" check_cmd="$3"

  if eval "$check_cmd" 2>/dev/null; then
    echo "✅ $name 이미 설치됨"
  else
    echo "📥 $name 설치 중..."
    if npm install -g "$package" 2>&1; then
      echo "   ✅ $name 설치 완료"
    else
      echo "   ⚠️  $name 설치 실패"
      echo "   수동 설치: npm install -g $package"
      echo "   (권한 문제 시: sudo npm install -g $package)"
      ERRORS=$((ERRORS + 1))
    fi
  fi
}

install_npm_global "gws (Google Workspace CLI)" "@googleworkspace/cli" "command -v gws"
install_npm_global "@google/genai"              "@google/genai"        "node -e \"require('@google/genai')\""

echo ""

# ── 4. gstack 설치 ───────────────────────────────────────
echo "--- gstack 설치 ---"

GSTACK_REPO="https://github.com/garrytan/gstack.git"
GSTACK_DIR="$HOME/github.com/AccelixGames/gstack"

if [ -d "$GSTACK_DIR" ]; then
  echo "✅ gstack 이미 설치됨 ($GSTACK_DIR)"
  # 업데이트 시도
  echo "   🔄 최신 버전 확인 중..."
  if (cd "$GSTACK_DIR" && git pull --ff-only 2>&1) | grep -qi "already up to date"; then
    echo "   ✅ 최신 버전"
  else
    echo "   🔄 업데이트 완료"
  fi
else
  echo "📥 gstack 클론 중..."
  mkdir -p "$(dirname "$GSTACK_DIR")"
  if git clone "$GSTACK_REPO" "$GSTACK_DIR" 2>&1; then
    echo "   ✅ gstack 클론 완료"
  else
    echo "   ⚠️  gstack 클론 실패"
    echo "   수동 설치: git clone $GSTACK_REPO $GSTACK_DIR"
    ERRORS=$((ERRORS + 1))
  fi
fi

# bun 설치 확인 (gstack 의존성)
if command -v bun &>/dev/null; then
  echo "✅ bun 확인됨"
  if [ -d "$GSTACK_DIR" ]; then
    echo "   📥 gstack 의존성 설치 중..."
    (cd "$GSTACK_DIR" && bun install 2>&1) || true
  fi
else
  echo "⚠️  bun 미설치 — gstack 일부 기능에 필요"
  echo "   설치: curl -fsSL https://bun.sh/install | bash"
  ERRORS=$((ERRORS + 1))
fi

echo ""

# ── 5. 결과 리포트 ───────────────────────────────────────
if [ $ERRORS -eq 0 ]; then
  echo "=== ✅ 설정 완료! ==="
else
  echo "=== ⚠️  설정 완료 (경고 ${ERRORS}개) ==="
  echo "위 ⚠️ 항목을 수동으로 확인해주세요."
fi

echo ""
echo "다음 단계:"
echo "  1. gstack dev-setup (프로젝트에 gstack 연결):"
echo "     cd <프로젝트> && $GSTACK_DIR/bin/dev-setup"
echo "  2. Gemini API key 설정 (이미지 생성 사용 시):"
echo "     claude mcp add image-gen --scope user -e GEMINI_API_KEY=<key> -- npx -y mcp-image"
echo "  3. gws 인증 (Google Sheets/Docs 사용 시):"
echo "     gws auth login"
echo "  4. Discord 웹훅 설정 (알림 사용 시):"
echo "     프로젝트 루트에 .discord-webhook-config.json 생성"
echo ""
echo "문제가 있으면 규혁님(@neonstarQ)에게 문의하세요."
