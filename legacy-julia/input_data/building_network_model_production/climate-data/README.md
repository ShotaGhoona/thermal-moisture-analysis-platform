# Climate Data - 気象データ

## フォルダ構成

```
climate-data/
├── climate_data_kyoto.csv      # 加工後データ（京都）
├── climate_data_okinawa.csv    # 加工後データ（沖縄）
├── climate_data_sapporo.csv    # 加工後データ（札幌）
├── raw/                        # 生データ
│   ├── weather_Kyoto.csv
│   ├── weather_Okinawa.csv
│   └── weather_Sapporo.csv
├── script/                     # 変換スクリプト
│   └── convert_climate_data.jl
└── README.md
```

## 加工後データ

| ファイル | 都市 | 気温範囲 | 湿度範囲 |
|----------|------|----------|----------|
| climate_data_kyoto.csv | 京都 | -2.4〜35.3℃ | 13〜96% |
| climate_data_okinawa.csv | 沖縄 | 12.8〜31.1℃ | 40〜97% |
| climate_data_sapporo.csv | 札幌 | -13.7〜31.2℃ | 20〜96% |

### データ形式

```
date,temp,rh,p_atm,Jp,Js,WS,WD,Qs,tau,cloudiness
2020/1/1 0:00,3.9,72,,0.0,,1.1,南,,1.0e-50,
```

| カラム | 単位 | 説明 |
|--------|------|------|
| date | y/m/d HH:MM | 日時 |
| temp | ℃ | 気温 |
| rh | % | 相対湿度 |
| tau | - | 大気透過率 |

## 生データ（raw/）

2010年〜2020年の統計データ（年情報なし）

| カラム | 説明 |
|--------|------|
| 月,日,時 | 日時 |
| 気温 | ℃ |
| 絶対湿度 | g/kg |
| 気圧 | Pa |

## 変換スクリプト（script/）

```bash
cd legacy-julia
julia input_data/building_network_model_production/climate-data/script/convert_climate_data.jl
```

### 変換内容

- 絶対湿度 → 相対湿度（Tetens式）
- 風向（度） → 日本語16方位
- 年の付与（2020年）
- エンコーディング: Shift_JIS
