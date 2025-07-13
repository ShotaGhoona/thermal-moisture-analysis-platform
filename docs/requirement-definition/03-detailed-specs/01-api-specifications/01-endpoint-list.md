# API エンドポイント仕様

## 基本情報
- **ベースURL**: `http://localhost:8000`
- **API バージョン**: v1
- **認証**: なし（ローカル環境のため）
- **Content-Type**: `application/json`

## エンドポイント一覧

### 1. ヘルスチェック・システム情報

#### `GET /health`
**目的**: システムの動作確認
**認証**: 不要
**レスポンス**: 常に200 OK
```json
{
  "status": "healthy",
  "timestamp": "2024-01-13T10:30:00Z",
  "version": "1.0.0"
}
```

#### `GET /system/info`
**目的**: システム構成情報の取得
**認証**: 不要
**レスポンス**: システム情報
```json
{
  "julia_version": "1.11.5",
  "available_materials": 40,
  "supported_calculation_types": ["1d"],
  "max_concurrent_simulations": 3
}
```

### 2. 材料データベース API

#### `GET /materials`
**目的**: 利用可能な材料一覧の取得
**認証**: 不要
**クエリパラメータ**:
- `category` (optional): "traditional" | "modern" | "special"
- `search` (optional): 材料名での部分検索

**レスポンス例**:
```json
{
  "materials": [
    {
      "id": "mud_wall",
      "name": "土壁",
      "category": "traditional",
      "description": "伝統的な土壁材料",
      "basic_properties": {
        "density": 1650,
        "thermal_conductivity": 0.23,
        "specific_heat": 900
      }
    },
    {
      "id": "concrete_goran",
      "name": "コンクリート",
      "category": "modern", 
      "description": "一般的なコンクリート",
      "basic_properties": {
        "density": 2303.2,
        "thermal_conductivity": 1.3,
        "specific_heat": 1100
      }
    }
  ],
  "total": 40,
  "filtered": 2
}
```

#### `GET /materials/{material_id}`
**目的**: 特定材料の詳細情報取得
**認証**: 不要
**パスパラメータ**:
- `material_id`: 材料ID

**レスポンス例**:
```json
{
  "id": "mud_wall",
  "name": "土壁",
  "category": "traditional",
  "description": "藤原2018年データに基づく土壁物性",
  "properties": {
    "density": 1650,
    "thermal_conductivity": 0.23,
    "specific_heat": 900,
    "porosity": 0.082,
    "moisture_capacity_function": {
      "type": "piecewise",
      "ranges": [
        {"rh_min": 0.0, "rh_max": 0.85, "formula": "0.002 + 0.03 * rh"},
        {"rh_min": 0.85, "rh_max": 1.0, "formula": "0.032 + 0.15 * (rh - 0.85)"}
      ]
    }
  },
  "references": ["藤原2018"],
  "validation_data": {
    "temperature_range": [-10, 60],
    "humidity_range": [0, 100]
  }
}
```

### 3. シミュレーション API

#### `POST /simulations`
**目的**: 新しいシミュレーションの開始
**認証**: 不要
**リクエストボディ**:
```json
{
  "name": "サンプル計算",
  "description": "土壁の熱水分移動解析",
  "calculation_type": "1d",
  "model_config": {
    "wall_layers": [
      {
        "material_id": "mud_wall",
        "thickness": 0.15,
        "division_count": 10
      }
    ],
    "boundary_conditions": {
      "indoor": {
        "temperature": 20.0,
        "relative_humidity": 0.6,
        "heat_transfer_coefficient": 9.3,
        "moisture_transfer_coefficient": 3.2e-8
      },
      "outdoor": {
        "temperature": 30.0,
        "relative_humidity": 0.8,
        "heat_transfer_coefficient": 23.0,
        "moisture_transfer_coefficient": 1.5e-7
      }
    },
    "initial_conditions": {
      "temperature": 25.0,
      "relative_humidity": 0.7
    }
  },
  "calculation_settings": {
    "start_time": "2024-01-01T00:00:00Z",
    "end_time": "2024-01-02T00:00:00Z", 
    "time_step": 1.0,
    "output_interval": 60.0
  }
}
```

**レスポンス**:
```json
{
  "simulation_id": "sim_20240113_103000_abc123",
  "status": "queued",
  "created_at": "2024-01-13T10:30:00Z",
  "estimated_duration": 300
}
```

#### `GET /simulations/{simulation_id}`
**目的**: シミュレーション状態の取得
**認証**: 不要
**パスパラメータ**:
- `simulation_id`: シミュレーションID

**レスポンス例**:
```json
{
  "simulation_id": "sim_20240113_103000_abc123",
  "status": "running",
  "progress": {
    "percentage": 45,
    "current_time": "2024-01-01T10:45:00Z",
    "estimated_remaining": 165
  },
  "created_at": "2024-01-13T10:30:00Z",
  "started_at": "2024-01-13T10:30:15Z",
  "logs": [
    {"timestamp": "2024-01-13T10:30:15Z", "level": "info", "message": "Simulation started"},
    {"timestamp": "2024-01-13T10:32:30Z", "level": "info", "message": "Progress: 45% completed"}
  ]
}
```

#### `GET /simulations/{simulation_id}/results`
**目的**: シミュレーション結果の取得
**認証**: 不要
**パスパラメータ**:
- `simulation_id`: シミュレーションID
**クエリパラメータ**:
- `format` (optional): "json" | "csv" (default: "json")
- `start_time` (optional): 結果取得開始時刻
- `end_time` (optional): 結果取得終了時刻

**レスポンス例**:
```json
{
  "simulation_id": "sim_20240113_103000_abc123",
  "status": "completed",
  "results": {
    "metadata": {
      "calculation_type": "1d",
      "total_points": 11,
      "time_points": 1441,
      "completed_at": "2024-01-13T10:35:00Z"
    },
    "time_series": [
      {
        "timestamp": "2024-01-01T00:00:00Z",
        "positions": [
          {"x": 0.0, "temperature": 20.0, "relative_humidity": 0.6},
          {"x": 0.015, "temperature": 20.1, "relative_humidity": 0.61},
          {"x": 0.03, "temperature": 20.2, "relative_humidity": 0.62}
        ]
      }
    ]
  }
}
```

#### `DELETE /simulations/{simulation_id}`
**目的**: シミュレーションの停止・削除
**認証**: 不要
**パスパラメータ**:
- `simulation_id`: シミュレーションID

**レスポンス**:
```json
{
  "simulation_id": "sim_20240113_103000_abc123",
  "status": "cancelled",
  "cancelled_at": "2024-01-13T10:32:45Z"
}
```

### 4. シミュレーション管理 API

#### `GET /simulations`
**目的**: シミュレーション一覧の取得
**認証**: 不要
**クエリパラメータ**:
- `status` (optional): "queued" | "running" | "completed" | "failed" | "cancelled"
- `limit` (optional): 取得件数上限 (default: 50)
- `offset` (optional): 取得開始位置 (default: 0)

**レスポンス例**:
```json
{
  "simulations": [
    {
      "simulation_id": "sim_20240113_103000_abc123",
      "name": "サンプル計算",
      "status": "completed",
      "created_at": "2024-01-13T10:30:00Z",
      "completed_at": "2024-01-13T10:35:00Z",
      "calculation_type": "1d"
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0
}
```

#### `POST /simulations/validate`
**目的**: シミュレーション設定の事前検証
**認証**: 不要
**リクエストボディ**: `/simulations` と同じ
**レスポンス**:
```json
{
  "valid": true,
  "estimated_duration": 300,
  "estimated_memory": 512,
  "warnings": [
    "Large time step may affect accuracy"
  ],
  "errors": []
}
```

### 5. ファイル出力 API

#### `GET /simulations/{simulation_id}/export`
**目的**: 結果のファイルエクスポート
**認証**: 不要
**パスパラメータ**:
- `simulation_id`: シミュレーションID
**クエリパラメータ**:
- `format`: "csv" | "json" | "excel"
- `include_metadata`: true | false (default: true)

**レスポンス**: ファイルダウンロード
**Content-Type**: 
- CSV: `text/csv`
- JSON: `application/json`
- Excel: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`

## エラーレスポンス標準形式

### 4xx クライアントエラー
```json
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "リクエストの形式が正しくありません",
    "details": {
      "field": "material_id",
      "reason": "存在しない材料IDです"
    },
    "timestamp": "2024-01-13T10:30:00Z"
  }
}
```

### 5xx サーバーエラー
```json
{
  "error": {
    "code": "CALCULATION_ERROR",
    "message": "計算処理中にエラーが発生しました", 
    "details": {
      "julia_error": "UndefVarError: variable not defined",
      "phase": "initialization"
    },
    "timestamp": "2024-01-13T10:30:00Z",
    "simulation_id": "sim_20240113_103000_abc123"
  }
}
```

## レート制限
- **同時実行数**: 最大3シミュレーション
- **リクエスト制限**: なし（ローカル環境のため）
- **ファイルサイズ制限**: 応答 100MB以下

## WebSocket接続 (オプション)

### `WS /simulations/{simulation_id}/stream`
**目的**: リアルタイム進捗更新
**認証**: 不要
**メッセージ例**:
```json
{
  "type": "progress_update",
  "simulation_id": "sim_20240113_103000_abc123",
  "data": {
    "percentage": 67,
    "current_time": "2024-01-01T16:00:00Z",
    "estimated_remaining": 99
  }
}
```

このAPI仕様により、フロントエンドエンジニアは具体的な実装が可能になり、バックエンドエンジニアも明確な実装目標を持つことができます。