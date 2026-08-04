#!/bin/bash
# =============================================================================
#  KOGO 제20회 통계유전학 워크샵 · Day 2 — 판지놈 실습 ALL-IN-ONE (relocatable)
# -----------------------------------------------------------------------------
#  이 스크립트 하나로 실습 1~3 전 과정을 처음부터 끝까지 실행한다.
#  절대경로(/BiO/home/...)를 쓰지 않고, 이 스크립트가 놓인 위치를 기준으로
#  모든 데이터·툴을 상대적으로 찾는다. 따라서 폴더를 어디에 압축 풀든 그대로 동작한다.
#
#  [기대하는 폴더 구조]  (이 스크립트는 최상위 ROOT 에 위치)
#    ROOT/
#    ├── run_all_kogo_day2.sh        ← (이 파일) 여기서 실행
#    ├── 01_data_prepare/
#    │   ├── 00_toy_pangenome/       OUR.gbz, OUR.full.gbz, OUR.hapl, OUR.gfa.gz,
#    │   │                            OUR.vcf.gz(+.tbi), GRCh38.chr2_1-5Mb.fa(+.fai)
#    │   └── 01_srWGS/               HG00438_{1,2}.fq.gz, HG02257_{1,2}.fq.gz
#    └── tools/
#        ├── vg167_kmc324/bin/       vg(1.67.0), kmc, kmc_tools ...   (KMC 단계용)
#        ├── vg174_kmc324/bin/       vg(1.74.1)                       (매핑/콜/surject)
#        └── deepvariant_pangenome_aware_1.8.0.sif                    (DeepVariant)
#
#  [사용법]
#    bash run_all_kogo_day2.sh [PHASE] [WORKDIR]
#       PHASE   : all | 1 | 2 | 3     (기본 all)
#                   1 = 실습1  growth curve + 변이 분석        (bcftools/panacus)
#                   2 = 실습2  vg giraffe SV genotyping         (kmc/vg)
#                   3 = 실습3  pangenome-aware DeepVariant      (surject/DeepVariant)
#       WORKDIR : 산출물 폴더 (기본 ROOT/kogo_run) — 입력 데이터는 건드리지 않음
#
#  [사전 준비]  conda 환경 kogo 활성화 가능해야 함 (00_setup_env.sh 참고).
#              vg/kmc/DeepVariant SIF 는 tools/ 에 이미 들어있으므로 conda 로 설치 안 함.
#
#  ※ 실습 2·3 은 Linux x86_64 전용(vg/DeepVariant). arm64 Mac 에선 실행 불가(서버에서 실행).
# =============================================================================
set -eo pipefail

# =============================================================================
#  경로 3분리: 코드(CODE) · 데이터(DATA_ROOT) · 산출물(WORK)
# -----------------------------------------------------------------------------
#  데이터는 여러 사람이 공유(읽기 전용), 코드와 산출물은 각자 자기 디렉터리에서.
#
#    CODE_DIR   이 스크립트가 있는 곳            (각자 clone한 저장소)
#    DATA_ROOT  01_data_prepare/ 와 tools/ 가 있는 곳   (공유, 쓰기 안 함)
#    WORK       모든 산출물이 생기는 곳          (각자 개인 폴더, 기본 ./kogo_run)
#
#  우선순위
#    DATA_ROOT : $KOGO_DATA  →  코드 옆/상위에서 자동 탐색
#    WORK      : 2번째 인자  →  $KOGO_OUT  →  현재 디렉터리(PWD)/kogo_run
#
#  예) 공유 데이터 + 개인 작업공간
#    export KOGO_DATA=/data1/share/pangenome_kogo_2026
#    mkdir -p /work/my_run && cd /work/my_run
#    bash /path/to/repo/scripts/run_all_kogo_day2.sh all      # → /work/my_run/kogo_run/
# =============================================================================
CODE_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# ---- DATA_ROOT 결정 ---------------------------------------------------------
_has_data() { [[ -d "$1/01_data_prepare" || -d "$1/tools" ]]; }
if [[ -n "${KOGO_DATA:-}" ]]; then
    DATA_ROOT="${KOGO_DATA%/}"
elif [[ -n "${KOGO_ROOT:-}" ]]; then       # 이전 버전 호환
    DATA_ROOT="${KOGO_ROOT%/}"
elif _has_data "${CODE_DIR}"; then
    DATA_ROOT="${CODE_DIR}"                          # 스크립트와 데이터가 같은 폴더
elif _has_data "$(dirname "${CODE_DIR}")"; then
    DATA_ROOT="$(dirname "${CODE_DIR}")"             # 저장소 구조(scripts/ 하위)
else
    DATA_ROOT="$(dirname "${CODE_DIR}")"             # 미배치 — need()가 안내 출력
fi

# ---- conda 환경 활성화 -------------------------------------------------------
#  기본은 아래 KOGO_ENV 경로(prefix)를 그대로 씁니다. 다른 환경을 쓰려면
#    export KOGO_ENV=/내/경로/envs/kogo     (경로) 또는
#    export KOGO_ENV=kogo                   (이름)
#  이미 원하는 환경을 activate 한 상태라면  KOGO_ENV=skip  으로 건너뛸 수 있습니다.
KOGO_ENV="${KOGO_ENV:-/data1/dansay/conda/envs/kogo}"

if [[ "$KOGO_ENV" == "skip" ]]; then
    echo "[INFO] CONDA = (skip — 현재 활성 환경 사용: ${CONDA_PREFIX:-none})"
elif command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"
    if conda activate "$KOGO_ENV" 2>/dev/null; then
        echo "[INFO] CONDA = ${CONDA_PREFIX}"
    else
        echo "[WARN] conda activate '$KOGO_ENV' 실패 — 환경 없이 진행합니다." >&2
        echo "       환경을 만들려면: bash ${CODE_DIR}/00_setup_env.sh" >&2
        echo "       다른 환경을 쓰려면: export KOGO_ENV=<경로 또는 이름>" >&2
    fi
else
    echo "[WARN] conda 를 찾을 수 없습니다 — 환경 없이 진행합니다." >&2
fi
set -u

# ---- 입력 경로 (DATA_ROOT 기준, 읽기 전용) -----------------------------------
DATA="${DATA_ROOT}/01_data_prepare/00_toy_pangenome"
SRWGS="${DATA_ROOT}/01_data_prepare/01_srWGS"
TOOLS="${DATA_ROOT}/tools"
VG167="${TOOLS}/vg167_kmc324/bin"      # KMC 단계용 vg 1.67.0 + KMC
VG174="${TOOLS}/vg174_kmc324/bin"      # 매핑/콜/surject 용 vg 1.74.1
SIF="${TOOLS}/deepvariant_pangenome_aware_1.8.0.sif"

# ---- 산출물 경로 (개인 작업공간) ---------------------------------------------
PHASE="${1:-all}"
WORK="${2:-${KOGO_OUT:-${PWD}/kogo_run}}"
if ! mkdir -p "$WORK" 2>/dev/null; then
    echo "ERROR: 산출물 폴더를 만들 수 없습니다 → $WORK" >&2
    echo "       쓰기 권한이 있는 폴더로 이동해 실행하거나, 위치를 직접 지정하세요:" >&2
    echo "         cd /쓰기가능한/경로 && bash ${CODE_DIR}/$(basename "$0") ${PHASE}" >&2
    echo "         KOGO_OUT=/쓰기가능한/경로/kogo_run bash ${CODE_DIR}/$(basename "$0") ${PHASE}" >&2
    exit 1
fi
if [[ ! -w "$WORK" ]]; then
    echo "ERROR: 산출물 폴더에 쓸 수 없습니다(읽기 전용) → $WORK" >&2
    echo "       쓰기 권한이 있는 폴더로 이동해 실행하거나 KOGO_OUT 으로 지정하세요." >&2
    exit 1
fi
WORK="$(cd "$WORK" && pwd)"    # 절대경로로 정규화
SHARDS=3
THREADS=3
TAG=chr2_1-5Mb
export MPLCONFIGDIR="${TMPDIR:-/tmp}/matplotlib-${USER:-kogo}"; mkdir -p "$MPLCONFIGDIR"

mkdir -p "$WORK/bin"
echo "[INFO] CODE  = $CODE_DIR"
echo "[INFO] DATA  = $DATA_ROOT        (읽기 전용)"
echo "[INFO] WORK  = $WORK             (산출물)"
echo "[INFO] PHASE = $PHASE"

# 산출물 폴더가 데이터 폴더 안이면 경고 (공유 데이터 오염 방지)
case "$WORK/" in
  "${DATA_ROOT}/"*) echo "[WARN] WORK가 공유 데이터 폴더 안에 있습니다 — 개인 폴더 사용을 권장합니다." >&2 ;;
esac

# ---- 입력 점검 --------------------------------------------------------------
need() {
    [[ -e "$1" ]] && return 0
    cat >&2 <<EOF

ERROR: 필수 입력이 없습니다 → $1

이 저장소에는 코드·문서만 있고 실습 데이터·툴은 용량 때문에 포함돼 있지 않습니다.
데이터를 찾은 위치: DATA_ROOT=$DATA_ROOT
다른 곳(예: 공유 폴더)에 있다면 다음처럼 알려주세요:

  export KOGO_DATA=/공유/경로/pangenome_kogo_2026
  bash $0 $PHASE

DATA_ROOT 아래에 필요한 구조:

  \$DATA_ROOT/01_data_prepare/00_toy_pangenome/   OUR.gbz OUR.full.gbz OUR.gfa.gz OUR.hapl
                                            OUR.vcf.gz(+.tbi) GRCh38.chr2_1-5Mb.fa(+.fai)
  \$DATA_ROOT/01_data_prepare/01_srWGS/           HG00438_{1,2}.fq.gz  HG02257_{1,2}.fq.gz
  \$DATA_ROOT/tools/vg167_kmc324/bin/             vg(1.67.0) kmc kmc_tools    # 실습2-① 전용
  \$DATA_ROOT/tools/vg174_kmc324/bin/             vg(1.74.1)                  # 매핑·콜·surject
  \$DATA_ROOT/tools/deepvariant_pangenome_aware_1.8.0.sif                     # 실습3

산출물 위치를 바꾸려면:  KOGO_OUT=/개인/작업폴더 bash $0 $PHASE
자세한 안내는 docs/GUIDE.md 의 "필요한 데이터" 절 참조.

EOF
    exit 1
}
need "$DATA/OUR.gbz"; need "$DATA/OUR.vcf.gz"; need "$DATA/OUR.gfa.gz"

# ---- sampleList (상대경로가 아니라 ROOT 기준 절대경로로 기록) ----------------
mkdir -p "$WORK/04_vg_sv_genotyping"
cat > "$WORK/04_vg_sv_genotyping/sampleList.txt" <<SL
HG00438	${SRWGS}/HG00438_1.fq.gz	${SRWGS}/HG00438_2.fq.gz
HG02257	${SRWGS}/HG02257_1.fq.gz	${SRWGS}/HG02257_2.fq.gz
SL
SAMPLE_LIST="$WORK/04_vg_sv_genotyping/sampleList.txt"

# =============================================================================
#  내장 헬퍼 파이썬 (강사 원본 그대로) → WORK/bin/
# =============================================================================
cat > "$WORK/bin/01_filter_SV_by_trim.py" <<'KOGO_SV_PY'
#!/usr/bin/env python3
import sys
from cyvcf2 import VCF, Writer

def trim_both(ref, alt):
    """
    Remove common prefix and suffix between ref and alt alleles.
    Returns trimmed (ref, alt).
    """
    # trim common prefix
    while ref and alt and ref[0] == alt[0]:
        ref = ref[1:]
        alt = alt[1:]
    # trim common suffix
    while ref and alt and ref[-1] == alt[-1]:
        ref = ref[:-1]
        alt = alt[:-1]
    return ref, alt

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input_split.vcf.gz> <output_filtered.vcf.gz>")
        sys.exit(1)

    input_vcf = sys.argv[1]
    output_vcf = sys.argv[2]

    # Open the split (but not normalized) multi-allelic VCF
    vcf_in = VCF(input_vcf)
    vcf_out = Writer(output_vcf, vcf_in)

    for rec in vcf_in:
        passed = False
        # Check each ALT allele
        for alt in rec.ALT:
            # 1) Trim common sequence
            r_trim, a_trim = trim_both(rec.REF, alt)
            # 2) Compute trimmed lengths
            len_ref = len(r_trim)
            len_alt = len(a_trim)
            diff = abs(len_ref - len_alt)
            # MNPs: trimmed ref/alt len sample, len >= 50bp
            if len_ref == len_alt and len_ref >= 50:
                passed = True
            # INDEL case: trimmed length difference >= 50
            elif rec.is_indel and diff >= 50:
                passed = True
            # Substitution: trimmed REF or ALT length >= 50
            elif not rec.is_indel and (len_ref >= 50 or len_alt >= 50):
                passed = True

            # 조건 만족 시 var 출력
            if passed:
                vcf_out.write_record(rec)
                break


    vcf_out.close()
    vcf_in.close()

if __name__ == "__main__":
    main()

KOGO_SV_PY

cat > "$WORK/bin/01_pangenome_growth_curve.py" <<'KOGO_GROWTH_PY'
#!/usr/bin/env python3

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from functools import partial
from io import StringIO
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter as ADHF

def read_csv(filename, comment='#', **kwargs):
    lines = "".join([line for line in filename
                     if not line.startswith(comment)])
    return pd.read_csv(StringIO(lines), **kwargs)

def clean_multicolumn_labels(df):
    '''
    Replaces 'Unnamed: ...' column headers from hierarchical columns by empty
    strings.
    '''
    column_header = list()
    for c in df.columns:
        if isinstance(c, tuple):
            c = tuple((not x.startswith('Unnamed:') and x or '' for x in c))
        elif isinstance(c, str) and c.startswith('Unnamed:'):
            c = ''
        column_header.append(c)
    df.columns = pd.Index(column_header, tupleize_cols=True)
    return df

def humanize_number(i, precision=0):
    order = 0
    x = i
    if abs(i) > 0:
        order = int(np.log10(abs(i)))//3
        x = i/10**(order*3)

    human_r = ['', 'K', 'M', 'B', 'D']
    return '{:,.{prec}f}{:}'.format(x, human_r[order], prec=precision)

def calibrate_yticks_text(yticks):
    prec = 0
    yticks_text = list(map(partial(humanize_number, precision=prec), yticks))
    while len(set(yticks_text)) < len(yticks_text):
        prec += 1
        yticks_text = list(map(partial(humanize_number, precision=prec), yticks))
    return yticks_text

def plot_ordered_growth(df, ax, loc='upper left'):
    # Sort columns by coverage and quorum
    df = df.reindex(sorted(df.columns, key=lambda x: (x[3], x[2])), axis=1)
    
    # Adjust bar width for closer spacing
    bar_width = 0.7  # Adjust this value to reduce the gap between bars
    
    for i, (t, ct, c, q) in enumerate(df.columns):
        df[(t, ct, c, q)].plot.bar(color=f'C{i}', 
                                   label=f'coverage ≥ {c}, quorum ≥ {q*100:.0f}%', 
                                   edgecolor='black', ax=ax, width=bar_width)
    
    ax.set_xticklabels(ax.get_xticklabels(), rotation=90)
    
    yticks = ax.get_yticks()
    ax.set_yticks(yticks)
    ax.set_yticklabels(calibrate_yticks_text(yticks))
    
    ax.set_title(f'{df.columns[0][0]} plot for #{df.columns[0][1]}s')
    ax.set_ylabel(f'#{df.columns[0][1]}s')
    ax.set_xlabel('samples')
    ax.legend(loc=loc)


if __name__ == '__main__':
    description = '''
    Visualize ordered growth stats from panacus output.
    '''
    parser = ArgumentParser(formatter_class=ADHF, description=description)
    parser.add_argument('stats', type=open,
            help='Ordered growth table computed by panacus')
    parser.add_argument('-l', '--legend_location',
            choices=['lower left', 'lower right', 'upper left', 'upper right'],
            default='upper left',
            help='Legend location')
    parser.add_argument('-s', '--figsize', nargs=2, type=int, default=[12, 8],
            help='Set size of figure canvas')
    parser.add_argument('-f', '--format', default='pdf', 
            choices=['pdf', 'png', 'svg', 'eps'],
            help='Specify the format of the output')
    parser.add_argument('-o', '--output', default='pangenome_growth_curve',
            help='Output filename (without extension)')

    args = parser.parse_args()

    # Read and process data
    N_HEADERS = 4
    df = clean_multicolumn_labels(read_csv(args.stats, sep='\t', 
                                         header=list(range(N_HEADERS)), 
                                         index_col=[0], comment='#'))
    
    # Convert column labels to appropriate types
    df.columns = df.columns.map(lambda x: (x[0], x[1], 
                                         x[2] and int(x[2].replace("A", "")), 
                                         x[3] and float(x[3].replace("R", ""))))
    
    # Filter for ordered-growth data only
    ordered_growth_cols = [col for col in df.columns if col[0] == 'ordered-growth']
    df_ordered = df[ordered_growth_cols]
    
    # Remove row with index '0' if it exists and contains only NaN values
    if '0' in df_ordered.index and df_ordered.loc['0'].isna().all():
        df_ordered.drop(['0'], inplace=True)
    
    # Setup plot style
    sns.set_theme(style='white')
    sns.set_color_codes('colorblind')
    sns.set_palette('Set2')
    sns.despine(left=True, bottom=True)
    
    # Create single plot
    fig, ax = plt.subplots(1, 1, figsize=args.figsize)
    
    # Plot ordered growth
    plot_ordered_growth(df_ordered, ax, loc=args.legend_location)
    
    plt.tight_layout()
    
    # Save plot
    output_filename = f"{args.output}.{args.format}"
    plt.savefig(output_filename, format=args.format, dpi=300, bbox_inches='tight')
    print(f"Plot saved as {output_filename}")
    
    plt.show()
    plt.close()
KOGO_GROWTH_PY

chmod +x "$WORK"/bin/*.py

# =============================================================================
#  PHASE 1 — 실습1: growth curve + 변이 분석
# =============================================================================
phase1() {
  echo "======================== PHASE 1 (실습1) ========================"

  # ---- 1-② growth curve ----------------------------------------------------
  mkdir -p "$WORK/02_pangenome_growth_curve"; pushd "$WORK/02_pangenome_growth_curve" >/dev/null
  if [[ ! -s OUR.gfa ]]; then
      if command -v pigz >/dev/null 2>&1; then pigz -dc -p "$THREADS" "$DATA/OUR.gfa.gz" > OUR.gfa
      else gzip -dc "$DATA/OUR.gfa.gz" > OUR.gfa; fi
  fi
  awk -F'\t' '$1=="W"{print $2}' OUR.gfa | grep -Ei  'grch38|chm13' | sort -u > ref.txt
  awk -F'\t' '$1=="W"{print $2}' OUR.gfa | grep -Evi 'grch38|chm13' | sort -u > subset.txt
  echo "[INFO] reference: $(wc -l < ref.txt) / haplotypes: $(wc -l < subset.txt)"
  if ( RUST_LOG=info panacus ordered-histgrowth -c bp -l 1,2,1,1,1 -q 0,0,1,0.5,0.1 \
         -S -e ref.txt -O subset.txt OUR.gfa > histgrowth.OUR.${TAG}.tsv && \
       python "$WORK/bin/01_pangenome_growth_curve.py" histgrowth.OUR.${TAG}.tsv \
         -o OUR_${TAG}_growth_curve -f png ); then
      echo "[DONE] growth curve → OUR_${TAG}_growth_curve.png"
  else
      echo "[WARN] growth curve 단계 실패(panacus 버전 이슈 가능) — 계속 진행" >&2
  fi
  popd >/dev/null

  # ---- 1-③ 변이 분석 -------------------------------------------------------
  mkdir -p "$WORK/03_variant_analysis"; pushd "$WORK/03_variant_analysis" >/dev/null
  local VCF="$DATA/OUR.vcf.gz"

  # (1) 변이 타입 split & SV
  rm -rf 01_type_split; mkdir 01_type_split; local DIR=01_type_split
  bcftools view -v snps --threads $THREADS "$VCF" \
    | bcftools view -V indels,mnps,other --threads $THREADS -o ${DIR}/SNVs_only.vcf.gz -Oz
  bcftools view -v indels,mnps,other --threads $THREADS "$VCF" -o ${DIR}/non_SNVs.vcf.gz -Oz
  bcftools norm --threads $THREADS -m -any -N ${DIR}/non_SNVs.vcf.gz \
    | bcftools view -V snps --threads $THREADS -Oz -o ${DIR}/tmp.vcf.gz
  python "$WORK/bin/01_filter_SV_by_trim.py" ${DIR}/tmp.vcf.gz ${DIR}/tmp_SV.vcf.gz
  bcftools norm --threads $THREADS -m +any -N -Oz -o ${DIR}/SVs.vcf.gz ${DIR}/tmp_SV.vcf.gz
  rm -f ${DIR}/tmp.vcf.gz ${DIR}/tmp_SV.vcf.gz
  : > ${DIR}/loci_count.txt
  for f in SNVs_only non_SNVs SVs; do
    echo "${f}.vcf.gz" >> ${DIR}/loci_count.txt
    bcftools +counts ${DIR}/${f}.vcf.gz >> ${DIR}/loci_count.txt
  done

  # (2) 집단 특이 변이 (our=sample*, control=CHM13/HG/NA)
  rm -rf 02_our_population_spec_var; mkdir 02_our_population_spec_var; DIR=02_our_population_spec_var
  bcftools view -h "$VCF" | grep -v "##" | tr '\t' '\n' | tail -n+10 | grep -v "sample" | grep -P "HG|NA|CHM13" > ${DIR}/control.txt
  bcftools view -h "$VCF" | grep -v "##" | tr '\t' '\n' | tail -n+10 | grep "sample" | grep -vP "HG|NA|CHM13" > ${DIR}/our.txt
  ls -1 01_type_split/*vcf.gz | sort -V | while read -r V; do
    local NAME=$(basename ${V%.vcf.gz})_spec.vcf.gz
    bcftools view --threads $THREADS -S ${DIR}/our.txt ${V}     | bcftools view --threads $THREADS -c1 -Oz > ${DIR}/group_var.vcf.gz
    bcftools view --threads $THREADS -S ${DIR}/control.txt ${V} | bcftools view --threads $THREADS -c1 -Oz > ${DIR}/col_var.vcf.gz
    bcftools view --threads $THREADS -S ${DIR}/control.txt ${V} | bcftools view --threads $THREADS -g miss -Oz > ${DIR}/col_miss.vcf.gz
    tabix -f ${DIR}/group_var.vcf.gz; tabix -f ${DIR}/col_var.vcf.gz; tabix -f ${DIR}/col_miss.vcf.gz
    bcftools isec --threads $THREADS -n~100 -w 1 -Oz -p ${DIR}/intersect ${DIR}/group_var.vcf.gz ${DIR}/col_var.vcf.gz ${DIR}/col_miss.vcf.gz
    mv ${DIR}/intersect/0000.vcf.gz ${DIR}/${NAME}
    rm -rf ${DIR}/group_var.vcf.gz* ${DIR}/col_var.vcf.gz* ${DIR}/col_miss.vcf.gz* ${DIR}/intersect
    echo ${NAME} >> ${DIR}/loci_count.txt
    bcftools +counts ${DIR}/${NAME} >> ${DIR}/loci_count.txt
  done

  # (3) 개인 특이 변이
  rm -rf 03_individual_spec_var; mkdir -p 03_individual_spec_var; local PDIR=03_individual_spec_var
  ls -1 02_our_population_spec_var/*_spec.vcf.gz | sort -V | while read -r V; do
    local SDIR=${PDIR}/$(basename ${V%.vcf.gz}); mkdir -p ${SDIR}
    for SAMPLE in $(bcftools query -l ${V}); do
      bcftools view -s ${SAMPLE}  ${V} | bcftools view -c1 -o ${SDIR}/sample_var.vcf.gz -Oz
      bcftools view -s ^${SAMPLE} ${V} | bcftools view -c1 -o ${SDIR}/other_var.vcf.gz  -Oz
      tabix -f ${SDIR}/sample_var.vcf.gz; tabix -f ${SDIR}/other_var.vcf.gz
      bcftools isec --threads $THREADS -n~10 -w 1 -Oz -p ${SDIR}/intersect ${SDIR}/sample_var.vcf.gz ${SDIR}/other_var.vcf.gz
      mv ${SDIR}/intersect/0000.vcf.gz ${SDIR}/${SAMPLE}_spec.vcf.gz
      rm -rf ${SDIR}/sample_var.vcf.gz* ${SDIR}/other_var.vcf.gz* ${SDIR}/intersect
      echo ${SAMPLE}_spec.vcf.gz >> ${SDIR}/loci_count.txt
      bcftools +counts ${SDIR}/${SAMPLE}_spec.vcf.gz >> ${SDIR}/loci_count.txt
    done
  done
  echo "[DONE] 변이 분석 → 01_type_split / 02_our_population_spec_var / 03_individual_spec_var 의 loci_count.txt"
  popd >/dev/null
}

# =============================================================================
#  PHASE 2 — 실습2: vg giraffe SV genotyping  (Linux x86_64 전용)
# =============================================================================
phase2() {
  echo "======================== PHASE 2 (실습2) ========================"
  mkdir -p "$WORK/04_vg_sv_genotyping"; pushd "$WORK/04_vg_sv_genotyping" >/dev/null
  local GRAPH="$DATA/OUR.gbz" HAPL="$DATA/OUR.hapl"

  # --- 2-① KMC + vg haplotypes (vg 1.67.0) ---
  ( export PATH="${VG167}:$PATH"; echo "[vg] $(which vg)"; vg version | head -1
    mkdir -p 01_sample
    while read -r SAMPLE R1 R2; do
      [[ -z "$SAMPLE" ]] && continue
      echo "==== [$SAMPLE] KMC + vg haplotypes ===="
      printf "%s\n%s\n" "$R1" "$R2" > 01_sample/${SAMPLE}.fastq_list.txt
      kmc -k29 -m64 -okff -t${THREADS} @01_sample/${SAMPLE}.fastq_list.txt 01_sample/${SAMPLE}.srWGS 01_sample
      vg haplotypes -v 2 -t ${THREADS} --include-reference --diploid-sampling \
         -i "$HAPL" -k 01_sample/${SAMPLE}.srWGS.kff -g 01_sample/${SAMPLE}_sampled.gbz "$GRAPH"
      vg snarls -t ${THREADS} 01_sample/${SAMPLE}_sampled.gbz > 01_sample/${SAMPLE}_sampled.snarls
    done < "$SAMPLE_LIST" )

  # --- 2-② vg giraffe 매핑 (vg 1.74.1) ---
  ( export PATH="${VG174}:$PATH"; echo "[vg] $(which vg)"; vg version | head -1
    mkdir -p 02_SR_mapping
    while read -r SAMPLE R1 R2; do
      [[ -z "$SAMPLE" ]] && continue
      echo "==== [$SAMPLE] vg giraffe ===="
      vg giraffe -p -t ${THREADS} -Z 01_sample/${SAMPLE}_sampled.gbz -f "$R1" -f "$R2" \
         > 02_SR_mapping/${SAMPLE}.${TAG}.gam 2> 02_SR_mapping/${SAMPLE}.${TAG}.gam.log
      vg stats --threads ${THREADS} -a 02_SR_mapping/${SAMPLE}.${TAG}.gam > 02_SR_mapping/${SAMPLE}.${TAG}.gam.stats.txt
    done < "$SAMPLE_LIST" )

  # --- 2-③ vg pack + vg call → merge (vg 1.74.1) ---
  ( export PATH="${VG174}:$PATH"
    mkdir -p 03_SV_call
    while read -r SAMPLE R1 R2; do
      [[ -z "$SAMPLE" ]] && continue
      echo "==== [$SAMPLE] vg pack + vg call ===="
      vg pack -t ${THREADS} -x 01_sample/${SAMPLE}_sampled.gbz --gam 02_SR_mapping/${SAMPLE}.${TAG}.gam \
         -o 03_SV_call/${SAMPLE}.pack --min-mapq 5
      vg call -t ${THREADS} --ref-sample GRCh38 01_sample/${SAMPLE}_sampled.gbz \
         --genotype-snarls --all-snarls --snarls 01_sample/${SAMPLE}_sampled.snarls \
         --pack 03_SV_call/${SAMPLE}.pack --sample ${SAMPLE} --gbz \
         | bgzip > 03_SV_call/${SAMPLE}.vg.call.vcf.gz
      bcftools index 03_SV_call/${SAMPLE}.vg.call.vcf.gz
    done < "$SAMPLE_LIST"
    mapfile -t VCFS < <(find 03_SV_call -maxdepth 1 -name '*.vg.call.vcf.gz' | sort)
    if (( ${#VCFS[@]} > 1 )); then
      bcftools merge -m all "${VCFS[@]}" -Oz | bcftools view -f PASS -Oz -o 03_SV_call/Total_merged.${TAG}.vcf.gz
      bcftools index 03_SV_call/Total_merged.${TAG}.vcf.gz
    fi )
  echo "[DONE] 실습2 → 04_vg_sv_genotyping/03_SV_call/Total_merged.${TAG}.vcf.gz"
  popd >/dev/null
}

# =============================================================================
#  PHASE 3 — 실습3: pangenome-aware DeepVariant  (공유메모리 미사용 방식)
# =============================================================================
phase3() {
  echo "======================== PHASE 3 (실습3) ========================"
  mkdir -p "$WORK/05_deepvariant"; pushd "$WORK/05_deepvariant" >/dev/null
  local REF_SAMPLE=GRCh38 REF_CONTIG=chr2
  local PATH_GBZ="$DATA/OUR.full.gbz" REF="$DATA/GRCh38.${TAG}.fa" PANGENOME="$DATA/OUR.gbz"

  # --- 3-① GAM → GRCh38 BAM surject (vg 1.74.1) ---
  ( export PATH="${VG174}:$PATH"; echo "[vg] $(which vg)"; vg version | head -1
    mkdir -p surject
    while read -r SAMPLE R1 R2; do
      [[ -z "$SAMPLE" ]] && continue
      echo "==== [$SAMPLE] vg surject ===="
      local GBZ="$WORK/04_vg_sv_genotyping/01_sample/${SAMPLE}_sampled.gbz"
      local GAM="$WORK/04_vg_sv_genotyping/02_SR_mapping/${SAMPLE}.${TAG}.gam"
      local PATHS=surject/${REF_SAMPLE}.${SAMPLE}.paths.txt
      vg paths -x "$PATH_GBZ" -S ${REF_SAMPLE} -L > ${PATHS}
      local PATH_CONTIG=$(head -n1 ${PATHS})
      vg surject -t ${THREADS} -x "$GBZ" -F ${PATHS} -b -i \
         -N ${SAMPLE} -R "ID:1\tLB:lib1\tSM:${SAMPLE}\tPL:illumina\tPU:unit1" "$GAM" \
         | samtools sort -@ ${THREADS} -O BAM -o surject/${SAMPLE}.raw.bam
      samtools view -H surject/${SAMPLE}.raw.bam \
        | awk -v old="${PATH_CONTIG}" -v new="${REF_CONTIG}" 'BEGIN{OFS="\t"} /^@SQ/{for(i=1;i<=NF;i++) if($i=="SN:"old)$i="SN:"new}{print}' \
        > surject/${SAMPLE}.reheader.sam
      samtools reheader surject/${SAMPLE}.reheader.sam surject/${SAMPLE}.raw.bam > surject/${SAMPLE}.grch38.${TAG}.bam
      rm -f surject/${SAMPLE}.raw.bam surject/${SAMPLE}.reheader.sam
      samtools index surject/${SAMPLE}.grch38.${TAG}.bam
      samtools flagstat --output-fmt tsv surject/${SAMPLE}.grch38.${TAG}.bam > surject/${SAMPLE}.flagstat.tsv
    done < "$SAMPLE_LIST" )

  # --- 3-② pangenome-aware DeepVariant (공유메모리 없이 3단계 직접 호출) + GLnexus ---
  #  강사 수정본: run_pangenome_aware_deepvariant(고정이름 공유메모리) 대신
  #  make_examples → call_variants → postprocess 를 직접 호출 → /dev/shm 충돌 없음.

  # 컨테이너 런타임 자동 감지: apptainer 또는 singularity (둘은 CLI 호환)
  #   강제 지정: export KOGO_CONTAINER=/path/to/singularity
  local CONTAINER_CMD="${KOGO_CONTAINER:-}"
  if [[ -z "$CONTAINER_CMD" ]]; then
      if   command -v apptainer   >/dev/null 2>&1; then CONTAINER_CMD=apptainer
      elif command -v singularity >/dev/null 2>&1; then CONTAINER_CMD=singularity
      fi
  fi
  if [[ -z "$CONTAINER_CMD" ]] || ! command -v "$CONTAINER_CMD" >/dev/null 2>&1; then
      echo "ERROR: apptainer/singularity 를 찾을 수 없습니다 — DeepVariant 를 실행할 수 없습니다." >&2
      echo "       둘 중 하나가 PATH 에 있어야 합니다. 경로를 직접 지정할 수도 있습니다:" >&2
      echo "         export KOGO_CONTAINER=/usr/local/bin/singularity" >&2
      echo "       (모듈 시스템이면: module load singularity  또는  module load apptainer)" >&2
      return 1
  fi
  echo "[INFO] CONTAINER = $(command -v "$CONTAINER_CMD")  ($("$CONTAINER_CMD" --version 2>&1 | head -1))"

  local INPUTD=input OUTPUTD=output JOINTD=joint
  mkdir -p ${INPUTD} ${OUTPUTD} ${JOINTD}
  local REFB=$(basename "$REF") PANB=$(basename "$PANGENOME")
  # 참조·판지놈을 개인 작업공간으로 복사 후 여기서 색인한다.
  # (공유 데이터 폴더는 읽기 전용일 수 있으므로 .fai 를 그쪽에 만들지 않는다)
  cp "$REF" "$PANGENOME" ${INPUTD}/
  if [[ -s "${REF}.fai" ]]; then
      cp "${REF}.fai" ${INPUTD}/
  else
      samtools faidx "${INPUTD}/${REFB}"
  fi

  while read -r SAMPLE R1 R2; do
    [[ -z "$SAMPLE" ]] && continue
    echo "==== [$SAMPLE] pangenome-aware DeepVariant (no shared memory) ===="
    cp surject/${SAMPLE}.grch38.${TAG}.bam surject/${SAMPLE}.grch38.${TAG}.bam.bai ${INPUTD}/
    local BAMB=${SAMPLE}.grch38.${TAG}.bam
    local TMPD=tmp_${SAMPLE}; rm -rf ${TMPD}; mkdir -p ${TMPD}
    "${CONTAINER_CMD}" exec \
      --bind "$(pwd)/${INPUTD}:/input" \
      --bind "$(pwd)/${OUTPUTD}:/output" \
      --bind "$(pwd)/${TMPD}:/work" \
      "${SIF}" \
      bash -c "
        set -eo pipefail
        seq 0 $((SHARDS - 1)) | parallel -q --halt 2 --line-buffer \
          /opt/deepvariant/bin/make_examples_pangenome_aware_dv \
            --mode calling \
            --ref /input/${REFB} \
            --reads /input/${BAMB} \
            --pangenome /input/${PANB} \
            --examples /work/make_examples_pangenome_aware_dv.tfrecord@${SHARDS}.gz \
            --checkpoint /opt/models/pangenome_aware_deepvariant/wgs \
            --gvcf /work/gvcf.tfrecord@${SHARDS}.gz \
            --keep_legacy_allele_counter_behavior \
            --keep_only_window_spanning_haplotypes \
            --keep_supplementary_alignments \
            --min_mapping_quality 0 \
            --normalize_reads \
            --sample_name_pangenome hprc_v1.1 \
            --sort_by_haplotypes \
            --trim_reads_for_pileup \
            --task {}

        /opt/deepvariant/bin/call_variants \
          --outfile /work/call_variants_output.tfrecord.gz \
          --examples /work/make_examples_pangenome_aware_dv.tfrecord@${SHARDS}.gz \
          --checkpoint /opt/models/pangenome_aware_deepvariant/wgs

        /opt/deepvariant/bin/postprocess_variants \
          --ref /input/${REFB} \
          --infile /work/call_variants_output.tfrecord.gz \
          --outfile /output/${SAMPLE}.pgdv.vcf.gz \
          --gvcf_outfile /output/${SAMPLE}.pgdv.g.vcf.gz \
          --nonvariant_site_tfrecord_path /work/gvcf.tfrecord@${SHARDS}.gz
      "
    bcftools index -f ${OUTPUTD}/${SAMPLE}.pgdv.vcf.gz
    bcftools index -f ${OUTPUTD}/${SAMPLE}.pgdv.g.vcf.gz
  done < "$SAMPLE_LIST"

  mapfile -t GVCFS < <(find ${OUTPUTD} -maxdepth 1 -name '*.pgdv.g.vcf.gz' | sort)
  if (( ${#GVCFS[@]} > 0 )); then
    echo "==== GLnexus joint genotyping (${#GVCFS[@]} gVCFs) ===="
    glnexus_cli --config DeepVariantWGS "${GVCFS[@]}" | bcftools view -Oz -o ${JOINTD}/OUR.pgdv.GLnexus.${TAG}.vcf.gz
    bcftools index -f ${JOINTD}/OUR.pgdv.GLnexus.${TAG}.vcf.gz
  fi
  echo "[DONE] 실습3 → 05_deepvariant/output/{SAMPLE}.pgdv.vcf.gz , joint/OUR.pgdv.GLnexus.${TAG}.vcf.gz"
  popd >/dev/null
}

# ---- 실행 ----
case "$PHASE" in
  1) phase1 ;;
  2) phase2 ;;
  3) phase3 ;;
  all) phase1; phase2; phase3 ;;
  *) echo "PHASE must be one of: all 1 2 3"; exit 1 ;;
esac
echo "[ALL DONE] PHASE=$PHASE"
