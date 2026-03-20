---
name: win-file-reader
description: >
  Windows document text extraction skill. Use this skill for reading and
  extracting text from PDF, DOCX, Excel, HWP, and HWPX files on Windows.
  ALWAYS invoke this skill when Claude's built-in Read tool fails on any
  document file — this skill must take over immediately.

  Triggers on any document reading failure or request:
  파일 읽기, 문서 추출, 텍스트 추출 요청 시 반드시 이 스킬을 사용하세요.
  PDF 읽기, docx 읽기, 엑셀 읽기, hwp 읽기 작업에 항상 이 스킬을 먼저 확인하세요.
  문서작업 에러, 사무작업 실패 발생 시 즉시 이 스킬을 참조하세요.
  UnicodeEncodeError, cp949, DLL load failed, pdftoppm failed 등
  문서 관련 에러가 발생하면 반드시 이 스킬의 패턴 파일을 먼저 조회하세요.
  token limit exceeded 발생 시 청킹 전략을 이 스킬에서 확인하세요.
  워드, 한글, 문서, 닥스, 피디에프, 엑셀파일, 한글파일, 워드파일, PDF파일
  관련 작업은 모두 이 스킬의 워크플로우를 따르세요.

  English triggers: read PDF, read docx, read excel, read hwp, text extraction,
  file reading, document parsing, pdf-parse, python-docx, pdfplumber, pymupdf,
  token limit exceeded. This skill is MANDATORY when any document read fails.
---

# win-file-reader Skill

Read and extract text from PDF, DOCX, Excel, HWP, and HWPX files on Windows.
This skill is the first line of defense when Claude's built-in Read tool cannot
handle a document format. Follow the workflow below every time.

---

## 1. Overview

### Purpose

Extract plain text from the four document formats most common in Korean and
general office work: PDF, DOCX (Word), XLSX/XLS (Excel), and HWP/HWPX (Hangul
Word Processor). All extraction runs through Python scripts on Windows.

### Philosophy: Self-Reinforcing Pattern Library

Every error solved here is recorded so the same error is never investigated
twice. The skill owns four pattern reference files — one per format — that
accumulate proven solutions over time:

```
skills/win-file-reader/references/
  pdf-patterns.md
  docx-patterns.md
  excel-patterns.md
  hwp-patterns.md
```

**When an error occurs:** search the relevant patterns file first.
**When an error is fixed:** record the solution to the patterns file immediately.
The skill grows stronger with every document processed.

---

## 2. Prerequisites

Python 3.8 or later is required. Install the following libraries before use:

```bash
pip install PyMuPDF          # Primary PDF library (fitz)
pip install python-docx      # DOCX extraction
pip install openpyxl         # XLSX/XLS reading
pip install olefile          # Binary HWP parsing (pre-2010 format)
pip install python-hwpx      # HWPX (ZIP-based) parsing
pip install pdfplumber        # PDF fallback when PyMuPDF fails
```

Verify installs:

```bash
python -c "import fitz, docx, openpyxl, olefile; print('OK')"
```

---

## 3. Quick Start

For most files, run the bundled extraction script directly:

```bash
python "${CLAUDE_PLUGIN_ROOT}/skills/win-file-reader/scripts/read_file.py" "path/to/document.pdf"
```

The script auto-detects the file extension and routes to the correct extractor.
Output is UTF-8 text printed to stdout.

**Override encoding on Windows if stdout crashes:**

```bash
set PYTHONIOENCODING=utf-8
python "${CLAUDE_PLUGIN_ROOT}/skills/win-file-reader/scripts/read_file.py" "path/to/document.pdf"
```

---

## 4. Workflow — 3 Stages

### Stage 1: Format Detection → Pattern Reference

Detect the file extension, then open the corresponding patterns file before
writing any extraction code.

| Extension       | Patterns File                    |
|-----------------|----------------------------------|
| `.pdf`          | `references/pdf-patterns.md`     |
| `.docx`         | `references/docx-patterns.md`    |
| `.xlsx` / `.xls`| `references/excel-patterns.md`   |
| `.hwp` / `.hwpx`| `references/hwp-patterns.md`     |

Read the patterns file and check whether a matching snippet or error entry
already exists for your current task.

### Stage 2: Execute with Proven Snippets

- If a matching snippet exists in the patterns file → use it directly without
  modification.
- If no matching snippet → run `scripts/read_file.py` as the default approach.
- For edge cases (password-protected files, scanned PDFs, legacy formats) →
  check the patterns file for guidance before attempting a custom solution.

### Stage 3: Self-Reinforcing Loop on Error

```
Error occurs
    │
    ▼
Search patterns.md for the same error message
    │
    ├── Found ──────────────────────────────────────────► Apply documented solution
    │
    └── Not found
            │
            ▼
        Investigate and solve the error
            │
            ▼
        MUST record to patterns.md:
          - Error message (exact)
          - Root cause
          - Solution snippet (working code)
          - Date recorded
```

This loop is non-optional. Every new error solution must be written back.

---

## 5. Pattern Recording Rules

### Entry Format

````markdown
### [Pattern Name or Error Name]

- **Situation**: Describe when this occurs
- **Error**: Exact error message (copy-paste from terminal)
- **Cause**: Why it happens on Windows / with this library
- **Solution**:
  ```python
  # Proven working code
  ```
- **Recorded**: YYYY-MM-DD
````

### Rules

1. **Search before recording.** Read all existing entries in the patterns file
   before adding a new one to avoid duplicates.
2. **Update, don't duplicate.** If the same error already has an entry, update
   the existing entry with any new information. Do not create a second entry.
3. **Record both error patterns and success patterns.** An approach that works
   reliably on the first try is worth recording as a success pattern so it can
   be reused.
4. **Keep entries self-contained.** Each entry must include enough context to
   be applied without reading the rest of the file.

---

## 6. Common Windows Issues — Quick Reference

| Issue | Quick Fix |
|-------|-----------|
| `UnicodeEncodeError` on stdout | `sys.stdout.reconfigure(encoding='utf-8')` at top of script, or set `PYTHONIOENCODING=utf-8` before running |
| Path with spaces in Git Bash | Wrap the full path in double quotes: `"path/with spaces/file.pdf"` |
| `DLL load failed` for PyMuPDF | See `references/pdf-patterns.md` — usually a Visual C++ Redistributable issue |
| `pdftoppm failed` / `poppler not found` | PyMuPDF does not need poppler; switch from pdfplumber to fitz |
| Token limit exceeded on large file | Use page-range chunking — see Stage 3 example in `references/pdf-patterns.md` |
| Korean text garbled / mojibake | Force UTF-8 throughout; never let Python default to cp949 for output |
| `cp949` codec error reading file | Open files with `encoding='utf-8'` explicitly; use `errors='replace'` as fallback |
| `.hwp` returns binary garbage | Use `olefile` for binary HWP; `python-hwpx` is for `.hwpx` only |

---

## 7. Format-Specific References

Consult the relevant reference file at the start of every extraction task for
that format. Do not skip this step — patterns accumulate over time and may
already contain the exact solution needed.

| Format | Reference File | When to Consult |
|--------|---------------|-----------------|
| PDF | `references/pdf-patterns.md` | Any PDF read task; always read before writing fitz/pdfplumber code |
| DOCX | `references/docx-patterns.md` | Word document extraction; table extraction; embedded images |
| Excel | `references/excel-patterns.md` | XLSX/XLS data extraction; formula cells; merged cells; multi-sheet files |
| HWP/HWPX | `references/hwp-patterns.md` | Hangul Word Processor files; binary `.hwp` vs ZIP-based `.hwpx` distinction |

### When Format Detection Is Ambiguous

- A file named `.hwp` may actually be HWPX (check the first 4 bytes: `PK\x03\x04` means ZIP/HWPX).
- A file named `.xls` may be an older BIFF format requiring `xlrd` instead of `openpyxl`.
- When in doubt, open the file in binary mode and inspect the magic bytes before
  choosing a library.

---

## 8. Extraction Snippets by Format

### PDF — PyMuPDF (primary)

```python
import fitz  # PyMuPDF
import sys

sys.stdout.reconfigure(encoding='utf-8')

def extract_pdf(path: str, pages: range = None) -> str:
    doc = fitz.open(path)
    page_range = pages if pages else range(len(doc))
    text_parts = []
    for i in page_range:
        text_parts.append(doc[i].get_text())
    return "\n".join(text_parts)

print(extract_pdf("path/to/document.pdf"))
```

### PDF — pdfplumber (fallback)

```python
import pdfplumber
import sys

sys.stdout.reconfigure(encoding='utf-8')

with pdfplumber.open("path/to/document.pdf") as pdf:
    text = "\n".join(page.extract_text() or "" for page in pdf.pages)
print(text)
```

### DOCX — python-docx

```python
from docx import Document
import sys

sys.stdout.reconfigure(encoding='utf-8')

def extract_docx(path: str) -> str:
    doc = Document(path)
    paragraphs = [p.text for p in doc.paragraphs]
    return "\n".join(paragraphs)

print(extract_docx("path/to/document.docx"))
```

### Excel — openpyxl

```python
import openpyxl
import sys

sys.stdout.reconfigure(encoding='utf-8')

def extract_xlsx(path: str) -> str:
    wb = openpyxl.load_workbook(path, data_only=True)
    lines = []
    for sheet in wb.worksheets:
        lines.append(f"=== Sheet: {sheet.title} ===")
        for row in sheet.iter_rows(values_only=True):
            row_text = "\t".join(str(c) if c is not None else "" for c in row)
            lines.append(row_text)
    return "\n".join(lines)

print(extract_xlsx("path/to/data.xlsx"))
```

### HWP — olefile (binary .hwp)

```python
import olefile
import zlib
import sys

sys.stdout.reconfigure(encoding='utf-8')

def extract_hwp(path: str) -> str:
    with olefile.OleFileIO(path) as ole:
        streams = ole.listdir()
        text_parts = []
        for stream in streams:
            if stream[-1].startswith("Section"):
                data = ole.openstream(stream).read()
                try:
                    decompressed = zlib.decompress(data, -15)
                    text = decompressed.decode("utf-16-le", errors="replace")
                    text_parts.append(text)
                except Exception:
                    pass
        return "\n".join(text_parts)

print(extract_hwp("path/to/document.hwp"))
```

### HWPX — python-hwpx

```python
from hwpx import HWPXFile
import sys

sys.stdout.reconfigure(encoding='utf-8')

def extract_hwpx(path: str) -> str:
    doc = HWPXFile(path)
    return doc.text

print(extract_hwpx("path/to/document.hwpx"))
```

---

## 9. Token Limit Strategy for Large Files

When a document exceeds the context window, use page-range chunking:

1. Extract total page count.
2. Process in chunks of N pages (start with 20 pages per chunk).
3. Summarize or filter each chunk before passing to the model.
4. Combine chunk summaries as needed.

```python
import fitz

doc = fitz.open("path/to/large.pdf")
total = len(doc)
chunk_size = 20

for start in range(0, total, chunk_size):
    end = min(start + chunk_size, total)
    chunk_text = "".join(doc[i].get_text() for i in range(start, end))
    # Process chunk_text here
    print(f"--- Pages {start+1}-{end} ---")
    print(chunk_text)
```

---

## 10. Skill Boundary

This skill handles **reading and extracting text only.**

| Task | Skill to Use |
|------|-------------|
| Read text from PDF, DOCX, XLSX, HWP, HWPX | **win-file-reader** (this skill) |
| Create or edit an HWPX document | **hwpx** skill (sibling skill in this plugin) |
| Write or modify a DOCX file | Use python-docx directly (out of scope) |
| OCR on scanned PDFs | Not covered — use an OCR tool separately |

Do not attempt to write, modify, or create document files using this skill.

---

## 11. Security Notes

- Always use generic placeholder paths in recorded patterns (e.g.,
  `"path/to/document.pdf"`, `"Assets/Data/report.xlsx"`).
- Never record real file paths, user names, project names, or personal data in
  the patterns files.
- If a real path appears in an error message you are recording, replace it with
  a placeholder before saving.
