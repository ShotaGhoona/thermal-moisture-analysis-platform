# Juliaシミュレーションデータ チェックリスト

75パターン（5壁構造 × 5換気量 × 3気候）のデータ確認用

## 凡例

**壁構造（W）**
| ID | 名称 | 説明 |
|----|------|------|
| W1 | RC単層 | 高蓄熱・非吸放湿 |
| W2 | RC内断熱 | 蓄熱が外気側 |
| W3 | RC外断熱 | 蓄熱が室内側 |
| W4 | RC内断熱+吸放湿 | 吸放湿内装あり |
| W5 | 土壁 | 高調湿性・伝統構法 |

**換気量（O）**
| ID | 名称 | 換気回数 |
|----|------|----------|
| O1 | 標準換気 | 0.5 回/h |
| O2 | 弱換気 | 0.1 回/h |
| O3 | 強換気 | 1.0 回/h |
| O4 | 無換気 | 0.0 回/h |
| O5 | 蔵換気 | 2.0 回/h |

---

## 京都

|  | O1 | O2 | O3 | O4 | O5 |
|--|----|----|----|----|-----|
| W1 | ✅ (約2日不足) / ❌ (1224:3ヶ月不足) / ❌ (run01:3ヶ月不足) | ✅ (約2日不足) / ❌ (run02:3ヶ月不足) | ✅ (約2日不足) / ❌ (run03:3ヶ月不足) | ✅ (約2日不足) / ❌ (1224:3ヶ月不足) / ❌ (run04:3ヶ月不足) | ✅ (約2日不足) / ❌ (1224:3ヶ月不足) / ❌ (run05:3ヶ月不足) |
| W2 | ✅ (約2日不足) / ❌ (1224:11日で停止) | ✅ (約2日不足) | ✅ (約2日不足) | ✅ (約2日不足) | ✅ (約2日不足) |
| W3 | ❌ (NaN発散) | ❌ (NaN発散) | ❌ (NaN発散) | ❌ (NaN発散) | ❌ (NaN発散) |
| W4 | ✅ (約2日不足) | ✅ (約2日不足) | ✅ (約2日不足) | ✅ (約2日不足) | ✅ (約2日不足) |
| W5 | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) |

---

## 沖縄

|  | O1 | O2 | O3 | O4 | O5 |
|--|----|----|----|----|-----|
| W1 | ✅ (約1日不足) / ❌ (1224:3ヶ月不足) | ✅ (約1日不足) / ❌ (1224:3ヶ月不足) | ✅ (約1日不足) / ❌ (1224:3ヶ月不足) | ✅ (約1日不足) / ❌ (1224:3ヶ月不足) | ✅ (約1日不足) / ❌ (1224:3ヶ月不足) |
| W2 | ❌ (6ヶ月不足) / ❌ (1224:11日で停止) | ❌ (6ヶ月不足) | ❌ (6ヶ月不足) | ❌ (6ヶ月不足) | ❌ (6ヶ月不足) |
| W3 | - | - | - | - | - |
| W4 | - | - | - | - | - |
| W5 | - | - | - | - | - |

---

## 札幌

|  | O1 | O2 | O3 | O4 | O5 |
|--|----|----|----|----|-----|
| W1 | ❌ (3ヶ月不足) | ❌ (3ヶ月不足) | ❌ (3ヶ月不足) | ❌ (3ヶ月不足) | ❌ (3ヶ月不足) |
| W2 | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) |
| W3 | ❌ (NaN発散) | ❌ (NaN発散) | ❌ (NaN発散) | ❌ (NaN発散) | ❌ (NaN発散) |
| W4 | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) |
| W5 | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) | ✅ (約1日不足) |

---

## データチェック方法

### 判定基準

| マーク | 意味 |
|--------|------|
| ✅ | OK（実用上問題なし、約2日不足まで許容） |
| ❌ | NG（要再計算：NaN発散、大幅なデータ不足など） |
| - | 未確認 |

- **期待される期間**: 2022/04/01 00:00 ～ 2023/04/01（1年間）
- **NaN発散**: 数値が発散してNaNが大量に含まれている状態

### チェックコマンド例

**単一ディレクトリのチェック:**
```bash
dir="legacy-julia/output_data/batch_all_o01/run01/w01-base_o01-base_kyoto"
file="$dir/result_all_rooms.csv"

# 行数、NaN数、開始日、終了日を確認
lines=$(wc -l < "$file")
nan_count=$(grep -ci "nan" "$file" 2>/dev/null || echo 0)
start_date=$(sed -n '3p' "$file" | cut -d',' -f1)
end_date=$(tail -1 "$file" | cut -d',' -f1)
echo "期間: $start_date → $end_date | 行数: $lines | NaN: $nan_count"
```

**複数ディレクトリの一括チェック:**
```bash
base_path="legacy-julia/output_data/batch_all_o01/run01"

for dir in w01-base_o01-base_kyoto w02-inner_o01-base_kyoto w03-outer_o01-base_kyoto w04-hygro_o01-base_kyoto; do
  file="$base_path/$dir/result_all_rooms.csv"
  if [ -f "$file" ]; then
    end_date=$(tail -1 "$file" | cut -d',' -f1)
    nan_count=$(grep -ci "nan" "$file" 2>/dev/null || echo 0)
    echo "$dir: → $end_date | NaN: $nan_count"
  else
    echo "$dir: ファイルなし"
  fi
done
```

**エラーファイルの確認:**
```bash
cat "$dir/_error.txt"
```

### データパス一覧

| バッチ | パス |
|--------|------|
| 京都 O1-O5 | `legacy-julia/output_data/batch_all_o0{1-5}/run0{1-5}/` |
| 京都 1224 | `legacy-julia/output_data/batch_all/1224/` |
| 京都 run01-05 | `legacy-julia/output_data/batch_all/run0{1-5}/` |
| 沖縄 1224 | `legacy-julia/output_data/batch_all_2/1224/` |
| 沖縄 run01-05 | `legacy-julia/output_data/batch_all/run0{1-5}/` |
| 札幌 1224 | `legacy-julia/output_data/batch_all_3/1224/` |

### ファイル命名規則

```
{wall_id}_{opening_id}_{climate_id}
例: w01-base_o01-base_kyoto
```

| ID | 壁構造 |
|----|--------|
| w01-base | RC単層 |
| w02-inner | RC内断熱 |
| w03-outer | RC外断熱 |
| w04-hygro | RC内断熱+吸放湿 |
| w05-mud | 土壁 |

| ID | 換気量 |
|----|--------|
| o01-base | 標準換気 (0.5回/h) |
| o02-low | 弱換気 (0.1回/h) |
| o03-high | 強換気 (1.0回/h) |
| o04-none | 無換気 (0.0回/h) |
| o05-storage | 蔵換気 (2.0回/h) |

| ID | 気候 |
|----|------|
| kyoto | 京都 |
| okinawa | 沖縄 |
| sapporo | 札幌 |
