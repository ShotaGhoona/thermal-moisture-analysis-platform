# Room Condition

室条件の設定ファイル一覧

## ファイル一覧

| ファイル名 | 説明 | 状態 |
|-----------|------|------|
| 01-base-model.csv | ベースモデル（標準室） | 完了 |

## パターン比較表

| 変数 | 単位 | P0 (Base) | P1 | P2 | P3 | P4 |
|-----|------|-----------|----|----|----|----|
| num | - | 2 | TODO | TODO | TODO | TODO |
| name | - | indoor | TODO | TODO | TODO | TODO |
| vol | m³ | 62.5 (5×5×2.5) | TODO | TODO | TODO | TODO |
| temp (初期) | ℃ | 25.0 | TODO | TODO | TODO | TODO |
| rh (初期) | % | 50.0 | TODO | TODO | TODO | TODO |
| Hight | m | 2.5 | TODO | TODO | TODO | TODO |
| Qs | W | 0 | TODO | TODO | TODO | TODO |
| Js | kg/s | 0 | TODO | TODO | TODO | TODO |
| AC | - | OFF | TODO | TODO | TODO | TODO |

## 備考

- num=1 は outdoor（外気）として固定
- num=2 以降が解析対象室
- 室内条件は固定し、壁と開口の違いが周波数応答の違いになるよう設計
