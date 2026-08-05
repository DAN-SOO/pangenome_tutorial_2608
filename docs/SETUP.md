# 설치 및 실행 절차 (처음 한 번)

원하는 디렉터리에 clone해서 쓰는 것을 기준으로 정리했습니다. **데이터는 공유(읽기 전용),
코드와 산출물은 각자 자기 디렉터리**입니다.

---

## 0. 미리 정할 것 세 가지

| 이름 | 뜻 | 예시 |
|---|---|---|
| **CODE** | 이 저장소를 clone할 곳 | `/data1/dansay/tools/pangenome_tutorial_2608` |
| **DATA** | 실습 데이터·툴이 있는 공유 폴더 | `/data1/dansay/test/pangenome_kogo_2026` |
| **WORK** | 산출물이 생길 내 작업 폴더 | `/data1/dansay/run/pangenome_run` |

세 개는 서로 아무 관계가 없어도 됩니다. 어디에 두든 동작합니다.

---

## 1. 원하는 디렉터리에 clone

```bash
# 원하는 위치를 정해서 clone (마지막 인자가 목적지)
git clone https://github.com/DAN-SOO/pangenome_tutorial_2608.git \
    /data1/dansay/tools/pangenome_tutorial_2608
```

이후 편의를 위해 변수로 잡아둡니다:

```bash
export KOGO_CODE=/data1/dansay/tools/pangenome_tutorial_2608
```

<details>
<summary>clone이 아이디·비밀번호를 물어보거나 <code>gnome-ssh-askpass ... cannot open display</code> 오류가 날 때</summary>

저장소가 private이면 인증을 요구합니다. GUI가 없는 서버에서는 askpass가 실패하므로
터미널 입력으로 바꿔줍니다:

```bash
unset SSH_ASKPASS GIT_ASKPASS
export GIT_TERMINAL_PROMPT=1
git clone https://DAN-SOO@github.com/DAN-SOO/pangenome_tutorial_2608.git "$KOGO_CODE"
# Username: DAN-SOO
# Password: ← GitHub 비밀번호가 아니라 Personal Access Token 을 붙여넣습니다
```

토큰 발급: GitHub → Settings → Developer settings → Personal access tokens →
Fine-grained tokens → 해당 저장소에 **Contents: Read** (push도 하려면 Read and write).

저장소가 Public이면 인증 없이 clone됩니다
(Settings → Danger Zone → Change visibility).
</details>

---

## 2. 공유 데이터 위치 지정

데이터·툴(약 3.5GB)은 저장소에 없습니다. 있는 곳을 알려줍니다:

```bash
export KOGO_DATA=/data1/dansay/test/pangenome_kogo_2026
```

이 폴더 안에 `01_data_prepare/`와 `tools/`가 있어야 합니다
(필요한 파일 전체 목록은 [DATA_MANIFEST.md](DATA_MANIFEST.md)).

매번 입력하지 않으려면 `~/.bashrc`에 넣어두세요:

```bash
cat >> ~/.bashrc <<'EOF'
export KOGO_CODE=/data1/dansay/tools/pangenome_tutorial_2608
export KOGO_DATA=/data1/dansay/test/pangenome_kogo_2026
EOF
source ~/.bashrc
```

---

## 3. conda 환경 만들기 (최초 1회)

환경 위치는 **`/data1/dansay/conda/envs/kogo`로 고정**되어 있습니다. 마스터 스크립트가
이 경로를 자동으로 활성화하므로 **매번 `conda activate` 할 필요가 없습니다.**

```bash
bash "$KOGO_CODE/scripts/00_setup_env.sh"
```

이미 그 환경이 있으면 이 단계는 건너뛰어도 됩니다. 확인:

```bash
ls /data1/dansay/conda/envs/kogo/bin/bcftools    # 있으면 준비된 상태
```

<details>
<summary>다른 위치·다른 환경을 쓰고 싶을 때</summary>

```bash
export KOGO_ENV=/내/경로/envs/kogo      # 경로(prefix)로 지정
export KOGO_ENV=kogo                    # 또는 환경 이름으로
export KOGO_ENV=skip                    # 이미 activate 한 환경을 그대로 쓰기
```

환경을 새로 만들 때도 같은 변수를 씁니다:
`KOGO_ENV=/내/경로/envs/kogo bash "$KOGO_CODE/scripts/00_setup_env.sh"`
</details>

> setup 스크립트는 공용 conda의 패키지 캐시 권한 문제(`Operation not permitted`)를 피해
> 개인 캐시(`<env 상위>/pkgs`)를 자동으로 씁니다. panacus는 0.5.x 버그를 피해 **0.4.1로
> 고정** 설치합니다.

---

## 4. 데이터 배치 확인

```bash
bash "$KOGO_CODE/scripts/check_data.sh"
# → 일치 19 / 없음 0 / 불일치 0   이면 준비 완료
```

실습1만 돌린다면 `tools/`와 FASTQ가 "없음"으로 나와도 괜찮습니다.

---

## 5. 내 작업 폴더에서 실행

**산출물은 실행한 디렉터리의 `kogo_run/`에 생깁니다.** 그래서 자기 폴더로 이동해서 실행합니다:

```bash
mkdir -p /data1/dansay/run/pangenome_run
cd /data1/dansay/run/pangenome_run

bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" all
```

conda 환경은 스크립트가 알아서 활성화합니다. 시작 로그의 `[INFO] CONDA =` 줄로 확인하세요.

단계별로 나눠 돌릴 수도 있습니다:

```bash
bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" 1   # 실습1 (growth curve + 변이 분석)
bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" 2   # 실습2 (KMC + vg giraffe SV genotyping)
bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" 3   # 실습3 (surject + DeepVariant)
```

산출물 위치를 따로 지정하려면:

```bash
KOGO_OUT=/scratch/$USER/kogo_run bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" all
# 또는 두 번째 인자로
bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" all /scratch/$USER/kogo_run
```

### 시작할 때 이 세 줄을 확인하세요

```
[INFO] CONDA = /data1/dansay/conda/envs/kogo
[INFO] CODE  = /data1/dansay/tools/pangenome_tutorial_2608/scripts
[INFO] DATA  = /data1/dansay/test/pangenome_kogo_2026        (읽기 전용)
[INFO] WORK  = /data1/dansay/run/pangenome_run/kogo_run      (산출물)
```

CONDA와 WORK가 의도한 곳인지만 보면 됩니다. 공유 데이터 폴더 안이면 경고가 나옵니다.

---

## 6. SLURM으로 돌리기

```bash
cat > kogo_day2.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=kogo_day2
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G
#SBATCH --output=kogo_day2.%j.log

source /data1/software/anaconda3/etc/profile.d/conda.sh
export CONDA_PKGS_DIRS=$HOME/conda/pkgs        # 공용 캐시 쓰기 불가 대비
conda activate kogo

export KOGO_CODE=/data1/dansay/tools/pangenome_tutorial_2608
export KOGO_DATA=/data1/dansay/test/pangenome_kogo_2026

cd /data1/dansay/run/pangenome_run             # 산출물이 여기 생김
bash "$KOGO_CODE/scripts/run_all_kogo_day2.sh" all
EOF

sbatch kogo_day2.sbatch
squeue -u $USER
```

---

## 7. 결과 확인

```bash
cd /data1/dansay/run/pangenome_run/kogo_run

# 실습1 — 변이 분류 / 집단 특이
cat 03_variant_analysis/01_type_split/loci_count.txt
cat 03_variant_analysis/02_our_population_spec_var/loci_count.txt

# 실습2 — SV genotyping
bcftools index -n 04_vg_sv_genotyping/03_SV_call/Total_merged.chr2_1-5Mb.vcf.gz

# 실습3 — DeepVariant + GLnexus
zcat 05_deepvariant/joint/OUR.pgdv.GLnexus.chr2_1-5Mb.vcf.gz | grep -vc '^#'
```

기대값과 해석은 [06_주요결과_정리.md](06_주요결과_정리.md)의 검증표를 보세요
(SNV 16,149 / non-SNV 3,728 / SV 415, 집단특이 10,430 / 2,047 / 202 등).

---

## 여러 사람이 함께 쓸 때

- **DATA는 한 벌만** 두고 공유하면 됩니다(읽기 전용 마운트도 가능). 스크립트는 그 폴더에
  아무것도 쓰지 않습니다 — DeepVariant용 참조 색인(`.fai`)도 각자 작업 폴더에서 만듭니다.
- **CODE는 각자 clone**하거나 공용 위치 하나를 `$KOGO_CODE`로 함께 가리켜도 됩니다.
- **CONDA는 공유하거나 각자** 만들 수 있습니다 (`$KOGO_ENV`).
- **WORK만 각자 다르게** 두면 동시에 돌려도 서로 간섭하지 않습니다.

### 권한 — 개인 폴더 아래를 공유할 때

기본 경로(`/data1/dansay/...`)는 개인 홈 아래이므로, 다른 사람이 쓰려면 **경로를 통과할
권한**(디렉터리의 `x` 비트 = traverse)이 각 단계마다 필요합니다. 하위가 아무리 열려
있어도 중간 한 곳이 막히면 접근할 수 없습니다.

먼저 실제 상태를 확인하세요 — 어느 단계에서 막히는지 한눈에 보입니다:

```bash
namei -l /data1/dansay/conda/envs/kogo
namei -l /data1/dansay/test/pangenome_kogo_2026
id                                   # 상대방이 같은 그룹인지 확인
```

읽는 법 — 예를 들어 `drwxr-x--- dansay wonlab dansay` 는:

| 필드 | 값 | 의미 |
|---|---|---|
| owner | `rwx` | 소유자(dansay)는 전부 가능 |
| **group** | `r-x` | **같은 그룹(wonlab)은 목록·통과 가능** |
| other | `---` | 그룹 밖 사용자는 통과 불가 |

즉 **같은 그룹이면 추가 조치가 필요 없습니다.** 그룹이 다른 사람에게 열어야 할 때만
통과 권한을 주되, 목록 노출은 막는 쪽이 안전합니다:

```bash
chmod o+x /data1/dansay          # 통과만 허용 (내용 목록은 여전히 안 보임)
```

`o+rx`가 아니라 `o+x`만 주면 그 폴더를 `ls`로 훑어볼 수는 없고, 정확한 하위 경로를
아는 경우에만 접근합니다. 하위 폴더(`conda/`, `test/`)가 이미 `drwxrwxr-x`라면 그쪽은
그대로 두면 됩니다.

**권한을 건드리지 않고 쓰는 방법도 있습니다.** 각자 자기 환경을 쓰면 됩니다:

```bash
export KOGO_ENV=/내/경로/envs/kogo    # 각자 만든 환경
export KOGO_ENV=skip                  # 이미 activate 한 환경 그대로
```

> **정기적으로 여러 사람이 쓸 계획이라면** 개인 홈 아래 대신 공용 위치
> (예: `/data1/share/kogo`)로 데이터·환경을 옮기는 것을 권합니다. 개인 계정 정리나
> 쿼터 문제에 함께 영향받지 않고, 권한 관리 부담도 줄어듭니다. 스크립트는
> `KOGO_DATA`/`KOGO_ENV`로 분리돼 있으므로 기본값만 바꾸면 됩니다.

---

## 자주 걸리는 문제

| 증상 | 원인·해결 |
|---|---|
| `gnome-ssh-askpass ... cannot open display` | private 저장소 인증 프롬프트 → 위 1절 `<details>` 참조 |
| `ERROR: 필수 입력이 없습니다` | `KOGO_DATA`가 안 잡혔거나 경로가 틀림 → `echo $KOGO_DATA` 확인 |
| `ERROR: 산출물 폴더를 만들 수 없습니다` | 쓰기 권한 없는 곳에서 실행 → 개인 폴더로 `cd` 또는 `KOGO_OUT` 지정 |
| growth curve TSV가 0바이트 | panacus 0.5.x 버그 → `mamba install -n kogo panacus=0.4.1` |
| `apptainer/singularity 를 찾을 수 없습니다` | 스크립트가 둘 중 있는 것을 자동으로 씁니다. 둘 다 없으면 모듈 로드(`module load singularity`) 또는 경로 지정: `export KOGO_CONTAINER=/usr/local/bin/singularity` |
| `bcftools plugin "counts" was not found` | 플러그인 없는 bcftools(예 `/usr/local/bin`)가 쓰인 경우. 스크립트가 `BCFTOOLS_PLUGINS`를 자동 설정하고, 그래도 안 되면 동일 출력을 내는 대체 집계로 넘어갑니다(`[WARN] ... 대체 집계를 사용합니다`). 근본 해결은 conda 환경의 bcftools를 쓰는 것: `which bcftools` 가 `$KOGO_ENV/bin/bcftools` 인지 확인 |
| conda `Operation not permitted` | 공용 pkgs 캐시 쓰기 불가 → `export CONDA_PKGS_DIRS=$HOME/conda/pkgs` |
| 집단특이 결과가 0 (macOS) | BSD grep은 `-P` 미지원 → Linux에서는 정상, macOS면 `grep -P`를 `-E`로 치환 |
