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

| 플러그인 | 설명 | 상세 |
|----------|------|------|
| [claude-plastic-scm](plugins/claude-plastic-scm/README.md) | PlasticSCM (Unity Version Control) 워크플로우 자동화 | 체크인, 코멘트, 병합, 브랜치 조회, 상태, 이력, 비교 |

---

## 라이선스

MIT License
