# TypeScript インターフェース定義

## 基本型定義

### 共通型
```typescript
// lib/types/common.ts

/** 日時文字列 (ISO 8601形式) */
type ISODateTime = string;

/** 材料ID */
type MaterialId = string;

/** シミュレーションID */
type SimulationId = string;

/** ステータス型 */
type SimulationStatus = 'queued' | 'running' | 'completed' | 'failed' | 'cancelled';

/** 計算タイプ */
type CalculationType = '1d' | '3d' | 'network';

/** 材料カテゴリ */
type MaterialCategory = 'traditional' | 'modern' | 'special';

/** エクスポート形式 */
type ExportFormat = 'csv' | 'json' | 'excel';
```

## 材料関連インターフェース

```typescript
// lib/types/materials.ts

/** 基本物性値 */
interface BasicProperties {
  /** 密度 [kg/m³] */
  density: number;
  /** 熱伝導率 [W/m·K] */
  thermal_conductivity: number;
  /** 比熱 [J/kg·K] */
  specific_heat: number;
  /** 空隙率 [-] */
  porosity?: number;
}

/** 含水率関数の定義 */
interface MoistureCapacityFunction {
  type: 'piecewise' | 'polynomial' | 'exponential';
  ranges?: Array<{
    rh_min: number;
    rh_max: number;
    formula: string;
  }>;
  coefficients?: number[];
}

/** 材料の詳細物性 */
interface MaterialProperties extends BasicProperties {
  /** 含水率関数 */
  moisture_capacity_function: MoistureCapacityFunction;
  /** 透湿率 [kg/m·Pa·s] */
  vapor_permeability?: number;
  /** 液水伝導率関数 */
  liquid_conductivity_function?: MoistureCapacityFunction;
}

/** 材料の検証データ */
interface ValidationData {
  /** 温度適用範囲 [°C] */
  temperature_range: [number, number];
  /** 湿度適用範囲 [%] */
  humidity_range: [number, number];
  /** 検証実験データ */
  experimental_data?: any[];
}

/** 材料基本情報 */
interface Material {
  /** 材料ID */
  id: MaterialId;
  /** 材料名 */
  name: string;
  /** カテゴリ */
  category: MaterialCategory;
  /** 説明 */
  description: string;
  /** 基本物性値 */
  basic_properties: BasicProperties;
}

/** 材料詳細情報 */
interface MaterialDetail extends Material {
  /** 詳細物性値 */
  properties: MaterialProperties;
  /** 参考文献 */
  references: string[];
  /** 検証データ */
  validation_data: ValidationData;
}

/** 材料一覧レスポンス */
interface MaterialsResponse {
  materials: Material[];
  total: number;
  filtered: number;
}
```

## シミュレーション関連インターフェース

```typescript
// lib/types/simulation.ts

/** 位置座標 */
interface Position {
  /** X座標 [m] */
  x: number;
  /** Y座標 [m] (3D計算時のみ) */
  y?: number;
  /** Z座標 [m] (3D計算時のみ) */
  z?: number;
}

/** 計算点の状態値 */
interface StateValue {
  /** 温度 [°C] */
  temperature: number;
  /** 相対湿度 [-] (0-1) */
  relative_humidity: number;
  /** 含水率 [kg/kg] */
  moisture_content?: number;
  /** 水分化学ポテンシャル [J/kg] */
  chemical_potential?: number;
}

/** 位置と状態を持つ計算点 */
interface CalculationPoint extends Position, StateValue {}

/** 壁体層の定義 */
interface WallLayer {
  /** 材料ID */
  material_id: MaterialId;
  /** 層厚さ [m] */
  thickness: number;
  /** 分割数 */
  division_count: number;
  /** 初期温度 [°C] (省略時はinitial_conditionsを使用) */
  initial_temperature?: number;
  /** 初期相対湿度 [-] (省略時はinitial_conditionsを使用) */
  initial_relative_humidity?: number;
}

/** 境界条件 */
interface BoundaryCondition {
  /** 温度 [°C] */
  temperature: number;
  /** 相対湿度 [-] (0-1) */
  relative_humidity: number;
  /** 熱伝達率 [W/m²·K] */
  heat_transfer_coefficient: number;
  /** 湿気伝達率 [kg/m²·Pa·s] */
  moisture_transfer_coefficient: number;
  /** 放射熱伝達率 [W/m²·K] */
  radiation_heat_transfer_coefficient?: number;
}

/** 初期条件 */
interface InitialConditions {
  /** 初期温度 [°C] */
  temperature: number;
  /** 初期相対湿度 [-] (0-1) */
  relative_humidity: number;
}

/** モデル設定 */
interface ModelConfig {
  /** 壁体層構成 */
  wall_layers: WallLayer[];
  /** 境界条件 */
  boundary_conditions: {
    indoor: BoundaryCondition;
    outdoor: BoundaryCondition;
  };
  /** 初期条件 */
  initial_conditions: InitialConditions;
}

/** 計算設定 */
interface CalculationSettings {
  /** 計算開始時刻 */
  start_time: ISODateTime;
  /** 計算終了時刻 */
  end_time: ISODateTime;
  /** 時間刻み [秒] */
  time_step: number;
  /** 出力間隔 [秒] */
  output_interval: number;
  /** 収束判定閾値 */
  convergence_threshold?: number;
  /** 最大反復回数 */
  max_iterations?: number;
}

/** シミュレーション作成リクエスト */
interface SimulationCreateRequest {
  /** シミュレーション名 */
  name: string;
  /** 説明 */
  description?: string;
  /** 計算タイプ */
  calculation_type: CalculationType;
  /** モデル設定 */
  model_config: ModelConfig;
  /** 計算設定 */
  calculation_settings: CalculationSettings;
}

/** 進捗情報 */
interface Progress {
  /** 進捗率 [%] (0-100) */
  percentage: number;
  /** 現在の計算時刻 */
  current_time: ISODateTime;
  /** 推定残り時間 [秒] */
  estimated_remaining: number;
}

/** ログエントリ */
interface LogEntry {
  /** タイムスタンプ */
  timestamp: ISODateTime;
  /** ログレベル */
  level: 'debug' | 'info' | 'warning' | 'error';
  /** メッセージ */
  message: string;
  /** 詳細情報 */
  details?: any;
}

/** シミュレーション基本情報 */
interface Simulation {
  /** シミュレーションID */
  simulation_id: SimulationId;
  /** 名前 */
  name: string;
  /** 説明 */
  description?: string;
  /** ステータス */
  status: SimulationStatus;
  /** 計算タイプ */
  calculation_type: CalculationType;
  /** 作成日時 */
  created_at: ISODateTime;
  /** 開始日時 */
  started_at?: ISODateTime;
  /** 完了日時 */
  completed_at?: ISODateTime;
  /** 推定所要時間 [秒] */
  estimated_duration?: number;
}

/** シミュレーション詳細情報 */
interface SimulationDetail extends Simulation {
  /** 進捗情報 */
  progress?: Progress;
  /** ログ */
  logs: LogEntry[];
  /** モデル設定 (completed時のみ) */
  model_config?: ModelConfig;
  /** 計算設定 (completed時のみ) */
  calculation_settings?: CalculationSettings;
}

/** 時系列データポイント */
interface TimeSeriesPoint {
  /** タイムスタンプ */
  timestamp: ISODateTime;
  /** 各位置での計算値 */
  positions: CalculationPoint[];
}

/** 結果メタデータ */
interface ResultMetadata {
  /** 計算タイプ */
  calculation_type: CalculationType;
  /** 計算点総数 */
  total_points: number;
  /** 時間ステップ数 */
  time_points: number;
  /** 完了日時 */
  completed_at: ISODateTime;
  /** 計算統計情報 */
  statistics?: {
    /** 最大温度 [°C] */
    max_temperature: number;
    /** 最小温度 [°C] */
    min_temperature: number;
    /** 最大相対湿度 [-] */
    max_relative_humidity: number;
    /** 最小相対湿度 [-] */
    min_relative_humidity: number;
  };
}

/** シミュレーション結果 */
interface SimulationResults {
  /** シミュレーションID */
  simulation_id: SimulationId;
  /** ステータス */
  status: SimulationStatus;
  /** 結果データ */
  results: {
    /** メタデータ */
    metadata: ResultMetadata;
    /** 時系列データ */
    time_series: TimeSeriesPoint[];
  };
}

/** 検証リクエスト */
interface ValidationRequest extends SimulationCreateRequest {}

/** 検証レスポンス */
interface ValidationResponse {
  /** 検証結果 */
  valid: boolean;
  /** 推定所要時間 [秒] */
  estimated_duration: number;
  /** 推定メモリ使用量 [MB] */
  estimated_memory: number;
  /** 警告メッセージ */
  warnings: string[];
  /** エラーメッセージ */
  errors: string[];
}
```

## UI コンポーネント関連インターフェース

```typescript
// lib/types/ui.ts

/** チャートデータポイント */
interface ChartDataPoint {
  /** X軸値 (時間または位置) */
  x: number | string;
  /** Y軸値 */
  y: number;
  /** 系列名 */
  series?: string;
}

/** グラフ設定 */
interface ChartConfig {
  /** グラフタイトル */
  title: string;
  /** X軸ラベル */
  xLabel: string;
  /** Y軸ラベル */
  yLabel: string;
  /** 表示する系列 */
  series: Array<{
    /** 系列名 */
    name: string;
    /** 色 */
    color: string;
    /** データキー */
    dataKey: string;
  }>;
}

/** フォーム状態 */
interface FormState {
  /** 入力値 */
  values: Record<string, any>;
  /** エラー */
  errors: Record<string, string>;
  /** 変更フラグ */
  dirty: boolean;
  /** 送信中フラグ */
  submitting: boolean;
}

/** ページネーション */
interface Pagination {
  /** 現在のページ */
  current: number;
  /** 1ページあたりの件数 */
  pageSize: number;
  /** 総件数 */
  total: number;
}

/** 通知メッセージ */
interface Notification {
  /** ID */
  id: string;
  /** タイプ */
  type: 'info' | 'success' | 'warning' | 'error';
  /** タイトル */
  title: string;
  /** メッセージ */
  message: string;
  /** 自動消去時間 [ms] */
  duration?: number;
}
```

## API レスポンス型

```typescript
// lib/types/api.ts

/** 基本APIレスポンス */
interface ApiResponse<T = any> {
  data?: T;
  error?: ApiError;
  timestamp: ISODateTime;
}

/** APIエラー */
interface ApiError {
  /** エラーコード */
  code: string;
  /** エラーメッセージ */
  message: string;
  /** 詳細情報 */
  details?: any;
  /** シミュレーションID (該当する場合) */
  simulation_id?: SimulationId;
}

/** リスト型レスポンス */
interface ListResponse<T> {
  /** データ配列 */
  items: T[];
  /** 総件数 */
  total: number;
  /** 取得上限数 */
  limit: number;
  /** 取得開始位置 */
  offset: number;
}

/** WebSocketメッセージ */
interface WebSocketMessage {
  /** メッセージタイプ */
  type: 'progress_update' | 'status_change' | 'error' | 'completed';
  /** シミュレーションID */
  simulation_id: SimulationId;
  /** データ */
  data: any;
  /** タイムスタンプ */
  timestamp: ISODateTime;
}
```

## React Hooks 型定義

```typescript
// lib/hooks/types.ts

/** シミュレーション管理フック返り値 */
interface UseSimulationReturn {
  /** シミュレーション一覧 */
  simulations: Simulation[];
  /** 選択中のシミュレーション */
  currentSimulation: SimulationDetail | null;
  /** ローディング状態 */
  loading: boolean;
  /** エラー */
  error: string | null;
  /** 新規作成 */
  createSimulation: (request: SimulationCreateRequest) => Promise<SimulationId>;
  /** 詳細取得 */
  getSimulation: (id: SimulationId) => Promise<void>;
  /** 削除 */
  deleteSimulation: (id: SimulationId) => Promise<void>;
  /** 一覧更新 */
  refreshList: () => Promise<void>;
}

/** 材料管理フック返り値 */
interface UseMaterialsReturn {
  /** 材料一覧 */
  materials: Material[];
  /** 選択中の材料詳細 */
  currentMaterial: MaterialDetail | null;
  /** ローディング状態 */
  loading: boolean;
  /** エラー */
  error: string | null;
  /** 材料検索 */
  searchMaterials: (query: string, category?: MaterialCategory) => Promise<void>;
  /** 材料詳細取得 */
  getMaterialDetail: (id: MaterialId) => Promise<void>;
}

/** ポーリングフック設定 */
interface UsePollingOptions {
  /** ポーリング間隔 [ms] */
  interval: number;
  /** 自動停止条件 */
  stopCondition?: (data: any) => boolean;
  /** エラー時の動作 */
  onError?: (error: Error) => void;
}
```

これらのTypeScript型定義により、フロントエンド開発時の型安全性が確保され、APIとの連携において期待されるデータ構造が明確になります。