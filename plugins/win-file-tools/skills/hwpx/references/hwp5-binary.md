# 레거시 HWP5 (.hwp) 바이너리 편집 가이드

## 개요

`.hwp`는 한글 워드프로세서의 레거시 바이너리 포맷이다. OLE2 Compound File 안에 zlib 압축된 레코드 스트림이 들어 있다. `.hwpx`(ZIP+XML)와 완전히 다른 포맷이므로 python-hwpx로는 처리 불가.

이 가이드는 원본 .hwp 양식의 레이아웃(표, 서식, 이미지)을 100% 보존하면서 텍스트만 치환/삽입하는 방법을 다룬다.

## 포맷 판별 (가장 먼저 수행)

```python
import olefile
if olefile.isOleFile(path):
    # → 레거시 .hwp → 이 가이드 따름
else:
    import zipfile
    if zipfile.is_zipfile(path):
        # → .hwpx → python-hwpx ZIP-level 치환 사용
```

## 설치

```bash
pip install olefile --break-system-packages
pip install pyhwp --break-system-packages  # 선택: HTML 변환 등
```

## OLE 스트림 구조

| 스트림 | 설명 |
|--------|------|
| FileHeader | 압축 여부 플래그 등 |
| BodyText/Section0 | 본문 (zlib 압축 레코드) ← **편집 대상** |
| PrvText | 미리보기 텍스트 (UTF-16LE) |
| BinData/ | 이미지 등 바이너리 |

## 핵심 워크플로우

```
[1] PrvText로 내용 빠르게 파악
[2] FileHeader 압축 플래그 확인 → BodyText/Section0 디컴프레스
[3] 레코드 파싱 → PARA_TEXT 텍스트 전수 덤프
[4] 빈 셀 위치 파악 (PARA_HEADER만 있고 PARA_TEXT 없는 곳)
[5] 텍스트 치환 + 빈 셀 삽입
[6] 레코드 재조립 → 재압축 → 원본 크기 패딩
[7] olefile write_mode로 스트림 덮어쓰기
```

## 압축

```python
# 디컴프레스 (raw deflate)
data = zlib.decompress(raw, -15)

# 재압축 → zlib 헤더/체크섬 제거
compressed = zlib.compress(new_data, 9)[2:-4]
```

## 레코드 구조

4바이트 헤더: `[31:20] size | [19:10] level | [9:0] tag_id`
size=0xFFF이면 다음 4바이트가 실제 크기.

주요 태그: 66=PARA_HEADER, 67=PARA_TEXT, 68=PARA_CHAR_SHAPE, 69=PARA_LINE_SEG

PARA_TEXT에서 **코드 24~31은 인라인 확장 제어 → 추가 14바이트 스킵** 필수.

## 빈 셀 패턴

빈 셀: `PARA_HEADER(nchars=0x80000001)` → PARA_TEXT 없음 → PARA_CHAR_SHAPE
텍스트 셀: `PARA_HEADER(nchars=N)` → PARA_TEXT(UTF-16LE) → PARA_CHAR_SHAPE

빈 셀에 텍스트 삽입: PARA_HEADER의 nchars 업데이트 + PARA_TEXT 레코드 신규 삽입.
nchars 최상위 비트(0x80000000)는 "리스트 마지막" 플래그 → 반드시 보존.

## olefile write_stream 제약

`write_stream()`은 **동일 크기**만 허용. 작으면 `\x00` 패딩, 크면 압축 레벨 하향.

## 전체 코드

`references/hwp5-binary.md` 하단의 `hwp_fill_form()` 함수 참조. 이 함수에 `empty_cells` (빈 셀 PARA_HEADER offset → 텍스트)과 `text_replacements` (기존 PARA_TEXT offset → (기존, 새))를 전달하면 양식 레이아웃을 보존하면서 텍스트를 채울 수 있다.

## 주의사항

1. python-hwpx는 .hwp 불가 (ObjectFinder, HwpxDocument 모두 에러)
2. Ubuntu LibreOffice에 HWP 필터 없어 변환 불가
3. 레코드 재조립 시 원본 순서 유지 필수
4. PARA_TEXT 제어문자 24~31 → 14바이트 추가 데이터 스킵
5. nchars 최상위 비트 0x80000000 플래그 보존 필수
