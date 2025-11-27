# Wall Condition

壁条件の設定ファイル一覧

## ファイル一覧

| ファイル名 | 説明 | 状態 |
|-----------|------|------|
| 01-base-model.csv | ベースモデル（単層RC） | 完了 |

## パターン比較表

| 変数 | 単位 | P0 (Base) 単層RC | P1 RC+内断熱 | P2 RC+外断熱 | P3 RC+内断熱+吸放湿 | P4 伝統土壁 |
|-----|------|-----------------|--------------|--------------|-------------------|------------|
| num | - | 1 | - | - | - | - |
| IP (外側室) | - | 1 (outdoor) | - | - | - | - |
| IM (内側室) | - | 2 (indoor) | - | - | - | - |
| Type | - | wall3 | TODO | TODO | TODO | TODO |
| div_num | - | (空) | - | - | - | - |
| material_name | - | (空) | - | - | - | - |
| temp (初期) | ℃ | (空) | - | - | - | - |
| rh (初期) | % | (空) | - | - | - | - |
| thickness | m | 0.15 | TODO | TODO | TODO | TODO |
| area | m² | 12.5 (5×2.5) | - | - | - | - |
| ION (傾斜) | 度 | 90 (垂直) | - | - | - | - |
| dir_IP | - | S (南) | - | - | - | - |
| dir_IM | - | N | - | - | - | - |
| ar_IP | - | 0 | - | - | - | - |
| ar_IM | - | 0 | - | - | - | - |
| er_IP | - | 0 | - | - | - | - |
| er_IM | - | 0 | - | - | - | - |
| alphac_IP | W/m²K | 9 | - | - | - | - |
| alphac_IM | W/m²K | 4.9 | - | - | - | - |
| alphar_IP | W/m²K | 4.4 | - | - | - | - |
| alphar_IM | W/m²K | 4.4 | - | - | - | - |
| aldm_IP | kg/m²sPa | (空) | - | - | - | - |
| aldm_IM | kg/m²sPa | (空) | - | - | - | - |
| q | W/m² | 0 | - | - | - | - |
| jv | kg/m² | 0 | - | - | - | - |
| jl | kg/m² | 0 | - | - | - | - |

## 構造的特徴

| パターン | 特徴 |
|---------|------|
| P0 | RC単層・非吸放湿 |
| P1 | RC＋内側断熱材（EPS等） |
| P2 | RC＋外側断熱材 |
| P3 | RC＋内断熱＋石膏ボード＋紙（吸放湿） |
| P4 | 土壁（高調湿） |

## 備考

### Type指定方式

| 方式 | Type値 | 必須パラメータ | 不要パラメータ |
|-----|--------|--------------|--------------|
| 自動分割 | 0 | div_num, material_name, temp, rh | - |
| cell_data参照 | ファイル名 | - | div_num, material_name, temp, rh |

### 既存cell_dataファイル一覧

`input_data/building_network_model/cell_data/` 内のファイル：

| ファイル名 | 構成 | 厚さ |
|-----------|-----|------|
| wall3 | concrete_goran 単層 | 0.15m |
| wall2_1 | RC + EPS（内断熱） | 0.175m |
| wall2_2 | EPS + RC（外断熱） | 0.175m |
| wall1 | RC + EPS + 通気層 + 石膏ボード + 紙 | 0.22m |
| wall4 | モルタル + RC | 0.175m |
| wall5 | 紙 + 石膏ボード + 通気層 + EPS + RC + モルタル | 0.245m |
| mud_wall | 土壁単層 | 0.175m |

### 不要パラメータの扱い

cell_data参照方式では以下を空欄にする：
- `div_num` → 空
- `material_name` → 空
- `temp` → 空
- `rh` → 空
