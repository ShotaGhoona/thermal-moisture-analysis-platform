# 3D計算機能実装戦略

## 背景・目的

既存の1D計算機能を基に、3D熱水分同時移動解析機能をWebアプリケーションとして実装する。
Juliaの3D_calculation.ipynbの機能をNext.js/TypeScriptで再現し、1Dと同様のUIワークフローを提供する。

## 1. 1Dと3Dの機能比較分析

### 1.1 入力パラメータの違い

| パラメータ | 1D計算 | 3D計算 | 備考 |
|-----------|--------|--------|------|
| **基本設定** | ✅ 同じ | ✅ 同じ | 名前、説明、計算期間、時間刻み |
| **空間定義** | 1次元壁体（Cell配列） | 3次元モデル（3D配列） | 3Dでは空間情報が大幅に拡張 |
| **材料定義** | 層序+材料選択 | 3Dプロパティマッピング | 各CVに材料・空気・境界条件を割り当て |
| **境界条件** | 室内外の環境条件 | 複数空間の環境条件 | 3Dでは空間が複数存在 |
| **幾何形状** | dx, dx2のみ | dx,dy,dz + dx2,dy2,dz2 | 3軸の寸法情報が必要 |

### 1.2 重要な入力ファイル構造

#### 3D特有の入力データ
1. **2D_property_data_*.csv**: 各X軸断面のプロパティマップ（Y×Z配列）
2. **property_information.csv**: プロパティ番号と材料・空間・境界条件の対応
3. **dx_data.csv, dy_data.csv, dz_data.csv**: 各軸の寸法情報
4. **XLSX統合ファイル**: 複数2Dデータの統合

#### プロパティ番号の体系
- 0-19: 境界条件（BC_Neumann）
- 20-99: 空間（BC_Robin）- 例: 20=air_in, 30=air_out, 40=air_mid
- 100以上: 材料（Cell）- 例: 101=mud_wall, 102=plywood

## 2. 型定義の拡張

### 2.1 新しい型定義が必要

```typescript
// 3D計算用の基本型
export interface Position3D {
  x: number;
  y: number;
  z: number;
}

export interface Dimensions3D {
  dx: number;
  dy: number;  
  dz: number;
  dx2?: number;
  dy2?: number;
  dz2?: number;
}

// 3Dプロパティマッピング
export interface PropertyMapping {
  number: number;
  name: string;
  type: 'boundary' | 'air' | 'material';
  alphac?: number;
  alphar?: number;
  alpha?: number;
  aldm?: number;
}

// 3D空間定義
export interface Air3DSpace {
  name: string;
  temperature: number;
  relative_humidity: number;
  volume?: number;
  convection_heat_transfer?: number;
  radiation_heat_transfer?: number;
  moisture_transfer?: number;
}

// 3Dモデル全体
export interface Model3D {
  dimensions: {
    x_count: number;
    y_count: number;
    z_count: number;
  };
  property_data: number[][][]; // [x][y][z]
  property_mapping: PropertyMapping[];
  dimension_data: {
    dx: number[];
    dy: number[];
    dz: number[];
    dx2?: number[];
    dy2?: number[];
    dz2?: number[];
  };
  air_spaces: Record<string, Air3DSpace>;
}
```

### 2.2 既存型の拡張

```typescript
// Step2の拡張（3D用）
export interface Step2FormData3D {
  calculation_type: '3d';
  model_type: 'property_mapping' | 'manual_construction';
  
  // プロパティマッピング方式の場合
  property_mapping?: {
    x_sections: number;
    y_divisions: number;
    z_divisions: number;
    property_data: number[][][];
    property_definitions: PropertyMapping[];
    dimensions: {
      dx: number[];
      dy: number[];
      dz: number[];
    };
  };
  
  // 手動構築方式の場合（将来的な拡張）
  manual_construction?: {
    spaces: Air3DSpace[];
    materials: MaterialDefinition3D[];
    geometry: GeometryDefinition3D;
  };
}

// Step3の拡張（3D用）
export interface Step3FormData3D {
  air_spaces: Record<string, {
    temperature: number;
    relative_humidity: number;
    convection_heat_transfer: number;
    radiation_heat_transfer: number;
    moisture_transfer: number;
  }>;
  initial_conditions: {
    temperature: number;
    relative_humidity: number;
  };
  advanced?: {
    convergence_threshold: number;
    max_iterations: number;
  };
}
```

## 3. UI設計戦略

### 3.1 ページ構成
```
/calculation/3d/
├── step1/          # 基本設定（1Dと同じ）
├── step2/          # 3Dモデル構築
├── step3/          # 境界条件・空間設定
└── step4/          # 確認・実行（1Dと同じ）
```

### 3.2 Step2の詳細設計

#### 3.2.1 モデル入力方式の選択
- **プロパティマッピング方式**（推奨）: CSVファイル+Excelアップロード
- **手動構築方式**（将来拡張）: ビジュアルエディタ

#### 3.2.2 プロパティマッピング方式のUI
1. **ファイルアップロード**
   - 2D_property_data*.csv（複数ファイル）
   - または統合XLSXファイル
   - dx_data.csv, dy_data.csv, dz_data.csv
   - property_information.csv

2. **プロパティ定義エディタ**
   - プロパティ番号と材料・空間・境界条件の対応表
   - インラインで編集可能

3. **3Dプレビュー**
   - Three.jsまたはReact Three Fiberを使用
   - 断面表示切り替え（X, Y, Z軸）
   - プロパティ別の色分け表示

4. **寸法設定**
   - 各軸の分割数と寸法の表
   - ビジュアルでの寸法確認

### 3.3 Step3の詳細設計

#### 3.3.1 空間環境設定
- 複数の空間（air_in, air_out, air_mid等）に対する環境条件設定
- 空間ごとのタブまたはアコーディオンUI

#### 3.3.2 伝達係数設定
- 各空間に対する対流・放射・湿気伝達係数の設定
- プリセット値の提供

## 4. コンポーネント設計

### 4.1 新規コンポーネント

```typescript
// 3Dモデルビューア
interface Model3DViewerProps {
  model: Model3D;
  currentSection: number;
  axis: 'x' | 'y' | 'z';
  onSectionChange: (section: number) => void;
  onAxisChange: (axis: 'x' | 'y' | 'z') => void;
}

// プロパティマッピングエディタ
interface PropertyMappingEditorProps {
  properties: PropertyMapping[];
  materials: Material[];
  onPropertiesChange: (properties: PropertyMapping[]) => void;
}

// ファイルアップロードグループ
interface FileUploadGroupProps {
  onPropertyDataUpload: (files: File[]) => void;
  onDimensionDataUpload: (files: Record<'dx' | 'dy' | 'dz', File>) => void;
  onPropertyInfoUpload: (file: File) => void;
}

// 空間環境設定
interface AirSpaceConfigProps {
  airSpaces: Record<string, Air3DSpace>;
  onAirSpacesChange: (airSpaces: Record<string, Air3DSpace>) => void;
}
```

### 4.2 既存コンポーネントの拡張

- **StepProgress**: ステップ表示を3D用に調整
- **SettingSummary**: 3Dモデル情報の表示機能追加

## 5. 実装フェーズ

### Phase 1: 基盤整備（Week 1）
- [ ] 3D用型定義の追加
- [ ] ルーティングの設定（/calculation/3d/step*）
- [ ] Step1ページの複製・調整

### Phase 2: 3Dモデル入力（Week 2）
- [ ] Step2ページの実装
- [ ] ファイルアップロード機能
- [ ] CSVパースライブラリの統合
- [ ] プロパティマッピングエディタ

### Phase 3: 3Dビジュアライゼーション（Week 3）  
- [ ] Three.js/React Three Fiberの統合
- [ ] 3Dモデルビューアの実装
- [ ] 断面表示機能

### Phase 4: 境界条件設定（Week 4）
- [ ] Step3ページの実装
- [ ] 複数空間環境設定UI
- [ ] バリデーションロジック

### Phase 5: 統合・テスト（Week 5）
- [ ] Step4確認ページの調整
- [ ] エラーハンドリング
- [ ] ユーザビリティテスト

## 6. 技術的考慮事項

### 6.1 パフォーマンス
- 大きな3Dデータの処理: Web Workers活用
- 3Dレンダリング: LOD（Level of Detail）実装
- ファイルアップロード: チャンク式アップロード

### 6.2 ライブラリ選定
- **3Dビジュアライゼーション**: React Three Fiber + Drei
- **CSVパース**: Papa Parse
- **Excelファイル**: SheetJS
- **ファイルアップロード**: React Dropzone

### 6.3 データ検証
- プロパティ番号の整合性チェック
- 寸法データの整合性チェック
- ファイル形式の検証

## 7. ユーザビリティ考慮

### 7.1 エラー防止
- サンプルファイルの提供
- リアルタイムバリデーション
- ファイル形式のテンプレート

### 7.2 学習コストの削減
- 1Dからの移行ガイド
- インタラクティブチュートリアル
- プリセットモデルの提供

## 8. 将来拡張性

### 8.1 手動モデル構築
- ドラッグ&ドロップによる3Dモデリング
- CADファイルインポート
- プロシージャル生成

### 8.2 高度な可視化
- 結果の3Dアニメーション
- 断熱性能の等値面表示
- リアルタイム計算結果表示

## 結論

3D計算機能は1D機能の自然な拡張として実装する。特に重要なのは：

1. **段階的な実装**: 1Dユーザーが迷わない設計
2. **ファイルベースの入力**: Juliaプログラムとの整合性
3. **視覚的フィードバック**: 3Dモデルの正確性確認
4. **拡張性**: 将来の機能追加に対応

この戦略により、既存の1D機能を活用しつつ、3D固有の複雑さを適切に管理できる。