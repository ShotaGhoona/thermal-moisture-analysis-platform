# Wall Condition

壁条件の設定ファイル一覧

## ファイル一覧

| ファイル名 | 説明 | 状態 |
|-----------|------|------|
| 01-base-model.csv | P0 ベースモデル（単層RC） | 完了 |
| 02-rc-inner-insulation.csv | P1 RC+内断熱 | 完了 |
| 03-rc-outer-insulation.csv | P2 RC+外断熱 | 完了 |
| 04-rc-inner-insulation-hygroscopic.csv | P3 RC+内断熱+吸放湿 | 完了 |
| 05-mud-wall.csv | P4 伝統土壁 | 完了 |

## パターン比較表

| 変数 | 単位 | P0 単層RC | P1 RC+内断熱 | P2 RC+外断熱 | P3 RC+内断熱+吸放湿 | P4 土壁 |
|-----|------|----------|--------------|--------------|-------------------|--------|
| num | - | 1 | 1 | 1 | 1 | 1 |
| IP (外側室) | - | 1 (outdoor) | 1 | 1 | 1 | 1 |
| IM (内側室) | - | 2 (indoor) | 2 | 2 | 2 | 2 |
| Type | - | p0_rc_single | p1_rc_inner_insulation | p2_rc_outer_insulation | p3_rc_inner_insulation_hygroscopic | p4_mud_wall |
| thickness | m | 0.15 | 0.25 | 0.25 | 0.2625 | 0.07 |
| area | m2 | 12.5 | 12.5 | 12.5 | 12.5 | 12.5 |
| ION (傾斜) | 度 | 90 | 90 | 90 | 90 | 90 |
| dir_IP | - | S | S | S | S | S |
| dir_IM | - | N | N | N | N | N |
| alphac_IP | W/m2K | 9 | 9 | 9 | 9 | 9 |
| alphac_IM | W/m2K | 4.9 | 4.9 | 4.9 | 4.9 | 4.9 |
| alphar_IP | W/m2K | 4.4 | 4.4 | 4.4 | 4.4 | 4.4 |
| alphar_IM | W/m2K | 4.4 | 4.4 | 4.4 | 4.4 | 4.4 |

## 構造的特徴

| パターン | 材料構成 (外→内) | 総厚 | 特徴 |
|---------|-----------------|------|------|
| P0 | concrete_goran | 150mm | RC単層・非吸放湿 |
| P1 | concrete_goran → glass_wool_16K | 250mm | 内断熱・断熱材100mm |
| P2 | glass_wool_16K → concrete_goran | 250mm | 外断熱・断熱材100mm |
| P3 | concrete_goran → glass_wool_16K → plasterboard → paper_washi | 262.5mm | 内断熱+吸放湿仕上げ |
| P4 | mud_wall | 70mm | 伝統土壁・高調湿性 |

## cell_data一覧

`input_data/building_network_model/cell_data/` 内の新規ファイル：

| ファイル名 | 材料構成 | セル数 |
|-----------|---------|--------|
| p1_rc_inner_insulation.csv | RC(16) + GW(5) | 21 |
| p2_rc_outer_insulation.csv | GW(5) + RC(16) | 21 |
| p3_rc_inner_insulation_hygroscopic.csv | RC(16) + GW(5) + PB(4) + 和紙(1) | 26 |
| p4_mud_wall.csv | 土壁(8) | 8 |

### 材料略称
- RC: concrete_goran
- GW: glass_wool_16K
- PB: plasterboard
- 和紙: paper_washi

## 使用材料の物性値

| 材料 | 熱伝導率 λ [W/mK] | 密度 ρ [kg/m3] | 比熱 c [J/kgK] |
|-----|------------------|----------------|----------------|
| concrete_goran | 1.3 | 2200 | 940 |
| glass_wool_16K | 0.045 | 16 | 698 |
| plasterboard | 0.22 | 787 | 870 |
| paper_washi | 0.08 | 600 | 1350 |
| mud_wall | 0.23 | 1650 | 900 |

## 備考

### Type指定方式

| 方式 | Type値 | 必須パラメータ | 不要パラメータ |
|-----|--------|--------------|--------------|
| 自動分割 | 0 | div_num, material_name, temp, rh | - |
| cell_data参照 | ファイル名 | - | div_num, material_name, temp, rh |

### 不要パラメータの扱い

cell_data参照方式では以下を空欄にする：
- `div_num` → 空
- `material_name` → 空
- `temp` → 空
- `rh` → 空
