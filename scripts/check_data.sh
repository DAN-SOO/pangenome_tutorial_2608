#!/usr/bin/env bash
# 실습 데이터·툴이 올바르게 배치됐는지 검증한다.
# 사용법: 저장소 루트에서  bash scripts/check_data.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${SCRIPT_DIR}/.." && pwd)"
# 데이터가 놓인 곳(ROOT)은 저장소와 다를 수 있다(KOGO_ROOT로 지정 가능).
ROOT="${KOGO_ROOT:-$REPO}"
SUMS="${REPO}/docs/DATA_MANIFEST.sha256"   # 절대경로 — cd 이후에도 유효

if [[ ! -f "$SUMS" ]]; then
    echo "ERROR: 체크섬 파일 없음 → $SUMS" >&2; exit 1
fi

# sha256 도구 선택 (Linux: sha256sum / macOS: shasum -a 256)
if command -v sha256sum >/dev/null 2>&1; then
    SHACMD=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
    SHACMD=(shasum -a 256)
else
    echo "ERROR: sha256sum 또는 shasum 이 필요합니다" >&2; exit 1
fi

cd "$ROOT" || exit 1
echo "[INFO] ROOT=$ROOT"

missing=0; bad=0; ok=0
while read -r want path; do
    [[ -z "${path:-}" ]] && continue
    if [[ ! -f "$path" ]]; then
        printf '없음    %s\n' "$path"; missing=$((missing+1)); continue
    fi
    got=$("${SHACMD[@]}" "$path" | awk '{print $1}')
    if [[ "$got" == "$want" ]]; then
        ok=$((ok+1))
    else
        printf '불일치  %s\n' "$path"; bad=$((bad+1))
    fi
done < "$SUMS"

echo
echo "일치 $ok / 없음 $missing / 불일치 $bad"
if (( ok + missing + bad == 0 )); then
    echo "ERROR: 검사한 항목이 0개입니다 — 체크섬 목록이 비었거나 읽지 못했습니다:" >&2
    echo "       $SUMS" >&2
    exit 1
fi
if (( missing == 0 && bad == 0 )); then
    echo "[OK] 데이터·툴 배치 완료 — bash scripts/run_all_kogo_day2.sh all 로 실행하세요."
    exit 0
fi
if (( missing > 0 )); then
    echo "[안내] 없는 파일은 docs/DATA_MANIFEST.md 의 경로 구조대로 배치하세요." >&2
    echo "       실습1만 돌린다면 tools/ 와 srWGS FASTQ 는 없어도 됩니다." >&2
fi
(( bad > 0 )) && echo "[경고] 불일치 파일은 전송이 손상됐을 수 있습니다 — 다시 받으세요." >&2
exit 1
