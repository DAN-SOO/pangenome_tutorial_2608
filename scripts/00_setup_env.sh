#!/usr/bin/env bash
# =============================================================================
#  KOGO Day2 판지놈 실습 — conda 환경(kogo) 생성
# -----------------------------------------------------------------------------
#  vg / kmc / DeepVariant(SIF) 는 tools/ 폴더에 이미 동봉되어 있으므로 conda 로는
#  설치하지 않는다. 여기서는 파싱·시각화·VCF 처리·GLnexus 등 나머지만 설치한다.
#
#  ※ mamba(또는 conda)가 이미 있어야 한다. 없으면 동봉된 Miniforge 로 먼저 설치:
#       bash Miniforge3-Linux-x86_64.sh      (동봉되어 있으면 ROOT 에 있음)
#     설치 후 새 셸에서 (base) 확인.
# =============================================================================
set -euo pipefail

# 환경 위치(prefix) — 마스터 스크립트의 기본값과 동일하게 맞춘다.
#   다른 곳에 만들려면:  KOGO_ENV=/내/경로/envs/kogo bash 00_setup_env.sh
KOGO_ENV="${KOGO_ENV:-/data1/dansay/conda/envs/kogo}"

# 공용 conda 의 패키지 캐시에 쓰기 권한이 없는 서버 대비 (개인 캐시 사용)
export CONDA_PKGS_DIRS="${CONDA_PKGS_DIRS:-$(dirname "$(dirname "$KOGO_ENV")")/pkgs}"

# mamba 우선, 없으면 conda
CREATE="mamba"; command -v mamba >/dev/null 2>&1 || CREATE="conda"
echo "[INFO] using   : $CREATE"
echo "[INFO] env path: $KOGO_ENV"
echo "[INFO] pkg cache: $CONDA_PKGS_DIRS"

mkdir -p "$(dirname "$KOGO_ENV")" "$CONDA_PKGS_DIRS"

# panacus 는 0.5.x 에서 ordered-histgrowth 가 빈 결과를 내는 버그가 있어 0.4.1 로 고정한다.
$CREATE create -y -p "$KOGO_ENV" -c conda-forge -c bioconda \
  python=3.12 pandas matplotlib numpy seaborn \
  cyvcf2 panacus=0.4.1 bcftools htslib samtools \
  pigz glnexus parallel wget git

eval "$(conda shell.bash hook)"; conda activate "$KOGO_ENV"
echo
echo "[OK] kogo 환경 생성 완료:"
panacus --version
bcftools --version | head -1
python -c "import cyvcf2, pandas, matplotlib, seaborn; print('py libs OK')"
echo
echo "  ※ vg/kmc 는 동봉된 tools/vg167_kmc324, tools/vg174_kmc324 사용 (마스터 스크립트가 자동 참조)"
echo "  ※ DeepVariant 는 동봉된 tools/deepvariant_pangenome_aware_1.8.0.sif 사용 (apptainer 필요)"
echo
echo "다음 단계:"
echo "  1) 데이터 확인 :  export KOGO_DATA=<공유 데이터 경로>"
echo "                    bash $(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/check_data.sh"
echo "  2) 실행        :  mkdir -p ./pangenome_run && cd ./pangenome_run"
echo "                    bash $(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/run_all_kogo_day2.sh all"
echo
echo "  ※ 마스터 스크립트가 이 환경($KOGO_ENV)을 자동으로 활성화하므로"
echo "     따로 conda activate 하지 않아도 됩니다."
