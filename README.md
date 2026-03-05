# claude-plastic-scm

PlasticSCM (Unity Version Control) 워크플로우 자동화를 위한 Claude Code 플러그인입니다.

## 요구사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- PlasticSCM CLI (`cm`) — [Unity Hub](https://unity.com/unity-hub) 또는 [plasticscm.com](https://www.plasticscm.com/) 에서 설치

## 설치

```bash
claude plugin install github:AccelixGames/claude-plastic-scm
```

## 업데이트

```bash
claude plugin update claude-plastic-scm
```

## 제거

```bash
claude plugin uninstall claude-plastic-scm
```

## 사용 가능한 명령

| 명령 | 설명 | 사용법 |
|------|------|--------|
| `/cm-checkin` | 변경 분석 후 코멘트 자동 생성 → 체크인 | `/cm-checkin` |
| `/cm-merge-comment` | 병합된 서브 브랜치 코멘트를 수집·정리하여 최신 체인지셋에 적용 | `/cm-merge-comment [브랜치경로]` |
| `/cm-branch-info` | 브랜치 개요, 체인지셋 목록, 병합 이력 표시 | `/cm-branch-info [브랜치경로]` |
| `/cm-status` | 워크스페이스 변경 사항을 카테고리별로 정리 | `/cm-status` |
| `/cm-history` | 파일/디렉토리 변경 이력 조회 | `/cm-history <경로>` |
| `/cm-diff` | 체인지셋, 브랜치, 라벨 간 비교 | `/cm-diff cs:100 cs:200` |

### 예시

```bash
# 현재 브랜치의 병합 코멘트 정리
/cm-merge-comment

# 특정 브랜치 지정
/cm-merge-comment /main/MacBuilder

# 워크스페이스 상태 확인
/cm-status

# 브랜치 정보 조회
/cm-branch-info /main/Alpha2

# 파일 이력 확인
/cm-history Assets/Scripts/Player.cs

# 체인지셋 비교
/cm-diff cs:2718 cs:2721
```

## 자동 트리거 (Skill)

PlasticSCM 관련 대화를 하면 자동으로 cm CLI 지식 베이스가 활성화됩니다.
별도로 명령을 입력하지 않아도 `cm` 명령 문법, 쿼리 작성, 트러블슈팅 등을 지원합니다.

**트리거 키워드:** 플라스틱, 체인지셋, cm 명령, 병합, 브랜치, 체크인, 워크스페이스 등

## 라이선스

MIT License — [LICENSE](LICENSE) 참고
