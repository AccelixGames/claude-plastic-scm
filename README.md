# accelix-ai-plugins

AccelixGames 팀 전용 Claude Code 플러그인 마켓플레이스입니다.

## 설치

```bash
# 1. 마켓플레이스 등록 (최초 1회)
claude plugin marketplace add AccelixGames/accelix-ai-plugins

# 2. 원하는 플러그인 설치
claude plugin install claude-plastic-scm
```

## 업데이트

```bash
# 마켓플레이스 + 플러그인 모두 업데이트
claude plugin marketplace update accelix-ai-plugins
claude plugin update claude-plastic-scm@accelix-ai-plugins
```

## 제거

```bash
claude plugin uninstall claude-plastic-scm
```

---

## 플러그인 목록

### claude-plastic-scm

PlasticSCM (Unity Version Control) 워크플로우 자동화.

**요구사항:** PlasticSCM CLI (`cm`)

| 명령 | 설명 | 사용법 |
|------|------|--------|
| `/cm-checkin` | 변경 분석 후 코멘트 자동 생성 → 체크인 | `/cm-checkin` |
| `/cm-merge-comment` | 병합된 서브 브랜치 코멘트를 수집·정리하여 최신 체인지셋에 적용 | `/cm-merge-comment [브랜치경로]` |
| `/cm-branch-info` | 브랜치 개요, 체인지셋 목록, 병합 이력 표시 | `/cm-branch-info [브랜치경로]` |
| `/cm-status` | 워크스페이스 변경 사항을 카테고리별로 정리 | `/cm-status` |
| `/cm-history` | 파일/디렉토리 변경 이력 조회 | `/cm-history <경로>` |
| `/cm-diff` | 체인지셋, 브랜치, 라벨 간 비교 | `/cm-diff cs:100 cs:200` |

**자동 트리거:** PlasticSCM 관련 대화 시 cm CLI 지식 베이스가 자동 활성화됩니다.

---

## 라이선스

MIT License
