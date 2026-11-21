# Parser performance

## Optimization workflow

Measure before changing the parser. Record elapsed time, peak working set, total allocation where available, installer size, expanded bytes, and selected code path. Optimize repeated reads, whole-file buffering, accidental arrays, broad scans, unnecessary extraction, repeated decompression, and repeated parser calls before translating format policy into C#.

Reuse one analysis context per top-level operation. Cache parsed PE layout, archive catalog, MSI database, XML, and decompressed metadata within that operation. Extract selected payloads instead of whole archives when the format permits it.

## Validation

Benchmark small and large representative layouts before and after the change. Do not enforce flaky wall-clock thresholds in CI. Keep deterministic parser limits and watchdogs as correctness constraints. Store full benchmark output in [transient evidence](../workflows/evidence.md) and summarize only the meaningful deltas in the task.
