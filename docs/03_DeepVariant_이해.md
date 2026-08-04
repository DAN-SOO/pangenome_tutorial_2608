# DeepVariant 이해하기 — 딥러닝 변이 호출기 + 판지놈 버전

> 실습 3에서 쓴 **pangenome-aware DeepVariant**가 무엇인지, 원조 DeepVariant와 어떻게
> 다른지, 그리고 **논문 어디를 보면 이해가 되는지**까지 정리했습니다.
> 참고: Poplin et al. (2018) *A universal SNP and small-indel variant caller using deep
> neural networks*, Nature Biotechnology 36:983 (원조 DeepVariant) / Asri et al. (2025)
> *Pangenome-aware DeepVariant*, bioRxiv 2025.06.05.657102 (실습에서 쓴 버전).

---

## 1. 변이 호출(variant calling)이란, 그리고 왜 어려운가

**변이 호출** = "이 사람의 read를 참조에 맞춰봤더니, 참조와 다른 자리가 있다. 이게 진짜
변이(SNV/INDEL)인가, 아니면 시퀀싱·정렬 오류인가?"를 판정하는 것.

어려운 이유: read에는 **에러**(시퀀싱 오류, 정렬 실수)가 섞여 있어서, 참조와 다른
자리가 **진짜 변이인지 노이즈인지** 구분이 애매합니다. 기존 도구(GATK 등)는 통계 모델과
수많은 수작업 규칙(hand-crafted filter)으로 이걸 판정했습니다.

---

## 2. 원조 DeepVariant (Poplin 2018) — "변이 호출을 이미지 분류로 바꿨다"

**핵심 아이디어 (한 문장):** 변이 후보 자리 주변의 read 정렬을 **그림(pileup image)으로
그린 뒤, 이미지 분류 CNN**으로 "이 자리는 0/0, 0/1, 1/1 중 무엇인가"를 맞힌다.

**3단계 워크플로우 (실습 스크립트의 3개 단계와 정확히 일치):**

| 단계 | 도구(실습) | 하는 일 |
|---|---|---|
| ① make_examples | `make_examples...` | 변이 후보 자리마다 **pileup image** 생성 |
| ② call_variants | `call_variants` | CNN이 각 이미지의 **유전형 확률** 예측 |
| ③ postprocess | `postprocess_variants` | 예측을 모아 **VCF/gVCF**로 출력 |

**pileup image가 뭔가 (가장 중요한 개념):** 한 후보 자리를 중심으로, 그 자리에 걸친
read들을 **가로=유전체 위치, 세로=쌓인 read**로 늘어놓은 그림입니다. 각 픽셀의 색/채널이
"염기 종류, base quality, mapping quality, 가닥 방향, 참조와 일치 여부" 같은 정보를
인코딩합니다. 사람이 IGV로 정렬을 눈으로 보고 "여긴 진짜 변이 같다"고 판단하는 걸,
**CNN이 이미지로 학습**해서 하는 셈입니다.

**왜 잘 되나:** 사람이 규칙을 일일이 안 짜도, CNN이 데이터에서 "진짜 변이의 시각적
패턴"을 학습합니다. 그래서 **플랫폼(Illumina/PacBio 등)·시퀀싱 방식이 바뀌어도 재학습만
하면 되는 "universal" 호출기**가 됩니다. 2016 FDA precisionFDA Truth Challenge에서
SNP 정확도 1위를 했고, 논문 기준 차선책 대비 오류를 크게 줄였습니다.

---

## 3. Pangenome-aware DeepVariant (Asri 2025) — 실습에서 쓴 버전

**무엇이 달라졌나 (핵심):** pileup image에 read 뿐 아니라 **판지놈 하플로타입(haplotype)
정렬도 함께 그려 넣습니다.** 즉 CNN이 보는 그림에 **"이 집단에는 이런 서열이 실제로
존재한다"는 판지놈의 사전지식(prior)**이 추가됩니다.

**왜 도움이 되나:** 애매한 자리에서, "내 read가 참조와 다르다"만으로는 노이즈인지
변이인지 헷갈립니다. 그런데 **판지놈에 그 대체 서열이 이미 하플로타입으로 존재**한다면,
"이건 실제로 인구집단에 있는 진짜 변이"라는 강한 증거가 됩니다. 반대로 판지놈 어디에도
없으면 노이즈일 가능성이 큽니다. → **참조 편향(reference bias)을 줄이고 정확도를 올림.**

**성능 (논문 수치):** 모든 시퀀싱 플랫폼·매퍼 설정에서 **선형 참조 기반 DeepVariant보다
오류를 최대 25.5% 감소.** Element read에서는 기존 방법 대비 23.6% 더 정확.

**실습과 연결되는 실무 개념:**
- **판지놈은 read가 매핑된 선형 참조(GRCh38)를 포함해야 한다** — pileup image를 만들 때
  하플로타입 정렬을 판지놈에서 뽑아야 하기 때문. (실습에서 `OUR.gbz`를 채널로 주고
  GRCh38 BAM을 입력으로 준 이유)
- **personalized pangenome(개인화 판지놈)** — 전체 판지놈은 너무 커서 pileup image에 다
  못 넣습니다. 그래서 **그 샘플에 관련된 서열만 subsample한 맞춤 판지놈**을 씁니다.
  이게 실습 2의 `vg haplotypes`로 만든 `_sampled.gbz`와 같은 개념 — 실습 2·3이 이렇게
  연결됩니다.
- **공유메모리 이슈(실습에서 겪은 것)**: 원래 래퍼는 판지놈을 `/dev/shm` 공유메모리에
  올려 shard가 공유하는데, 공용 서버에서 이름 충돌이 났습니다. 실습에서는 3단계
  (make_examples→call_variants→postprocess)를 직접 호출해 공유메모리를 안 쓰는 방식으로
  우회했습니다. → toy 데이터라 성능 손해 없음.

---

## 4. 논문 어디를 봐야 하는가 (추천)

### ★ 1순위 — 원조 DeepVariant 논문 **Figure 1** (Poplin 2018)

**어디:** Poplin et al. (2018) Nat Biotechnol 36:983 — **Figure 1** (1~2페이지).
(원문 유료지만 bioRxiv 프리프린트 092890은 오픈: biorxiv.org/content/10.1101/092890)

**왜:** **pileup image → CNN → 유전형**의 전체 아이디어가 이 그림 하나에 그려져 있습니다.
- 왼쪽: 한 후보 자리의 read 정렬이 **어떻게 이미지(채널 쌓기)로 바뀌는지**
- 가운데: 그 이미지를 받는 **CNN(Inception 계열) 구조**
- 오른쪽: 출력이 **0/0, 0/1, 1/1 세 유전형의 확률**
- **연결:** 실습 스크립트의 `make_examples`(이미지) → `call_variants`(CNN) →
  `postprocess`(VCF) 3단계가 이 그림의 왼→가운데→오른쪽과 1:1 대응.

**함께 볼 것:** 논문 앞부분 "pileup image" 설명 문단 — 각 채널이 무슨 정보를
인코딩하는지(염기, base quality, mapping quality, strand) 한 문단만 읽으면 충분.

### ★ 2순위 — Pangenome-aware DeepVariant **Figure 1 + Supplementary Figure 1** (Asri 2025)

**어디:** Asri et al. (2025) bioRxiv 2025.06.05.657102 (오픈액세스, PMC12157594) —
**Figure 1**(전체 개요)과 **Supplementary Figure 1**(pileup image에 haplotype 채널이
어떻게 추가되는지).

**왜:** 원조와 **뭐가 추가됐는지**가 핵심인데, 그게 이 그림에 있습니다 — read pileup
**위에 판지놈 haplotype pileup이 함께 쌓이는** 구조. 원조 Fig.1과 나란히 보면
"아, 판지놈 채널이 하나 더 붙은 거구나"가 바로 보입니다.

**함께 볼 것:** Abstract + Methods의 *"Creating pileup images augmented with pangenome"*
절 — personalized pangenome로 subsample하는 이유(전체는 이미지에 안 들어감)가 나옵니다.
실습 2의 맞춤 그래프와 직접 연결됩니다.

### ★ 3순위 — DeepVariant GitHub 케이스 스터디 (실무용)

**어디:** github.com/google/deepvariant — `docs/pangenome-aware-wgs-*-case-study.md`.

**왜:** 논문이 아니라 **실행 레시피**입니다. 실습에서 쓴 옵션
(`--make_examples_extra_args`, `--pangenome`, shard 나누기 등)의 실제 사용 예가 있어,
스크립트를 손볼 때 참조하기 좋습니다.

---

## 5. 한 줄 요약

- **원조 DeepVariant** = 변이 호출을 **pileup image + CNN 이미지 분류**로 바꾼 도구
  (make_examples→call_variants→postprocess 3단계). → **Poplin 2018 Fig.1** 먼저.
- **Pangenome-aware DeepVariant** = 그 pileup image에 **판지놈 하플로타입을 채널로 추가**
  해 참조 편향을 줄이고 정확도를 최대 25.5% 올린 버전. → **Asri 2025 Fig.1** 로 차이 확인.
- **딱 하나 본다면: Poplin 2018 Figure 1** — DeepVariant의 핵심 아이디어(정렬→이미지→
  CNN→유전형)가 한 그림에 다 있고, 실습 3단계 스크립트와 정확히 대응됩니다.

---

## 6. 참고 문헌

- Poplin R, et al. (2018). *A universal SNP and small-indel variant caller using deep
  neural networks.* Nature Biotechnology 36:983–987. doi:10.1038/nbt.4235
  (프리프린트 bioRxiv 092890).
- Asri M, et al. (2025). *Pangenome-aware DeepVariant.* bioRxiv 2025.06.05.657102.
  doi:10.1101/2025.06.05.657102 (PMC12157594).
- DeepVariant GitHub: github.com/google/deepvariant (pangenome-aware case studies).
