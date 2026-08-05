#!/usr/bin/env bash
# =============================================================================
#  KOGO Day2 판지놈 실습 — SLURM 제출 스크립트
#
#  사용법:
#    bash scripts/submit_slurm.sh [PHASE]        # PHASE: all(기본) | 1 | 2 | 3
#
#  예:
#    bash scripts/submit_slurm.sh          # 실습1~3 전체
#    bash scripts/submit_slurm.sh 1        # 실습1만 (가벼움)
#    bash scripts/submit_slurm.sh 3        # 실습3만 (DeepVariant)
#
#  이 스크립트는 계정별로 고쳐 쓸 필요가 없습니다 — 실행하는 사람의 $USER 기준으로
#  출력·로그 경로가 정해지고, 아래 값들은 환경변수로 덮어쓸 수 있습니다.
#
#    KOGO_DATA        공유 데이터 위치 (필수 — 없으면 자동 탐색 후 실패 시 안내)
#    KOGO_ENV         conda 환경 (경로 | 이름 | skip)
#    KOGO_OUT         산출물 폴더        기본: ./kogo_run (실행한 위치 기준)
#    SLURM_PARTITION  파티션            기본: cpu
#    SLURM_ACCOUNT    계정              기본: (미설정 — 서버가 요구하면 지정)
#    SLURM_CPUS       코어 수           기본: PHASE 별 자동
#    SLURM_MEM        메모리            기본: PHASE 별 자동
#    SLURM_TIME       제한시간          기본: PHASE 별 자동
#    CONDA_SH         conda 초기화 스크립트 경로 (자동 탐색 실패 시 지정)
#
#  예) 다른 파티션·계정으로:
#    SLURM_PARTITION=long SLURM_ACCOUNT=mylab bash scripts/submit_slurm.sh all
# =============================================================================
set -euo pipefail

PHASE="${1:-all}"
case "$PHASE" in
  all|1|2|3) ;;
  *) echo "ERROR: PHASE 는 all | 1 | 2 | 3 중 하나여야 합니다 (받은 값: $PHASE)" >&2; exit 1 ;;
esac

# --- 코드 위치 (이 스크립트가 있는 폴더) ------------------------------------
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MASTER="${CODE_DIR}/run_all_kogo_day2.sh"
[[ -s "$MASTER" ]] || { echo "ERROR: 마스터 스크립트가 없습니다 → $MASTER" >&2; exit 1; }

# --- 산출물 폴더: 실행한 사람의 현재 위치 기준 -------------------------------
WORK="${KOGO_OUT:-${PWD}/kogo_run}"
mkdir -p "$WORK" 2>/dev/null || {
    echo "ERROR: 산출물 폴더를 만들 수 없습니다 → $WORK" >&2
    echo "       쓰기 가능한 폴더로 이동해 다시 실행하거나 KOGO_OUT 을 지정하세요." >&2
    exit 1
}
WORK="$(cd "$WORK" && pwd -P)"

# --- 자원 기본값: PHASE 별 ---------------------------------------------------
#  실습1: bcftools/panacus (가벼움)  실습2: KMC+giraffe (메모리)  실습3: DeepVariant (오래)
case "$PHASE" in
  1)   DEF_CPUS=4;  DEF_MEM=16G; DEF_TIME=01:00:00 ;;
  2)   DEF_CPUS=8;  DEF_MEM=72G; DEF_TIME=03:00:00 ;;   # KMC -m64 → 64G 이상 필요
  3)   DEF_CPUS=8;  DEF_MEM=32G; DEF_TIME=04:00:00 ;;
  all) DEF_CPUS=12; DEF_MEM=72G; DEF_TIME=08:00:00 ;;
esac
CPUS="${SLURM_CPUS:-$DEF_CPUS}"
MEM="${SLURM_MEM:-$DEF_MEM}"
TIMELIMIT="${SLURM_TIME:-$DEF_TIME}"
PARTITION="${SLURM_PARTITION:-cpu}"
ACCOUNT="${SLURM_ACCOUNT:-}"

# --- conda 초기화 스크립트 자동 탐색 ----------------------------------------
#  계산 노드에서 conda 를 PATH 에 올리기 위한 것. 환경 activate 는 마스터가 처리.
find_conda_sh() {
    local c
    if [[ -n "${CONDA_SH:-}" ]]; then echo "$CONDA_SH"; return; fi
    # 이미 conda 를 쓰고 있으면 그 설치본
    if [[ -n "${CONDA_EXE:-}" && -s "$(dirname "$(dirname "$CONDA_EXE")")/etc/profile.d/conda.sh" ]]; then
        echo "$(dirname "$(dirname "$CONDA_EXE")")/etc/profile.d/conda.sh"; return
    fi
    if c=$(command -v conda 2>/dev/null); then
        c="$(dirname "$(dirname "$c")")/etc/profile.d/conda.sh"
        [[ -s "$c" ]] && { echo "$c"; return; }
    fi
    for c in "$HOME/miniforge3" "$HOME/miniconda3" "$HOME/anaconda3" \
             /data1/software/anaconda3 /opt/conda /usr/local/anaconda3; do
        [[ -s "$c/etc/profile.d/conda.sh" ]] && { echo "$c/etc/profile.d/conda.sh"; return; }
    done
    echo ""
}
CONDA_SH_PATH="$(find_conda_sh)"
if [[ -z "$CONDA_SH_PATH" ]]; then
    echo "[WARN] conda 초기화 스크립트를 찾지 못했습니다." >&2
    echo "       계산 노드에서 conda 를 못 쓰면 실패합니다. 경로를 지정해 주세요:" >&2
    echo "         CONDA_SH=/설치경로/etc/profile.d/conda.sh bash $0 $PHASE" >&2
fi

# --- 배치 스크립트 생성 (산출물 폴더 안에) ----------------------------------
JOBNAME="kogo${PHASE}_${USER}"
SB="${WORK}/.submit_kogo_${PHASE}.sbatch"
LOG="${WORK}/kogo_day2.${PHASE}.%j.log"

{
  echo "#!/bin/bash"
  echo "#SBATCH --job-name=${JOBNAME}"
  echo "#SBATCH --partition=${PARTITION}"
  [[ -n "$ACCOUNT" ]] && echo "#SBATCH --account=${ACCOUNT}"
  echo "#SBATCH --cpus-per-task=${CPUS}"
  echo "#SBATCH --mem=${MEM}"
  echo "#SBATCH --time=${TIMELIMIT}"
  echo "#SBATCH --output=${LOG}"
  echo ""
  echo "set -uo pipefail"
  echo ""
  echo "echo \"[JOB] \$SLURM_JOB_ID on \$(hostname)  user=\$USER  cpus=\${SLURM_CPUS_PER_TASK:-?}\""
  echo ""
  [[ -n "$CONDA_SH_PATH" ]] && echo "source '${CONDA_SH_PATH}'   # conda 를 PATH 에 올림 (activate 는 마스터가 처리)"
  echo ""
  # 공용 conda 의 패키지 캐시에 쓰기 권한이 없을 때를 대비해 개인 캐시로
  echo "export CONDA_PKGS_DIRS=\"\${CONDA_PKGS_DIRS:-\$HOME/.conda/pkgs}\""
  echo "mkdir -p \"\$CONDA_PKGS_DIRS\" 2>/dev/null || true"
  echo ""
  # 호출한 셸의 KOGO_* 설정을 잡에 그대로 전달 (값이 있는 것만)
  for v in KOGO_DATA KOGO_ENV KOGO_CONTAINER; do
      if [[ -n "${!v:-}" ]]; then printf 'export %s=%q\n' "$v" "${!v}"; fi
  done
  echo ""
  # bash 3.2 호환 인용 (${VAR@Q} 는 bash 4.4+ 전용이라 쓰지 않음)
  printf 'cd %q || exit 1\n' "$WORK"
  printf 'bash %q %s %q\n' "$MASTER" "$PHASE" "$WORK"
  echo "rc=\$?"
  echo "echo \"[JOB] exit=\$rc\""
  echo "exit \$rc"
} > "$SB"

# --- 제출 전 요약 ------------------------------------------------------------
cat <<EOS
────────────────────────────────────────────────────────────
 KOGO Day2 SLURM 제출 요약
────────────────────────────────────────────────────────────
 PHASE      : ${PHASE}
 사용자     : ${USER}
 job-name   : ${JOBNAME}
 partition  : ${PARTITION}$( [[ -z "$ACCOUNT" ]] && echo "   (account 미지정)" || echo "   account: ${ACCOUNT}" )
 자원       : ${CPUS} cpus / ${MEM} / ${TIMELIMIT}
 코드       : ${CODE_DIR}
 데이터     : ${KOGO_DATA:-(미지정 — 마스터가 자동 탐색)}
 conda      : ${KOGO_ENV:-(기본값)}$( [[ -n "$CONDA_SH_PATH" ]] && echo "   hook: ${CONDA_SH_PATH}" )
 산출물     : ${WORK}
 로그       : ${LOG//%j/<jobid>}
 배치파일   : ${SB}
────────────────────────────────────────────────────────────
EOS

if ! command -v sbatch >/dev/null 2>&1; then
    echo "[WARN] sbatch 를 찾을 수 없습니다 — 이 노드에서는 제출할 수 없습니다." >&2
    echo "       배치 파일은 만들어 두었으니 로그인 노드에서 제출하세요:" >&2
    echo "         sbatch ${SB}" >&2
    exit 1
fi

JOBID="$(sbatch --parsable "$SB")" || { echo "ERROR: sbatch 제출 실패" >&2; exit 1; }
echo "[제출됨] Job ID: ${JOBID}"
echo
echo "  상태 확인 : squeue -j ${JOBID}"
echo "  실시간 로그: tail -f ${LOG//%j/${JOBID}}"
echo "  종료 후    : sacct -j ${JOBID} --format=State,Elapsed,ExitCode"
echo "  취소       : scancel ${JOBID}"
