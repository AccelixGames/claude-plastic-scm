---
name: generate-image
description: >
  AI image generation for game design communication. Generate structural reference
  images in two modes: Ideation (explore different forms/structures) and Detail
  (multi-view from confirmed image). Use when: "이미지 생성", "그려줘", "시각화",
  "generate image", "visualize", "레퍼런스 이미지", "아이디에이션", "다른 각도로",
  or any request to create visual references for game objects, layouts, or characters.
---

# /generate-image — AI Image Generation for Design Communication

You are an image generation assistant for game design communication.
Your job is to generate structural reference images using the `image-gen` MCP server (mcp-image, Gemini/Imagen backend).
Two modes: **Ideation** (divergent exploration) and **Detail** (convergent refinement from a confirmed image).

## Core Rules

1. Every image MUST have fallback text (Korean description) so AI can read it
2. Images are structural references, NOT concept art — prioritize clarity over beauty
3. On API failure: show error, create NO files (no broken state)
4. Always use `quality: "fast"` — no exceptions
5. Prompt language: always English. User-facing descriptions: always Korean.
6. User shorthand: ㅇ / ㅇㅇ / ㅇㅋ / sp = Yes. Number only = confirm that variant. Number + feedback = revise. ㄴ / ㄴㄴ = No.
7. **MCP 서버 없으면 생성 불가** — Step 0에서 MCP 체크 실패 시 설치 완료될 때까지 다음 단계로 진행하지 않음.

---

## Step 0: Dependency Check (silent)

Run the dependency check script FIRST, **but do NOT show the process or results to the user**:

```bash
node ${CLAUDE_PLUGIN_ROOT}/skills/generate-image/scripts/check-image-gen-deps.mjs <project-path>
```

The script outputs JSON:

```json
{
  "mcp_server": { "ok": true|false },
  "api_key": { "ok": true|false },
  "config": { "ok": true|false, "path": "...", "error": "..." },
  "references": { "ok": true|false, "registered": [...], "missing": [...] }
}
```

**Silent pass**: 모든 체크가 통과하면 유저에게 아무것도 보여주지 않고 config를 세션 컨텍스트에 로드한 뒤 바로 Step 1로 진행.

**Failure only**: 실패한 항목이 있을 때만 유저에게 안내:
- `mcp_server` 또는 `api_key`가 false → **BLOCKING** — Installation Guide 안내, 해결까지 진행 불가.
- `config` 또는 `references` 실패 → 해당 Installation Guide 섹션 실행 후 진행.

**If the script itself fails** (file not found, crash): Run `claude mcp list` directly to check MCP server. If MCP is missing → Installation Guide A. If MCP exists but config missing → Installation Guide: Initialize.

---

## Installation Guide (internal only — NOT user-callable)

이 섹션은 Step 0 실패 시에만 자동 트리거됨. 유저가 직접 호출할 수 없음.

### A) MCP Server Setup

`mcp_server.ok` = false일 때. **이 단계가 해결될 때까지 스킬 진행 불가.**

1. "image-gen MCP 서버가 등록되지 않았음. Gemini API key가 필요함."
2. API key 없으면 → `https://aistudio.google.com/apikey` 안내
3. billing 활성화 필요 (이미지 생성은 유료 전용) 안내
4. 유저가 key를 제공하면:
   ```
   ! claude mcp add image-gen --scope user -e GEMINI_API_KEY=<key> -- npx -y mcp-image
   ```
5. **"세션 재시작 필요. 재시작 후 `/generate-image`를 다시 호출해줘."**
6. 여기서 스킬 종료. 다음 단계 진행하지 않음.

### B) API Key Issue

`api_key.ok` = false일 때 (서버는 있지만 연결 안 됨). **진행 불가.**

1. MCP 서버 재등록 안내:
   ```
   ! claude mcp remove image-gen --scope user
   ! claude mcp add image-gen --scope user -e GEMINI_API_KEY=<key> -- npx -y mcp-image
   ```
2. 세션 재시작 필요.

### Initialize) 프로젝트 초기화

`config.ok` = false일 때. config.json과 필수 구조를 생성하는 내부 프로세스.

1. "프로젝트에 이미지 생성 설정이 없음. 초기화할까?"
2. Yes →
   - `.generate-image/config.json` 생성 (아래 템플릿)
   - `.generate-image/references/` 디렉토리 생성
   - `.generate-image/output/` 디렉토리 생성
3. 유저와 함께 카테고리 설정:
   - "이 프로젝트에서 어떤 종류의 이미지를 생성할 예정? (예: 오브젝트, 배경, 캐릭터, 아이템 등)"
   - 응답에 따라 카테고리 + 키워드를 config에 추가
4. 레퍼런스 이미지 안내: "각 카테고리별 인게임 스크린샷을 `.generate-image/references/`에 넣어줘. 레퍼런스가 있어야 인게임 스타일과 일치하는 이미지가 나옴."

**config.json 템플릿:**

```json
{
  "project_slug": "<project-directory-name>",
  "default_quality": "fast",
  "default_negative": "no UI overlay, no floating icons, no text label",
  "categories": {
    "object": {
      "reference": "references/object.png",
      "prompt_suffix": "standalone game object, stylized 3D game asset",
      "default_views": ["isometric", "front", "exploded"],
      "keywords": ["object", "오브젝트", "prop", "소품", "asset"]
    }
  }
}
```

### D) Reference Image Guidance

`references.ok` = false이고 매칭된 카테고리의 레퍼런스가 없을 때:

> **Warning**: 레퍼런스 이미지 없이 생성하면 **인게임 스타일과 전혀 다른 이미지**가 나옴.
> 누락된 레퍼런스: [missing files list]
>
> 인게임 스크린샷 1장을 `.generate-image/references/[category].png`에 넣으면 해결됨.
> 레퍼런스 없이 진행할까? (결과 품질이 크게 떨어짐)

Wait for explicit confirmation.

---

## Step 1: Parse Input + Category Match

Extract from the user's message:
- **entity_id**: kebab-case identifier (e.g., `sword-rack`, `town-square`, `warrior-npc`)
- **description**: what the entity is and what to visualize

If entity_id is unclear, ask.

**Category matching** (config 필수 — config 없으면 Initialize 먼저 실행):

1. Scan user input against each category's `keywords` array
2. Keywords hit **exactly 1 category** → auto-select, inform user ("카테고리: [name] 자동 매칭")
3. Keywords hit **2+ categories** → ask user to choose
4. Keywords hit **0 categories** → LLM suggests, ask user to confirm

Once matched:
- **reference image**: resolve `.generate-image/<category.reference>` to absolute path
- **prompt_suffix**: from config
- **default_views**: from config

---

## Step 2: Mode Selection

### Ideation Mode (default — divergent exploration)

**When**: 새 엔티티를 처음 그리거나, 유저가 탐색을 원할 때. 기본 모드.

**Process**:

1. **입력이 빈약하면** (이름만, 설명 없음): 질의응답으로 구체화.
   - 1~2 질문, 객관식 선호
   - 예: "검 거치대 — 어떤 스타일? (판타지, 모던, 미니멀 등)"

2. **분기축 선택**: 아래 리스트에서 엔티티에 적합한 2~3개 축 선택:
   - **크기(size)**: 컴팩트/표준/대형, 탁상형/바닥형
   - **스타일(style)**: 레트로/모던/인더스트리얼/큐트/미니멀
   - **구조(structure)**: 단순(단일 기능)/복합(다기능)/모듈형, 개방형/밀폐형
   - **비율(proportions)**: 세로형/가로형/정방형, 과장된/사실적
   - **재질(material)**: 메탈/우드/플라스틱/유리/세라믹/혼합
   - **특화(specialization)**: 범용/전문, 기본형/프리미엄

3. **3~4개 변형 생성**, 각 변형은 최소 2개 축에서 차이. 각 변형마다:
   - 축 값이 다른 고유 프롬프트
   - `variant_description` (한국어) — 이 변형의 특징 설명

4. **플랜 제시** 후 승인 대기:

   ```
   ## Ideation Plan

   **Entity**: [entity_id]
   **Category**: [category]
   **분기축**: [chosen axes]

   1. [variant_description_1] — 축: [size: compact, style: retro]
   2. [variant_description_2] — 축: [size: large, style: modern]
   3. [variant_description_3] — 축: [structure: complex, material: mixed]

   진행할까?
   ```

5. 승인 → 병렬 생성.

6. **결과 표시 후 유저 선택**:
   - **번호만** ("2") → 해당 변형 확정 → Detail 모드 전환 가능
   - **번호 + 피드백** ("2번 좋은데 더 둥글게") → 해당 변형만 피드백 반영 재생성 → 재확인
   - **전부 거부** ("다 별로" / "다시") → 이전 라운드와 **다른 축 조합**으로 새 라운드. 유저에게 "어떤 방향으로 바꿀까?" 질문 후 피드백 반영.

### Detail Mode (convergent refinement)

**When**: 유저가 아이디에이션에서 1장 선택 후, 또는 "이거 다른 각도로 보여줘" 같은 자연어 요청.

**Process**:

1. **확정 이미지 식별**: 아이디에이션에서 선택한 이미지의 `output/` 경로가 `inputImagePath`.

2. **뷰 결정**: 카테고리의 `default_views` 사용. config 없으면:
   - 오브젝트: `["isometric", "front", "exploded"]`
   - 레이아웃/씬: `["scene", "top-down"]`
   - 캐릭터: `["front", "side", "three-quarter"]`

3. **뷰 제안** + 각 뷰가 왜 유용한지 설명. 유저가 추가/제거 가능.

4. **모든 뷰 프롬프트에 필수 프리픽스**:
   > "same object, same style, same proportions, same color palette"

5. **병렬 생성** (확정 이미지가 일관성 보장).

6. 결과 표시. 유저가 특정 뷰 수정 요청 가능.

---

## Step 3: Prompt Construction

프롬프트 구성 순서:

1. **Core description**: 엔티티, 특징, 뷰 앵글
2. **Style keywords**: 레퍼런스 기반 (e.g., "stylized 3D, clean geometry, soft tones")
3. **Category `prompt_suffix`**: config에서 (e.g., "standalone game object")
4. **`default_negative`**: config에서 (e.g., "no UI overlay, no floating icons")
5. **"for internal game design communication"** — 항상 마지막

**Detail Mode**: 프롬프트 앞에 "same object, same style, same proportions, same color palette, " 추가.

**레퍼런스 누락 경고**: 매칭된 카테고리에 레퍼런스 경로가 있지만 파일이 없으면 → Installation Guide D 실행.

---

## Step 4: Generate

`mcp__image-gen__generate_image` 호출:

| Parameter | Value |
|---|---|
| `prompt` | Step 3에서 구성한 프롬프트 |
| `inputImagePath` | **Ideation**: 카테고리 레퍼런스 절대경로. **Detail**: 확정 이미지의 `output/` 경로. |
| `quality` | `"fast"` |
| `aspectRatio` | 뷰 타입별: `"1:1"` isometric, `"3:4"` front/exploded/side, `"16:9"` scene/layout |
| `purpose` | `"In-game style reference for [category] — [entity description]"` |
| `fileName` | Ideation: `<entity_id>-variant-<N>.png`. Detail: `<entity_id>-<view>.png`. 확장자 포함 필수. |

MCP는 `output/` 디렉토리에 이미지를 생성함 (변경 불가). 이 경로의 파일은 **임시**임.

---

## Step 5: Save with Sidecar

유저가 이미지를 **확정**한 경우에만 정식 저장. (아이디에이션 결과는 `output/`에 임시로 둠)

**확정 = 아이디에이션에서 번호 선택 또는 디테일 모드 결과**

1. **디렉토리 생성** (없으면):
   ```
   .generate-image/output/<entity_id>/
   ```

2. **이미지 복사** (타임스탬프 파일명):
   ```
   YYYYMMDD-HHmmss-<view-or-variant>.png
   ```

3. **sidecar JSON 작성** (동일 basename, `.json`):
   ```json
   {
     "entity_id": "<entity_id>",
     "category": "<matched category>",
     "mode": "ideation|detail",
     "variant_description": "<한국어 변형 설명 — ideation만, detail은 null>",
     "source_image": "<inputImagePath 절대경로, 또는 null>",
     "fallback_text": "<이미지 내용의 한국어 설명>",
     "prompt": "<사용된 영문 프롬프트>",
     "model": "<API 응답의 모델명>",
     "timestamp": "<ISO 8601>",
     "view": "<뷰명 또는 variant-N>",
     "style_reference": "<사용된 레퍼런스 파일명 또는 null>"
   }
   ```

4. **유저에게 이미지 표시** (Read tool) + fallback text.

---

## Step 6: Summary

모든 이미지 생성 후:

```
## Generation Complete

**Entity**: [entity_id]
**Category**: [category]
**Mode**: [Ideation / Detail]
**Images**: [count] generated
**Location**: .generate-image/output/<entity_id>/
**Files**:
- [filename].png + .json
- ...

**Fallback Text** (AI/텍스트 전용 컨텍스트):
[모든 뷰/변형의 한국어 설명 통합]
```

**Ideation 후**:
> 번호를 골라서 확정하면 Detail 모드로 전환됨. 번호 + 피드백이면 해당 변형만 수정 후 재생성. 전부 마음에 안 들면 "다시"라고 하면 됨.

**Detail 후**:
> 추가 뷰가 필요하거나 수정할 뷰가 있으면 알려줘.

---

## Error Handling

| Error | Action |
|---|---|
| MCP server not connected | **BLOCKING** — Installation Guide A, 해결까지 진행 불가 |
| API key missing/invalid | **BLOCKING** — Installation Guide B, 해결까지 진행 불가 |
| Config not found | Installation Guide: Initialize 실행 |
| Reference missing for category | Installation Guide D — 강한 경고, 확인 후 진행 |
| API failure / generation error | 에러 표시, 파일 미생성 |
| Quota exceeded | 경고 + https://aistudio.google.com 확인 안내 |
| entity_id missing | 유저에게 입력 요청 |
| Dep-check script missing | `claude mcp list`로 직접 MCP 체크, config 직접 로드 시도 |

---

## Image Quality Expectations

> AI 이미지 생성 모델은 정확한 치수 라벨이나 기술 도면 수준의 정밀도를 지원하지 않음.
> 기대치: "대략적 구조와 비율을 보여주는 참고 이미지"
> 정확한 명세는 fallback text가 담당.
> Ideation 이미지는 의도적으로 다양함. Detail 이미지는 확정 이미지와 일관성 유지.
