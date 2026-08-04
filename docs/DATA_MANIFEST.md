# 필요한 데이터·툴 목록 (저장소 미포함)

이 저장소에는 코드·문서만 있습니다. 아래 파일들을 저장소 루트에 같은 경로 구조로
배치해야 실행됩니다 (총 약 3.55 GB). 워크숍에서 배포된 파일을 사용하세요.

## 검증

배치가 올바른지 한 번에 확인:

```bash
bash scripts/check_data.sh
```

- **일치 19 / 없음 0 / 불일치 0** 이면 준비 완료입니다.
- 데이터를 저장소 밖에 두었다면: `KOGO_ROOT=/데이터/경로 bash scripts/check_data.sh`
- 실습1만 돌린다면 `tools/`와 `01_srWGS/` FASTQ는 "없음"으로 나와도 괜찮습니다.

체크섬 원본은 [`DATA_MANIFEST.sha256`](DATA_MANIFEST.sha256) 입니다
(`sha256sum -c` / `shasum -a 256 -c` 형식).

## 전체 목록

| 경로 | 크기(bytes) | SHA-256 |
|---|---|---|
| `01_data_prepare/00_toy_pangenome/GRCh38.chr2_1-5Mb.fa` | 5,050,006 | `3721db4417089544b5b07e0702d7a41ae863f60ee14d0bc67b15130296adb125` |
| `01_data_prepare/00_toy_pangenome/GRCh38.chr2_1-5Mb.fa.fai` | 23 | `563d3f34f8ec98cac5d291ac5016d9ea3b84354de74c9775a59773b869fd2592` |
| `01_data_prepare/00_toy_pangenome/OUR.full.gbz` | 3,249,120 | `ca0b8b18493cf86b6f2d069ca7a92d60ae4749595beef9c7d78eec3f06fbfaee` |
| `01_data_prepare/00_toy_pangenome/OUR.gbz` | 3,179,752 | `c5ff075b162bd9e27e17fae4886699bf48ab059fd0374fcd146ce33cab3034f2` |
| `01_data_prepare/00_toy_pangenome/OUR.gfa.gz` | 3,327,837 | `8009fa1a1149b05775b266f3c934367ac55493f2c30b34fb48e18df73c4b276d` |
| `01_data_prepare/00_toy_pangenome/OUR.hapl` | 2,918,000 | `5f282ab68c9304b5ef7c38846c06a8d77b635d9d71a84bed9d0d631aeae55bcd` |
| `01_data_prepare/00_toy_pangenome/OUR.vcf.gz` | 517,606 | `962427e5da9f956041749ad9c8a2cd96459efa5c8cebcc6d1980b024977770ce` |
| `01_data_prepare/00_toy_pangenome/OUR.vcf.gz.tbi` | 2,526 | `f71bf3a7e2509606017ac92f3c31e1f98e0c8f869f476b026b012423a606a954` |
| `01_data_prepare/01_srWGS/HG00438_1.fq.gz` | 21,921,072 | `7f7a4be079c123d4452b4db510ea47f5c89a05f1ca21f70b1765baa145cd3546` |
| `01_data_prepare/01_srWGS/HG00438_2.fq.gz` | 24,270,418 | `2a88c0a4fc38c60bf03a6f04e7ad472492461f8158a4856d84ac6b065076f412` |
| `01_data_prepare/01_srWGS/HG02257_1.fq.gz` | 22,870,365 | `180ae74d10efa76a3981852bcfbeddd8ac0ae0216b2916f42019dab1a314ab4c` |
| `01_data_prepare/01_srWGS/HG02257_2.fq.gz` | 26,172,517 | `14222054559b975553737dd887699ff318b1a27918d9cce7cb2a2955800b099d` |
| `tools/deepvariant_pangenome_aware_1.8.0.sif` | 3,314,044,928 | `799d1483946a37132010a80fa6bbe6693f35ba0d4e2c9aae4e2870fbbf1a4c7f` |
| `tools/vg167_kmc324/bin/kmc` | 5,867,448 | `89e59edde1e8324493f81f93b310a3fb3f1b1cee9c53460ccec3eb725e8f9abb` |
| `tools/vg167_kmc324/bin/kmc_dump` | 2,270,768 | `fa96c3f64e363dc86de02c4791f7166a9e4a277e789df2543cd9b8c5591cc658` |
| `tools/vg167_kmc324/bin/kmc_tools` | 4,341,216 | `135fc84886fb035f0525ae70435525f2291820ada1ddc30e25e485200f318ee3` |
| `tools/vg167_kmc324/bin/libkmc_core.a` | 9,146,060 | `ca80e3beb63917a1d3776d50ef3818cc6ec667579d1c75007376553ff1de1b32` |
| `tools/vg167_kmc324/bin/vg` | 49,146,128 | `19fc5f95a3dcbb648698df3bb3d0378b9e00080783e6c521085868beb707b672` |
| `tools/vg174_kmc324/bin/vg` | 55,171,704 | `a2d19fccb68829f8c7cad51f0e34c951ea78d06d042460153cd70c99873294ac` |

## 플랫폼 주의

- `tools/vg*/bin/` 바이너리와 `.sif` 컨테이너는 **Linux x86_64 전용**입니다.
  macOS·ARM 환경에서는 실습2·3을 실행할 수 없습니다(실습1은 conda 툴로 가능).
- 툴 바이너리는 공식 배포본에서 직접 받을 수도 있습니다:
  [vg releases](https://github.com/vgteam/vg/releases) (v1.67.0, v1.74.1),
  [KMC 3.2.4](https://github.com/refresh-bio/KMC/releases),
  [DeepVariant](https://github.com/google/deepvariant) pangenome-aware 1.8.0 이미지.
  이 경우 SHA-256은 위 표와 다를 수 있습니다(빌드 차이).
