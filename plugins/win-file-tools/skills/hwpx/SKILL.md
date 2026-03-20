---
name: hwpx
description: "한글 문서(.hwpx 및 레거시 .hwp)를 생성, 읽기, 편집, 템플릿 치환하는 스킬. win-file-tools 플러그인의 일부. '한글 문서', '한글파일', 'hwpx', 'HWPX', '.hwp', 'HWP', '한글로 작성', '보고서', '공문', '기안문', '출입카드 신고서', '신청서 양식' 등의 키워드가 나오면 반드시 이 스킬을 사용할 것. .hwpx(ZIP+XML)는 python-hwpx로, 레거시 .hwp(OLE2 바이너리)는 olefile+zlib 바이너리 편집으로 처리한다. 사용자가 .hwp 파일을 업로드하거나 '한글파일' '한글 양식'을 언급하면 반드시 이 스킬을 트리거할 것. 일반 Word(.docx)에는 docx 스킬을 사용."
---

# 한글 문서(.hwpx / .hwp) 생성·편집 스킬

## 개요

이 스킬은 한컴오피스 한글 문서를 두 가지 포맷 모두 처리한다:

- **.hwpx** (개방형): ZIP + XML 구조. `python-hwpx` 라이브러리로 처리.
- **.hwp** (레거시 바이너리): OLE2 Compound File + zlib 압축 레코드. `olefile` + 직접 바이너리 편집으로 처리.

> **python-hwpx는 .hwp 파일을 열 수 없다.** .hwp 파일에 python-hwpx(ObjectFinder, HwpxDocument 등)를 사용하면 에러가 난다. 반드시 포맷을 먼저 판별하라.

---

## ⚠️⚠️⚠️ 최우선: 포맷 판별 (모든 작업 전 반드시 수행) ⚠️⚠️⚠️

한글 파일을 받으면 **어떤 작업이든 시작하기 전에** 포맷부터 확인한다:

```python
import olefile, zipfile

def detect_hwp_format(path):
    """한글 파일 포맷 판별. 'hwp' 또는 'hwpx' 반환."""
    if olefile.isOleFile(path):
        return "hwp"   # → 레거시 바이너리 → references/hwp5-binary.md 따름
    elif zipfile.is_zipfile(path):
        return "hwpx"  # → 개방형 → 아래 HWPX 워크플로우 따름
    else:
        raise ValueError(f"알 수 없는 포맷: {path}")
```

- **hwp** → `references/hwp5-binary.md` 레퍼런스를 읽고 olefile 바이너리 편집 진행
- **hwpx** → 아래 HWPX 워크플로우(ZIP-level 치환) 진행

> LibreOffice에는 HWP 필터가 없어 `libreoffice --convert-to` 변환이 **불가능**하다. 시도하지 마라.

---

## 레거시 .hwp 파일 편집

.hwp(OLE2 바이너리) 파일을 편집해야 하면 **반드시 `references/hwp5-binary.md`를 먼저 읽어라.**

핵심 요약:
1. `olefile`로 OLE 스트림 접근, `PrvText`로 내용 파악
2. `BodyText/Section0` zlib 디컴프레스 → 레코드 파싱
3. PARA_TEXT(태그 67) 텍스트 치환 / 빈 셀(PARA_HEADER만 있는 곳)에 PARA_TEXT 삽입
4. 레코드 재조립 → 재압축 → 원본 크기에 맞춰 zero-padding
5. `olefile.write_stream()`으로 덮어쓰기 (동일 크기만 허용)

**절대 하지 말 것:**
- python-hwpx로 .hwp 열기 시도
- LibreOffice로 .hwp → .docx 변환 시도
- HwpxDocument.new()로 .hwp 양식 재현 시도 (서식이 완전히 깨짐)

```bash
pip install olefile --break-system-packages
```

---

## 설치 (HWPX용)

```bash
pip install python-hwpx --break-system-packages
```

---

## ⚠️⚠️⚠️ 최우선 규칙: 양식(템플릿) 선택 정책 ⚠️⚠️⚠️

> **HWPX 문서를 만들 때 반드시 아래 순서를 따른다. 예외 없음.**

### 1단계: 사용자 업로드 양식이 있는가?

사용자가 `.hwpx` 양식 파일을 업로드했다면 **반드시 해당 파일을 템플릿으로 사용**한다.
- `the user's file location/` 에 `.hwpx` 파일이 있는지 확인
- 있다면 → 그 파일을 복사하여 템플릿으로 사용 (기본 양식 무시)
- 사용자가 "이 양식으로 만들어줘", "이 파일 기반으로" 등의 표현을 쓰면 100% 해당 파일 사용

### 2단계: 기본 제공 양식 사용

사용자 업로드 양식이 없으면 **반드시 기본 제공 양식**을 사용한다:
- 보고서 → `assets/report-template.hwpx`
- (향후 추가될 다른 양식들도 이 규칙 적용)

### 3단계: HwpxDocument.new()는 최후의 수단

`HwpxDocument.new()`로 빈 문서를 만드는 것은 **아주 단순한 메모·목록 수준의 문서에만** 허용한다. 보고서, 공문, 기안문 등 양식이 필요한 문서는 절대 `new()`로 만들지 않는다.

---

## ⚠️ 양식 활용 시 필수 워크플로우 (모든 경우에 적용)

어떤 양식을 쓰든(사용자 업로드든, 기본 제공이든) 아래 워크플로우를 따른다:

```
[1] 양식 파일을  로 복사
     ↓
[2] ObjectFinder로 양식 내 텍스트 전수 조사
     ↓
[3] 플레이스홀더 목록 작성 (어떤 텍스트를 뭘로 바꿀지 매핑)
     ↓
[4] ZIP-level 전체 치환 (표 내부 포함)
     ↓  (동일 플레이스홀더가 여러 번 나오면 순차 치환 사용)
[5] 네임스페이스 후처리 (fix_namespaces.py)
     ↓
[6] ObjectFinder로 치환 결과 검증
     ↓
[7] the output directory/ 로 복사 → present_files
```

### 핵심: HwpxDocument.open()은 사용하지 않는다

`python-hwpx` 버전에 따라 `HwpxDocument.open()`이 복잡한 양식 파일을 파싱하지 못할 수 있다. **ZIP-level 치환만 사용**하는 것이 안전하다.

---

## ZIP-level 치환 함수 (직접 구현)

`hwpx_replace` 모듈은 별도로 존재하지 않으므로 아래 함수를 직접 코드에 포함한다:

### 일괄 치환 (동일 텍스트를 모두 같은 값으로)

```python
import zipfile, os

def zip_replace(src_path, dst_path, replacements):
    """HWPX ZIP 내 모든 XML에서 텍스트 치환 (표 내부 포함)"""
    tmp = dst_path + ".tmp"
    with zipfile.ZipFile(src_path, "r") as zin:
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                data = zin.read(item.filename)
                if item.filename.startswith("Contents/") and item.filename.endswith(".xml"):
                    text = data.decode("utf-8")
                    for old, new in replacements.items():
                        text = text.replace(old, new)
                    data = text.encode("utf-8")
                zout.writestr(item, data)
    if os.path.exists(dst_path):
        os.remove(dst_path)
    os.rename(tmp, dst_path)
```

### 순차 치환 (동일 플레이스홀더를 순서대로 다른 값으로)

```python
def zip_replace_sequential(src_path, dst_path, old, new_list):
    """section XML에서 old를 순서대로 new_list 값으로 하나씩 치환"""
    tmp = dst_path + ".tmp"
    with zipfile.ZipFile(src_path, "r") as zin:
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                data = zin.read(item.filename)
                if "section" in item.filename and item.filename.endswith(".xml"):
                    text = data.decode("utf-8")
                    for new_val in new_list:
                        text = text.replace(old, new_val, 1)  # 1번만 치환
                    data = text.encode("utf-8")
                zout.writestr(item, data)
    if os.path.exists(dst_path):
        os.remove(dst_path)
    os.rename(tmp, dst_path)
```

---

## 양식 내 텍스트 전수 조사 방법

```python
from hwpx import ObjectFinder

finder = ObjectFinder("양식파일.hwpx")
results = finder.find_all(tag="t")
for r in results:
    if r.text and r.text.strip():
        print(repr(r.text))
```

이 결과를 보고 어떤 텍스트가 플레이스홀더인지 파악한 후, 치환 매핑을 작성한다.

---

## 기본 양식(report-template.hwpx) 활용 가이드

### 양식 구조

```
1쪽: 표지      → 기관명(30pt) + 보고서 제목(25pt) + 작성일(25pt)
2쪽: 목차      → 로마숫자(Ⅰ~Ⅴ) + 제목 + 페이지, 붙임/참고
3쪽~: 본문     → 결재란 + 제목(22pt) + 섹션 바(Ⅰ~Ⅳ) + □○―※ 계층 본문
```

### 본문 기호 체계 (공문서와 완전히 다름!)

```
1단계:  □    (HY헤드라인M 16pt, 문단 위 15)
2단계:  ○    (휴먼명조 15pt, 문단 위 10)
3단계:  ―    (휴먼명조 15pt, 문단 위 6)
4단계:  ※    (한양중고딕 13pt, 문단 위 3)
```

### 치환 가능한 플레이스홀더 목록

| 플레이스홀더 | 위치 | 치환 대상 | 치환 방법 |
|------------|------|----------|----------|
| `브라더 공기관` | 표지 1줄 | 기관명 | 일괄 치환 |
| `기본 보고서 양식` | 표지 2줄 | 보고서 제목 | 일괄 치환 |
| `2024. 5. 23.` | 표지 작성일 | 실제 작성일 | 일괄 치환 |
| `제 목` | 본문 페이지 제목 | 보고서 제목 | 일괄 치환 |
| `. 개요` 등 | 목차 항목 | 실제 목차 제목 | 일괄 치환 |
| ` 추진 배경` 등 | 섹션 바 제목 | 실제 섹션 제목 | 일괄 치환 |
| `헤드라인M 폰트 16포인트(문단 위 15)` | □ 본문 (8개) | 1단계 내용 | **순차 치환** |
| `  ○ 휴면명조 15포인트(문단위 10)` | ○ 본문 (8개) | 2단계 내용 | **순차 치환** |
| `   ― 휴면명조 15포인트(문단 위 6)` | ― 본문 (8개) | 3단계 내용 | **순차 치환** |
| `     ※ 중고딕 13포인트(문단 위 3)` | ※ 주석 (7개) | 4단계 참조 | **순차 치환** |
| `  1. 세부내용` / `  2. 세부내용` | 붙임/참고 | 첨부 목록 | 일괄 치환 |

### 기본 양식 사용 예시 (전체 코드)

```python
import shutil, subprocess

# 양식 복사
TEMPLATE = "${CLAUDE_PLUGIN_ROOT}/skills/hwpx/assets/report-template.hwpx"
WORK = "report.hwpx"
shutil.copy(TEMPLATE, WORK)

# 1. 표지 + 목차 + 섹션 바 + 제목 (일괄 치환)
zip_replace(WORK, WORK, {
    "브라더 공기관": "실제 기관명",
    "기본 보고서 양식": "실제 보고서 제목",
    "2024. 5. 23.": "2026. 2. 13.",
    "제 목": "실제 보고서 제목",
    ". 개요": ". 실제 목차1",
    ". 추진배경": ". 실제 목차2",
    # ... 나머지 목차, 섹션 바 치환
})

# 2. □ 항목 (순차 치환 — 8개)
zip_replace_sequential(WORK, WORK,
    "헤드라인M 폰트 16포인트(문단 위 15)",
    ["첫번째 □ 내용", "두번째 □ 내용", ...]
)

# 3. ○, ―, ※ 항목도 각각 순차 치환
# ...

# 4. 네임스페이스 후처리 (필수!)
subprocess.run(
    ["python", "${CLAUDE_PLUGIN_ROOT}/skills/hwpx/scripts/fix_namespaces.py", WORK],
    check=True
)

# 5. 결과 검증
from hwpx import ObjectFinder
finder = ObjectFinder(WORK)
for r in finder.find_all(tag="t"):
    if r.text and r.text.strip():
        print(r.text)
```

---

## 사용자 업로드 양식 활용 가이드

사용자가 자신만의 `.hwpx` 양식을 업로드한 경우:

```python
import shutil, subprocess

# 1. 사용자 양식을 작업 디렉토리로 복사
USER_TEMPLATE = "the user's file location/사용자양식.hwpx"
WORK = "report.hwpx"
shutil.copy(USER_TEMPLATE, WORK)

# 2. 양식 내 텍스트 전수 조사 (★ 필수 단계!)
from hwpx import ObjectFinder
finder = ObjectFinder(WORK)
for r in finder.find_all(tag="t"):
    if r.text and r.text.strip():
        print(repr(r.text))

# 3. 조사 결과를 바탕으로 치환 매핑 작성
#    (양식마다 플레이스홀더가 다르므로 반드시 조사 후 진행)

# 4. ZIP-level 치환 적용
zip_replace(WORK, WORK, {
    "양식의 기존 텍스트": "실제 내용",
    # ...
})

# 동일 플레이스홀더가 여러 번 → 순차 치환
zip_replace_sequential(WORK, WORK, "반복되는 텍스트", ["값1", "값2", ...])

# 5. 네임스페이스 후처리
subprocess.run(
    ["python", "${CLAUDE_PLUGIN_ROOT}/skills/hwpx/scripts/fix_namespaces.py", WORK],
    check=True
)

# 6. 치환 결과 검증
finder = ObjectFinder(WORK)
for r in finder.find_all(tag="t"):
    if r.text and r.text.strip():
        print(r.text)
```

---

## 문서 유형별 스타일 가이드

### 보고서(내부 보고용) 작성 시

→ **`references/report-style.md`** 를 먼저 읽고 따를 것

### 공문서(기안문) 작성 시

→ **`references/official-doc-style.md`** 를 먼저 읽고 따를 것

### 저수준 XML 조작이 필요한 경우

→ **`references/xml-internals.md`** 를 읽을 것

---

## ⚠️ 필수 후처리: 네임스페이스 수정

> **가장 중요한 단계. 빠뜨리면 한글 Viewer에서 빈 페이지로 표시된다.**

ZIP-level 치환 후 또는 `doc.save()` 후 반드시 실행:

```python
subprocess.run(
    ["python", "${CLAUDE_PLUGIN_ROOT}/skills/hwpx/scripts/fix_namespaces.py", "output.hwpx"],
    check=True
)
```

> 주의: `exec(open(...).read())` 방식은 스크립트의 `if __name__ == "__main__"` 블록 때문에 오동작할 수 있다. 반드시 `subprocess.run()` 방식을 사용한다.

---

## Quick Reference

| 작업 | 포맷 | 접근 방식 |
|------|------|----------|
| **.hwp 양식 텍스트 채우기** | .hwp | **olefile 바이너리 편집** → `references/hwp5-binary.md` |
| 보고서/공문/양식 문서 생성 | .hwpx | **양식 파일 + ZIP-level 치환** (★ 권장) |
| 아주 단순한 문서 | .hwpx | `HwpxDocument.new()` → `.save()` → 후처리 |
| 표(테이블) 추가 | .hwpx | `doc.add_table(rows, cols)` → `set_cell_text()` |
| 머리글/바닥글 | .hwpx | `doc.set_header_text()` / `doc.set_footer_text()` |
| 텍스트 검색/추출 | .hwpx | `ObjectFinder(filepath)` |
| 셀 병합 | .hwpx | `table.merge_cells(row1, col1, row2, col2)` |

---

## 주의사항

1. **포맷 판별 최우선**: 어떤 작업이든 시작 전에 `olefile.isOleFile()` / `zipfile.is_zipfile()`로 포맷 확인
2. **python-hwpx는 .hwp 불가**: ObjectFinder, HwpxDocument 모두 .hwp에서 에러남. 절대 시도하지 마라
3. **LibreOffice HWP 변환 불가**: Ubuntu LibreOffice에 HWP 필터 없음. `--convert-to` 시도 금지
4. **.hwp 양식 보존**: .hwp 양식의 레이아웃을 재현하려고 HwpxDocument.new()로 새로 만들지 마라 — 서식이 완전히 깨진다. 반드시 원본 .hwp를 바이너리 편집하라
5. **양식 우선** (.hwpx): 사용자 업로드 양식 > 기본 제공 양식 > HwpxDocument.new()
6. **ZIP-level 치환 우선** (.hwpx): HwpxDocument.open()보다 ZIP-level 치환이 안전하고 호환성이 높다
7. **네임스페이스 후처리 필수** (.hwpx): 모든 저장/치환 후 `fix_namespaces.py` 실행
8. **양식 텍스트 조사 필수** (.hwpx): 치환 전에 반드시 ObjectFinder로 텍스트 전수 조사
9. **순차 치환 주의** (.hwpx): 동일 플레이스홀더가 여러 번 나오면 `zip_replace_sequential` 사용
10. **공문서 날짜 형식**: `2026-02-13`이 아닌 `2026. 2. 13.` (월·일 앞 0 생략)
11. **fix_namespaces 호출법** (.hwpx): `exec()` 말고 `subprocess.run()` 사용