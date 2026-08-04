# KOGO Day2 판지놈 실습 — 처음부터 끝까지 (자체완결 패키지)

한국인 판지놈(KPP) toy 그래프(chr2:1-5Mb)로 **매핑 → 변이 분석 → SV genotyping →
small variant calling** 전 과정을 한 폴더 안에서 실행하는 패키지입니다.
**모든 스크립트는 강사 원본 코드 기반**이고, 경로는 전부 자동 감지·환경변수로 정해지므로
어디에 두든 그대로 돌아갑니다. 데이터는 공유(읽기 전용)하고 산출물은 각자 폴더에 씁니다.

---

전체 데이터 흐름 그림은 `kogo_pipeline_overview.png` 참고 (각 단계가 무엇을
소비하고 무엇을 만드는지 한눈에).

> 처음 설치하신다면 **[SETUP.md](SETUP.md)** 를 보세요 (단계별 상세 안내).

## 0. 빠른 시작 (TL;DR)

**데이터는 공유, 코드와 산출물은 각자 자기 디렉터리**에서 돌아갑니다.

```bash
# 0) 코드 — 원하는 디렉터리에 clone (1회)
git clone https://github.com/DAN-SOO/pangenome_tutorial_2608.git \
    /data1/dansay/tools/pangenome_tutorial_2608
export KOGO_CODE=/data1/dansay/tools/pangenome_tutorial_2608

# 1) 공유 데이터 위치 지정 (~/.bashrc 에 넣어두면 매번 안 써도 됩니다)
export KOGO_DATA=/data1/dansay/test/pangenome_kogo_2026

# 2) conda 환경 (최초 1회) — mamba/conda 필요
bash "$KOGO_CODE/scripts/00_setup_env.sh"
conda activate kogo
bash "$KOGO_CODE/scripts/check_data.sh"          # 데이터 배치 확인 (일치 19 / 없음 0)

# 3) 자기 작업 폴더에서 실행 — 산출물이 여기 생깁니다
mkdir -p /data1/dansay/run/pangenome_run && cd /data1/dansay/run/pangenome_run
bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh"            # = PHASE all
#  또는 단계별:
bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" 1          # 실습1 (growth curve + 변이 분석)
bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" 2          # 실습2 (vg giraffe SV genotyping)
bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" 3          # 실습3 (pangenome-aware DeepVariant)
```

### 경로 3분리

| 구분 | 결정 방식 | 쓰기 |
|---|---|---|
| **CODE** | 스크립트 위치에서 자동 | 안 함 |
| **DATA** | `$KOGO_DATA` → 없으면 코드 옆/상위 자동 탐색 | **안 함** (읽기 전용 OK) |
| **WORK** | 2번째 인자 → `$KOGO_OUT` → **현재 디렉터리**`/kogo_run` | 여기만 |

산출물 위치를 명시하려면 `KOGO_OUT=/scratch/$USER/kogo_run` 또는 2번째 인자
(`bash .../run_all_kogo_day2.sh all /원하는/출력폴더`). 실행 시작 시 세 경로를 출력합니다.

여러 사람이 같은 `$KOGO_DATA`를 동시에 써도 서로 간섭하지 않습니다 — 공유 폴더에는
아무것도 쓰지 않고, DeepVariant용 참조 색인(`.fai`)도 각자 작업 폴더에서 만듭니다.

### SLURM 예시

```bash
#!/bin/bash
#SBATCH --job-name=kogo_day2
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G
#SBATCH --output=kogo_day2.%j.log

source /path/to/conda/etc/profile.d/conda.sh
export CONDA_PKGS_DIRS=$HOME/conda/pkgs      # 공용 캐시 쓰기 불가한 서버 대비
conda activate kogo

export KOGO_CODE=/data1/dansay/tools/pangenome_tutorial_2608
export KOGO_DATA=/data1/dansay/test/pangenome_kogo_2026
cd /data1/dansay/run/pangenome_run            # 산출물이 여기 생김
bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" all
```

---

## 1. 폴더 구조

```
kogo_day2_pkg/
├── run_all_kogo_day2.sh          ← 마스터 스크립트 (여기서 실행)
├── 00_setup_env.sh               ← conda 환경 생성 (최초 1회)
├── GUIDE.md                      ← (이 문서)
├── 01_data_prepare/
│   ├── 00_toy_pangenome/         OUR.gbz · OUR.full.gbz · OUR.hapl · OUR.gfa.gz
│   │                              OUR.vcf.gz(+.tbi) · GRCh38.chr2_1-5Mb.fa(+.fai)
│   └── 01_srWGS/                 HG00438_{1,2}.fq.gz · HG02257_{1,2}.fq.gz
└── tools/
    ├── vg167_kmc324/bin/         vg 1.67.0 + kmc/kmc_tools (실습2 KMC 단계)
    ├── vg174_kmc324/bin/         vg 1.74.1 (매핑·콜·surject)
    └── deepvariant_pangenome_aware_1.8.0.sif   (실습3 DeepVariant, ~3.3GB)
```

마스터 스크립트는 자신이 놓인 폴더(ROOT)를 자동 감지해 위 경로를 상대적으로 찾습니다.
**절대경로(`/BiO/home/...`)를 전혀 쓰지 않습니다.**

---

## 2. 실습이 하는 일 — 개념부터

핵심 구분(강사 슬라이드 18):

- **실습 1** = 판지놈 **구축 VCF**(`OUR.vcf.gz`) 분석.
  판지놈 그래프에 이미 담긴 4명(sample01~04)의 변이(bubble/snarl). 새 데이터 불필요.
- **실습 2·3** = 판지놈에 **없는 새 샘플**(HG00438, HG02257)의 short-read 분석.
  - 실습 2: 판지놈의 큰 변이(SV)를 이 샘플이 갖는지 **genotyping** (vg pack/call)
  - 실습 3: 이 샘플의 SNV·INDEL 을 **호출** (DeepVariant, genotyping 아님)

### PHASE 1 — 실습1 (bcftools / panacus)

1. **growth curve** (`02_pangenome_growth_curve`)
   `OUR.gfa.gz` 압축 해제 → `panacus ordered-histgrowth`로 샘플을 하나씩 더할 때
   판지놈이 커버하는 서열(bp)이 얼마나 늘어나는지 곡선을 그림. 참조(GRCh38/CHM13)는
   `-e ref.txt`로 제외, 샘플 순서는 `-O subset.txt`로 고정.
2. **변이 타입 분류** (`03_variant_analysis/01_type_split`)
   `OUR.vcf.gz`를 SNV / non-SNV / SV 로 나눔.
   - SNV = `bcftools view -v snps | view -V indels,mnps,other`
   - non-SNV = `view -v indels,mnps,other`
   - SV = non-SNV를 `norm -m -any -N`(다대립 split만) → non-SNP만 → 강사 `.py`로
     양끝 trim 후 길이차 ≥50bp만 → `norm -m +any -N`(재결합, site당 1건)
3. **집단 특이 변이** (`02_our_population_spec_var`)
   our(sample01~04)에는 있고 control(CHM13)에는 없는 변이. `bcftools isec -n~100 -w1`.
4. **개인 특이 변이** (`03_individual_spec_var`)
   한 샘플에만 있고 나머지 our 샘플엔 없는 변이. `bcftools isec -n~10 -w1`.

### PHASE 2 — 실습2 (kmc / vg giraffe)

1. **KMC + vg haplotypes** (`01_sample`, vg 1.67.0)
   새 샘플 FASTQ에서 k-mer(k=29) 계수(`.kff`) → `vg haplotypes`로 그 샘플에 맞는
   **개인 맞춤 그래프**(`_sampled.gbz`) 생성 + `vg snarls`.
2. **vg giraffe 매핑** (`02_SR_mapping`, vg 1.74.1)
   short-read를 개인 맞춤 그래프에 매핑 → GAM. `vg stats -a`로 통계.
3. **vg pack + vg call** (`03_SV_call`, vg 1.74.1)
   read support(`pack`) → `vg call`로 SV genotype → 샘플 병합
   `Total_merged.chr2_1-5Mb.vcf.gz`.

### PHASE 3 — 실습3 (surject / DeepVariant)

1. **surject → GRCh38 BAM** (`surject`, vg 1.74.1)
   GAM을 `OUR.full.gbz`의 GRCh38 경로로 투영(`vg surject`) → 좌표를 chr2 로
   reheader → BAM + flagstat.
2. **pangenome-aware DeepVariant** (`output`, `joint`)
   판지놈(`OUR.gbz`)을 채널로 SNV·INDEL 정밀 호출. **공유메모리를 쓰지 않는 방식**
   (강사 수정본): `run_pangenome_aware_deepvariant` 래퍼 대신 내부 3단계
   (`make_examples_pangenome_aware_dv` → `call_variants` → `postprocess_variants`)를
   직접 호출 → 여러 사용자가 공유하는 `/dev/shm` 고정이름 충돌(RuntimeError: File
   exists)이 원천적으로 없음. 마지막에 `glnexus_cli`로 gVCF들을 공동 genotyping →
   `OUR.pgdv.GLnexus.chr2_1-5Mb.vcf.gz`.

---

## 3. 검증표 — 강사 정답과 로컬 대조 (실습1)

강사 원본 스크립트를 이 패키지 형태(상대경로)로 로컬 실행해 강사 정답 파일과 대조:

**변이 타입 분류 (01_type_split)**

| 항목 | 강사 정답 | 로컬 재현 |
|---|---|---|
| SNVs_only | 16,149 | 16,149 |
| non_SNVs (SNP234·INDEL3263·MNP453·OTHER226) | 3,728 | 3,728 |
| SVs (INDEL388·MNP34·OTHER87, ≥50bp) | 415 | 415 |

**집단 특이 변이 (02_our_population_spec_var, control=CHM13)**

| 항목 | 강사 정답 | 로컬 재현 |
|---|---|---|
| SNVs_only_spec | 10,430 | 10,430 |
| non_SNVs_spec (SNP95·INDEL1803·MNP216·OTHER69) | 2,047 | 2,047 |
| SVs_spec (INDEL185·MNP7·OTHER33) | 202 | 202 |

개인 특이(03_individual_spec_var)도 sample01~04 각각 생성됨.

**실습 2·3 대조용 기준값** (강사 정답 — 서버에서 재현되면 이 값이 나와야 함):
- HG00438 giraffe aligned **805,888** / surject mapped **804,384 (65.36%)**

> 실습 2·3(vg·DeepVariant)은 Linux x86_64 전용이라 arm64 Mac 로컬 재현은 불가.
> 위 기준값으로 서버 실행 결과를 대조하세요.

---

## 4. 산출물 위치 (kogo_run/ 아래)

```
kogo_run/
├── 02_pangenome_growth_curve/  histgrowth.*.tsv, OUR_*_growth_curve.png
├── 03_variant_analysis/        01_type_split/, 02_our_population_spec_var/,
│                                03_individual_spec_var/  (+ loci_count.txt)
├── 04_vg_sv_genotyping/        01_sample/, 02_SR_mapping/, 03_SV_call/
│                                 └ Total_merged.chr2_1-5Mb.vcf.gz
└── 05_deepvariant/             surject/, output/{SAMPLE}.pgdv.vcf.gz,
                                  joint/OUR.pgdv.GLnexus.chr2_1-5Mb.vcf.gz
```

---

## 5. 문제 해결

- **`conda activate kogo` 실패** → `bash 00_setup_env.sh` 먼저. mamba/conda 자체가
  없으면 동봉된 `Miniforge3-Linux-x86_64.sh`로 설치.
- **growth curve `[WARN]`** → panacus 버전에 따라 `-O` 관련 크래시가 날 수 있음.
  스크립트는 이 단계 실패가 변이 분석을 막지 않도록 격리해 두었으니 나머지는 정상 진행.
- **실습3 DeepVariant** → 이 패키지는 공유메모리 미사용 방식이라 `/dev/shm`
  `RuntimeError: File exists` 충돌이 발생하지 않음. `apptainer`가 PATH에 있어야 함.
- **vg/kmc "command not found"** → tools/ 폴더가 ROOT 아래 그대로 있는지 확인.
  마스터 스크립트가 `tools/vg167_kmc324/bin`, `tools/vg174_kmc324/bin`을 자동 참조.
