# accelix-ai-plugins

AccelixGames 팀 전용 Claude Code 플러그인 마켓플레이스입니다.

## 설치

```bash
# 1. 마켓플레이스 등록 (최초 1회)
claude plugin marketplace add AccelixGames/accelix-ai-plugins

# 2. 원하는 플러그인 설치
claude plugin install claude-plastic-scm
claude plugin install win-file-tools
```

## 업데이트

```bash
# 마켓플레이스 + 플러그인 모두 업데이트
claude plugin marketplace update accelix-ai-plugins
claude plugin update claude-plastic-scm@accelix-ai-plugins
claude plugin update win-file-tools@accelix-ai-plugins
```

## 제거

```bash
claude plugin uninstall claude-plastic-scm
claude plugin uninstall win-file-tools
```

---

## 플러그인 목록

| 플러그인 | 설명 | 상세 |
|----------|------|------|
| [claude-plastic-scm](plugins/claude-plastic-scm/README.md) | PlasticSCM (Unity Version Control) 워크플로우 자동화 | 체크인, 코멘트, 컴파일 체크, 숨김 관리, 병합, 브랜치 조회, 상태, 이력, 비교 |

---

### win-file-tools

Windows 환경 문서 도구 — 파일 읽기(PDF, DOCX, Excel, HWP) + HWP/HWPX 문서 생성/편집.

**요구사항:** Python 3.8+, PyMuPDF, python-docx, openpyxl, olefile, python-hwpx

| 스킬 | 설명 | 자동 트리거 |
|------|------|------------|
| `win-file-reader` | 파일 읽기 + 자기 강화 에러 패턴 라이브러리 | PDF/DOCX/Excel/HWP 읽기, 문서 에러 발생 시 |
| `hwpx` | HWP/HWPX 문서 생성/편집 | 한글 문서, hwpx, 보고서, 공문 작성 시 |

---

## 라이선스

MIT License
