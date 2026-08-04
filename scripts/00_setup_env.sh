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

# mamba 우선, 없으면 conda
CREATE="mamba"; command -v mamba >/dev/null 2>&1 || CREATE="conda"
echo "[INFO] using: $CREATE"

$CREATE create -y -n kogo -c conda-forge -c bioconda \
  python=3.12 pandas matplotlib numpy seaborn \
  cyvcf2 panacus bcftools htslib samtools \
  pigz glnexus parallel wget git

eval "$(conda shell.bash hook)"; conda activate kogo
echo
echo "[OK] kogo 환경 생성 완료:"
panacus --version
bcftools --version | head -1
python -c "import cyvcf2, pandas, matplotlib, seaborn; print('py libs OK')"
echo
echo "  ※ vg/kmc 는 동봉된 tools/vg167_kmc324, tools/vg174_kmc324 사용 (마스터 스크립트가 자동 참조)"
echo "  ※ DeepVariant 는 동봉된 tools/deepvariant_pangenome_aware_1.8.0.sif 사용 (apptainer 필요)"
echo
echo "다음: conda activate kogo && bash run_all_kogo_day2.sh"
