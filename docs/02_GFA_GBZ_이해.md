# GFA · rGFA · GBZ 이해하기 — 판지놈 그래프 파일 포맷

> 판지놈 그래프가 파일로 어떻게 저장되는지 정리한 자료입니다.
> 참고: Li, Feng, Chu (2020) *The design and construction of reference pangenome
> graphs with minigraph*, Genome Biology 21:265 / GFA-spec
> (github.com/GFA-spec/GFA-spec). GFA가 뭔지, rGFA·GBZ와 뭐가 다른지, 실무에서
> 알아야 할 포인트만 추렸습니다.

---

## 1. 왜 그래프를 텍스트 파일로 저장하나

판지놈은 "노드(서열 조각) + 엣지(연결) + 경로(각 사람이 지나간 길)"로 이루어진
그래프입니다. 이걸 파일 하나로 주고받으려면 표준 포맷이 필요합니다. 그게 **GFA
(Graphical Fragment Assembly)** 입니다. 원래는 유전체 *조립(assembly)* 결과를
표현하려고 만들어졌지만, 지금은 판지놈 그래프의 사실상 표준 교환 포맷입니다.

핵심: **GFA는 사람이 읽을 수 있는 탭 구분 텍스트**입니다. 한 줄 = 한 레코드,
줄 맨 앞 한 글자가 **레코드 종류**를 정합니다.

---

## 2. GFA 라인 타입 — 줄 첫 글자만 보면 된다

| 첫 글자 | 이름 | 담는 것 | 예시(탭 구분) |
|---|---|---|---|
| `H` | Header | 버전 등 메타데이터 | `H  VN:Z:1.1` |
| `S` | **Segment** | **노드 = 서열 조각** | `S  s1  ACGTACGT` |
| `L` | **Link** | **엣지 = 두 노드의 연결(방향 포함)** | `L  s1  +  s2  +  0M` |
| `P` | Path | 한 경로를 세그먼트 나열로 (구형) | `P  sample1  s1+,s2+,s4+  *` |
| `W` | **Walk** | 한 하플로타입의 경로 (신형, GFA 1.1) | `W  sample1  0  chr2  0  5000000  >s1>s2>s4` |

**꼭 알 포인트:**
- **`S`(노드)와 `L`(엣지)가 그래프의 뼈대**입니다. 나머지는 "누가 이 그래프를 어떻게
  지나가는가"(경로)를 기록합니다.
- **방향(orientation)이 중요합니다.** `+`는 정방향, `-`는 역상보(reverse complement).
  DNA는 양쪽 가닥이 있어서 같은 노드를 반대 방향으로 지날 수 있습니다.
  Walk에서는 `>`(정방향), `<`(역방향)로 표기합니다 (`>s1<s2`).
- **`L` 라인의 `0M`** 같은 CIGAR는 두 세그먼트가 겹치는 정도입니다. 판지놈 그래프는
  보통 겹침 없이 `0M`(blunt) 입니다.

**P-line vs W-line (실무에서 자주 헷갈림):**
- `P`(Path)는 구형. 경로 이름이 자유 문자열이라 "어느 샘플의 어느 염색체 어느 하플로타입"
  인지 규칙이 약합니다.
- `W`(Walk)는 GFA 1.1에서 도입. **샘플명·하플로타입번호·염색체·시작·끝**을 컬럼으로
  분리해 기록 → 파싱이 명확합니다. **이번 실습 `OUR.gfa`는 W-line 기반**이라, 아래처럼
  샘플별 경로를 뽑을 수 있었습니다:
  ```bash
  awk -F'\t' '$1=="W"{print $2}' OUR.gfa   # W-line의 샘플명 컬럼
  ```
  (실습 growth curve에서 참조 GRCh38/CHM13 경로를 걸러낼 때 쓴 방법)

---

## 3. rGFA — "참조 좌표를 보존하는" GFA (minigraph)

일반 GFA의 한계: **좌표가 불안정**합니다. GFA는 (segId, offset)이라는 *segment
coordinate*를 쓰는데, 세그먼트를 둘로 쪼개면 서열은 그대로여도 좌표가 바뀝니다.
그러면 "GRCh38의 chr2:1,500,000" 같은 **기존 선형 좌표와 연결이 끊깁니다.**

minigraph는 이를 해결하려고 **rGFA(reference GFA)** 를 도입했습니다. 핵심은 각
세그먼트에 **"이 조각이 원래 어느 유전체의 어디서 왔는가"** 를 태그로 붙이는 것입니다:

| 태그 | 의미 |
|---|---|
| `SN` | 이 노드가 유래한 **원본 서열 이름** (예: `chr2`, `GRCh38`) |
| `SO` | 그 원본 서열에서의 **offset(위치)** |
| `SR` | **rank**: `0`이면 선형 참조 위, `>0`이면 비참조(다른 assembly에서 추가된 부분) |

예:
```
S  s1  ACGT...  SN:Z:chr2  SO:i:0     SR:i:0     ← 참조(GRCh38 chr2) 위
S  s2  TTGG...  SN:Z:chr2  SO:i:2000  SR:i:1     ← 참조엔 없던, 추가된 변이 서열
```

**이게 왜 중요한가 (핵심 개념):**
- **stable coordinate(안정 좌표)**: rGFA는 `SN`/`SO` 덕분에 그래프를 여전히
  "GRCh38 chr2의 몇 번 위치" 라는 **기존 선형 좌표로 읽을 수 있습니다.** 그래프를 쪼개고
  합쳐도 이 좌표는 안 변합니다.
- 그래서 minigraph 판지놈은 **선형 참조의 자연스러운 확장**으로 취급됩니다 — 기존
  GRCh38 기반 annotation(유전자 위치 등)을 그대로 얹을 수 있습니다.
- `SR` 태그로 **"참조에 원래 있던 서열"과 "새 assembly가 더한 서열(=구조 변이)"** 을
  구분합니다. minigraph는 이 방식으로 **수만 개의 SV를 압축적으로 인코딩**합니다.

**minigraph의 설계 제약 (알아둘 점):**
- rGFA는 **엣지 겹침 금지 + 노드 쌍 사이 다중 엣지 금지** — 구현 단순화·모호성 회피용.
- minigraph 그래프는 기본적으로 **큰 변이(SV, ~100bp 이상)** 를 담고, **개별
  하플로타입 경로나 SNP 수준 정보는 담지 않습니다.** (그건 minigraph-cactus나 PGGB가
  더 조밀하게 만듭니다.) 이번 실습 그래프는 W-line으로 하플로타입까지 담긴 형태라
  minigraph보다 더 조밀한 계열입니다.
- **참조·입력 순서에 따라 편향(bias)** 이 생길 수 있습니다 — 어떤 유전체를 primary
  참조로 놓느냐, 어떤 순서로 넣느냐가 결과 그래프에 영향을 줍니다.

**segment coordinate vs stable coordinate 요약:**
- segment 좌표 = `(노드ID, 노드내offset)` — 그래프 변형에 취약.
- stable 좌표 = `(SN, SO)` = 기존 선형 참조 위치 — 안정적, 기존 도구와 호환.
- 정렬 결과 포맷 **GAF**도 이 두 좌표 중 하나로 쓸 수 있습니다(minigraph는 둘 다 지원).

---

## 4. GBZ — 대용량 판지놈을 위한 압축 인덱스 (vg / giraffe)

GFA는 사람이 읽기엔 좋지만 **텍스트라 크고 느립니다.** 전체 인간 판지놈(수백
하플로타입)을 GFA로 두면 수백 GB이고, 매핑 때마다 파싱하면 감당이 안 됩니다.

**GBZ**는 그래프 + 하플로타입 경로를 **압축된 이진 인덱스**로 저장한 포맷입니다
(vg / giraffe 생태계에서 사용). 핵심 아이디어:
- 하플로타입들이 그래프에서 **비슷한 경로를 공유**한다는 점을 이용해(GBWT 기반),
  수천 개 하플로타입 경로를 매우 작게 압축.
- 매핑 도구(`vg giraffe`)가 **바로 로드해서 쓸 수 있는** 인덱스 형태.

**실무 포인트:**
- **GFA ↔ GBZ 변환**: `vg convert` / `vg gbwt` 계열로 오갑니다. 사람이 들여다보거나
  panacus 같은 도구에 넣을 땐 GFA, 매핑·변이호출엔 GBZ.
- 이번 실습 파일들의 역할 분담이 정확히 이걸 보여줍니다:
  | 파일 | 포맷 | 용도 |
  |---|---|---|
  | `OUR.gfa.gz` | GFA(텍스트, gzip) | **growth curve**(panacus)가 읽음 — 사람·분석용 |
  | `OUR.gbz` | GBZ(이진 인덱스) | **vg giraffe 매핑 / vg call** — 도구가 바로 로드 |
  | `OUR.full.gbz` | GBZ | surject 시 **참조(GRCh38) 경로** 추출용 |
  | `OUR.hapl` | 하플로타입 패널 | 새 샘플 맞춤 그래프 생성 입력 |
- **왜 두 벌(gfa + gbz)을 다 주나?** 포맷마다 잘하는 게 달라서입니다. 분석·시각화는
  GFA, 대용량 연산은 GBZ. 같은 그래프의 다른 표현일 뿐입니다.

---

## 5. 한 장 요약

```
GFA   = 판지놈 그래프의 표준 텍스트 포맷 (S=노드, L=엣지, W/P=경로)
         └ 사람이 읽음, 분석·시각화용, 크다
rGFA  = GFA + 각 노드에 출신 태그(SN=원본이름, SO=위치, SR=참조여부)
         └ minigraph가 생성, "선형 참조 좌표 보존"(stable coordinate)이 핵심 장점
         └ SR>0 = 참조에 없던 서열 = 구조 변이(SV)를 압축 인코딩
GBZ   = 그래프+하플로타입을 압축한 이진 인덱스 (vg/giraffe)
         └ 대용량 판지놈을 빠르게 매핑, 도구가 바로 로드, 작다
```

**실무에서 꼭 기억할 3가지:**
1. **줄 첫 글자로 GFA를 읽어라** — `S`=노드, `L`=엣지, `W`=하플로타입 경로.
   방향(`+`/`-`, `>`/`<`)이 의미를 바꾼다.
2. **rGFA의 SN/SO/SR = 좌표 안정성** — 그래프여도 "GRCh38 어디"로 말할 수 있게 해준다.
   `SR:i:0`은 참조, `>0`은 새로 추가된(변이) 서열.
3. **GFA는 읽기용, GBZ는 연산용** — 같은 그래프의 두 표현. 분석엔 GFA, 매핑엔 GBZ.

---

## 6. 참고 문헌

- Li H, Feng X, Chu C (2020). *The design and construction of reference pangenome
  graphs with minigraph.* Genome Biology 21:265. doi:10.1186/s13059-020-02168-z
  — rGFA 포맷과 SN/SO/SR 태그, stable/segment coordinate, incremental 그래프
  구축을 제안한 원 논문.
- GFA-spec (github.com/GFA-spec/GFA-spec) — GFA 1.0/1.1 라인 타입(H/S/L/P/W 등)의
  공식 명세.
- 관련: Hickey et al. (2024) Minigraph-Cactus, Garrison et al. (2024) PGGB —
  더 조밀한(base-level, 하플로타입 포함) 판지놈 그래프 구축 도구.
