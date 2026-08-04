# results/ — 검증용 요약 산출물

전체 파이프라인 산출물은 용량 때문에 커밋하지 않고, **강사 정답과 대조한 요약 파일만**
포함했습니다. 해석은 [../docs/06_주요결과_정리.md](../docs/06_주요결과_정리.md) 참조.

| 파일 | 내용 |
|---|---|
| `loci_count.01_type_split.txt` | 변이 타입 분류 (SNV 16,149 / non-SNV 3,728 / SV 415) |
| `loci_count.02_population_specific.txt` | 집단 특이 변이 (SNV 10,430 / SV 202 / non-SNV 2,047) |
| `loci_count.03_individual_specific.txt` | 개인 특이 변이 (샘플별 3타입) |
| `histgrowth.OUR.chr2_1-5Mb.tsv` | growth curve 원시 수치 (5개 quorum 열) |
| `HG00438.gam.stats.txt`, `HG02257.gam.stats.txt` | vg giraffe 그래프 매핑 통계 |
| `HG00438.flagstat.tsv`, `HG02257.flagstat.tsv` | surject 후 BAM 매핑률 |

`loci_count.01_type_split.txt` 와 `loci_count.03_individual_specific.txt` 는 서버 실행
결과에서 옮겨 적은 요약이며, 나머지는 산출 파일 원본입니다.
