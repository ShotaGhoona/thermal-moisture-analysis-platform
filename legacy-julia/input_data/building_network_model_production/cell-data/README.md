# Cell Data (Production用)

production用のセルデータファイル

## ファイル一覧

| ファイル名 | 説明 | 材料構成 | 総厚 |
|-----------|------|---------|------|
| p0_rc_single.csv | P0: RC単層 | concrete_goran | 150mm |
| p1_rc_inner_insulation.csv | P1: RC+内断熱 | RC(150) + GW(100) | 250mm |
| p2_rc_outer_insulation.csv | P2: RC+外断熱 | GW(100) + RC(150) | 250mm |
| p3_rc_inner_insulation_hygroscopic.csv | P3: RC+内断熱+吸放湿 | RC + GW + PB + 和紙 | 262.5mm |
| p4_mud_wall.csv | P4: 土壁 | mud_wall | 70mm |

## 材料略称

- RC: concrete_goran (コンクリート)
- GW: glass_wool_16K (グラスウール16K)
- PB: plasterboard (石膏ボード)
- 和紙: paper_washi

## 使用方法

wall-conditionのCSVファイルで、Type列にファイル名（拡張子なし）を指定：

```csv
Type
p1_rc_inner_insulation
```

## パス優先順位

wall.jlは以下の順序でcell_dataを検索します：

1. `./input_data/building_network_model_production/cell-data/` (優先)
2. `../input_data/building_network_model_production/cell-data/`
3. `./input_data/building_network_model/cell_data/` (従来)
4. `../input_data/building_network_model/cell_data/`

production用のファイルが優先的に読み込まれます。
