# 最適ディレクトリ構造設計

## 既存Juliaコード分析結果に基づく設計

### 分析サマリー
既存プログラムは優れたモジュラー設計を持ち、Web化に適している。特に：
- **計算エンジン**: `transfer_in_media.jl` を中心とした数値計算部分はAPI化に最適
- **材料データベース**: 40種類以上の材料物性が体系化されており、そのまま活用可能
- **境界条件処理**: 3種類の境界条件が柔軟に対応できる設計

## 提案: 最適ディレクトリ構造

```
thermal-simulation-web/
├── README.md
├── docker-compose.yml
├── .env.example
├── .gitignore
│
├── frontend/                           # Next.js フロントエンド
│   ├── Dockerfile
│   ├── package.json
│   ├── next.config.js
│   ├── tailwind.config.js
│   ├── tsconfig.json
│   ├── src/
│   │   ├── app/
│   │   │   ├── layout.tsx              # 全体レイアウト
│   │   │   ├── page.tsx                # ホーム画面
│   │   │   ├── globals.css             # グローバルスタイル
│   │   │   ├── calculation/            # 計算設定関連
│   │   │   │   ├── 1d/
│   │   │   │   │   ├── step1/
│   │   │   │   │   │   └── page.tsx    # Step1: 基本設定
│   │   │   │   │   ├── step2/
│   │   │   │   │   │   └── page.tsx    # Step2: 材料選択
│   │   │   │   │   ├── step3/
│   │   │   │   │   │   └── page.tsx    # Step3: 境界条件
│   │   │   │   │   └── step4/
│   │   │   │   │       └── page.tsx    # Step4: 確認・実行
│   │   │   │   ├── network/            # ネットワーク計算 (将来拡張)
│   │   │   │   └── 3d/                 # 3D計算 (将来拡張)
│   │   │   ├── progress/
│   │   │   │   └── [id]/
│   │   │   │       └── page.tsx        # 計算進捗表示
│   │   │   ├── results/
│   │   │   │   └── [id]/
│   │   │   │       └── page.tsx        # 結果表示画面
│   │   │   ├── history/
│   │   │   │   └── page.tsx            # シミュレーション履歴
│   │   │   ├── materials/
│   │   │   │   ├── page.tsx            # 材料データベース一覧
│   │   │   │   └── [id]/
│   │   │   │       └── page.tsx        # 材料詳細情報
│   │   │   ├── system/
│   │   │   │   └── page.tsx            # システム情報
│   │   │   └── api/                    # Next.js API Routes (プロキシ用)
│   │   │       └── proxy/[...path].ts
│   │   ├── components/
│   │   │   ├── ui/                     # shadcn/ui基本コンポーネント
│   │   │   │   ├── button.tsx
│   │   │   │   ├── input.tsx
│   │   │   │   ├── select.tsx
│   │   │   │   ├── card.tsx
│   │   │   │   ├── dialog.tsx
│   │   │   │   ├── form.tsx
│   │   │   │   ├── label.tsx
│   │   │   │   ├── progress.tsx
│   │   │   │   ├── table.tsx
│   │   │   │   ├── separator.tsx
│   │   │   │   ├── badge.tsx
│   │   │   │   ├── alert.tsx
│   │   │   │   └── skeleton.tsx
│   │   │   ├── layout/
│   │   │   │   ├── Header.tsx
│   │   │   │   ├── Footer.tsx
│   │   │   │   ├── Sidebar.tsx
│   │   │   │   ├── Navigation.tsx
│   │   │   │   └── Breadcrumbs.tsx
│   │   │   ├── forms/                  # フォーム関連コンポーネント
│   │   │   │   ├── StepProgress.tsx
│   │   │   │   ├── BasicSettingsForm.tsx
│   │   │   │   ├── MaterialSelector.tsx
│   │   │   │   ├── WallLayerEditor.tsx
│   │   │   │   ├── BoundaryConditions.tsx
│   │   │   │   ├── ConfigurationSummary.tsx
│   │   │   │   ├── WallDiagram.tsx
│   │   │   │   ├── MaterialCard.tsx
│   │   │   │   └── ParameterInput.tsx
│   │   │   ├── visualization/          # グラフ・可視化
│   │   │   │   ├── TemperatureChart.tsx
│   │   │   │   ├── HumidityChart.tsx
│   │   │   │   ├── DataTable.tsx
│   │   │   │   ├── ExportButtons.tsx
│   │   │   │   └── ChartControls.tsx
│   │   │   ├── simulation/             # シミュレーション固有
│   │   │   │   ├── ProgressMonitor.tsx
│   │   │   │   ├── SimulationCard.tsx
│   │   │   │   ├── LogViewer.tsx
│   │   │   │   ├── ResultSummary.tsx
│   │   │   │   └── StatusIndicator.tsx
│   │   │   └── shared/                 # 共通コンポーネント
│   │   │       ├── LoadingSpinner.tsx
│   │   │       ├── ErrorBoundary.tsx
│   │   │       ├── SystemStatus.tsx
│   │   │       └── NotificationToast.tsx
│   │   ├── hooks/
│   │   │   ├── use-simulation.ts       # シミュレーション状態管理
│   │   │   ├── use-materials.ts        # 材料データ管理
│   │   │   ├── use-polling.ts          # 進捗ポーリング
│   │   │   ├── use-websocket.ts        # WebSocket管理
│   │   │   ├── use-form-state.ts       # フォーム状態管理
│   │   │   ├── use-local-storage.ts    # ローカルストレージ
│   │   │   └── use-toast.ts            # 通知管理
│   │   ├── services/
│   │   │   ├── api.ts                  # API クライアント設定
│   │   │   ├── simulation-service.ts   # シミュレーション API
│   │   │   ├── material-service.ts     # 材料 API
│   │   │   ├── system-service.ts       # システム情報 API
│   │   │   └── websocket-service.ts    # WebSocket通信
│   │   ├── types/
│   │   │   ├── simulation.ts           # シミュレーション型定義
│   │   │   ├── materials.ts            # 材料型定義
│   │   │   ├── ui.ts                   # UI型定義
│   │   │   ├── api.ts                  # API型定義
│   │   │   └── common.ts               # 共通型定義
│   │   ├── lib/
│   │   │   ├── utils.ts                # ユーティリティ関数 (cn, clsx等)
│   │   │   ├── validations.ts          # Zodスキーマ定義
│   │   │   ├── constants.ts            # アプリケーション定数
│   │   │   ├── chart-utils.ts          # グラフユーティリティ
│   │   │   ├── file-utils.ts           # ファイル操作
│   │   │   └── format-utils.ts         # データフォーマット
│   │   └── contexts/                   # React Context
│   │       ├── SimulationContext.tsx
│   │       ├── MaterialContext.tsx
│   │       └── ThemeContext.tsx
│   ├── components.json              # shadcn/ui設定ファイル
│   └── public/
│       ├── images/
│       └── icons/
│
├── backend/                            # FastAPI バックエンド
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── pyproject.toml
│   ├── src/
│   │   ├── main.py                     # FastAPI アプリケーション
│   │   ├── config/
│   │   │   ├── __init__.py
│   │   │   ├── settings.py             # 設定管理
│   │   │   └── logging.py              # ログ設定
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── deps.py                 # 依存関係
│   │   │   ├── middleware.py           # ミドルウェア
│   │   │   └── routes/
│   │   │       ├── __init__.py
│   │   │       ├── simulation.py       # シミュレーション API
│   │   │       ├── materials.py        # 材料一覧 API
│   │   │       ├── health.py           # ヘルスチェック
│   │   │       └── admin.py            # 管理用 API
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── julia_runner.py         # Julia実行エンジン
│   │   │   ├── job_manager.py          # ジョブ管理
│   │   │   ├── result_processor.py     # 結果処理
│   │   │   └── file_manager.py         # ファイル管理
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   ├── simulation.py           # シミュレーション データモデル
│   │   │   ├── materials.py            # 材料 データモデル
│   │   │   ├── responses.py            # レスポンス モデル
│   │   │   └── enums.py                # 列挙型定義
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── simulation_service.py   # シミュレーション サービス
│   │   │   ├── material_service.py     # 材料 サービス
│   │   │   ├── validation_service.py   # バリデーション サービス
│   │   │   └── cache_service.py        # キャッシュ サービス
│   │   ├── utils/
│   │   │   ├── __init__.py
│   │   │   ├── exceptions.py           # カスタム例外
│   │   │   ├── helpers.py              # ヘルパー関数
│   │   │   └── constants.py            # 定数
│   │   └── tests/
│   │       ├── __init__.py
│   │       ├── conftest.py
│   │       ├── test_api/
│   │       ├── test_core/
│   │       └── test_services/
│   └── data/
│       ├── temp/                       # 一時ファイル
│       ├── results/                    # 計算結果
│       └── logs/                       # ログファイル
│
├── julia-engine/                       # Julia 計算エンジン
│   ├── Dockerfile
│   ├── Project.toml                    # Julia 依存関係
│   ├── Manifest.toml
│   ├── scripts/
│   │   ├── run_simulation.jl           # メイン実行スクリプト
│   │   ├── setup.jl                    # 環境設定
│   │   └── health_check.jl             # ヘルスチェック
│   ├── src/
│   │   ├── SimulationEngine.jl         # メインモジュール
│   │   ├── core/
│   │   │   ├── calculation_engine.jl   # 計算エンジン (transfer_in_media.jlベース)
│   │   │   ├── cell_manager.jl         # Cell構造体管理 (cell.jlベース)
│   │   │   ├── boundary_handler.jl     # 境界条件処理 (boundary_condition.jlベース)
│   │   │   ├── model_builder.jl        # モデル構築
│   │   │   └── time_integration.jl     # 時間積分
│   │   ├── materials/
│   │   │   ├── material_database.jl    # 材料データベース管理
│   │   │   ├── property_calculator.jl  # 物性値計算
│   │   │   └── properties/             # 材料物性定義 (既存material_propertyから移植)
│   │   │       ├── traditional/        # 伝統材料
│   │   │       │   ├── mud_wall.jl
│   │   │       │   ├── paper_washi.jl
│   │   │       │   └── tuff_motomachi.jl
│   │   │       ├── modern/             # 現代材料
│   │   │       │   ├── concrete_goran.jl
│   │   │       │   ├── glass_wool.jl
│   │   │       │   └── plywood.jl
│   │   │       └── special/            # 特殊材料
│   │   │           ├── liquid_water.jl
│   │   │           └── van_genuchten.jl
│   │   ├── models/
│   │   │   ├── simulation_1d.jl        # 1次元計算 (1D_calculationベース)
│   │   │   ├── simulation_3d.jl        # 3次元計算 (3D_calculationベース)
│   │   │   ├── simulation_network.jl   # ネットワーク計算 (network_calculationベース)
│   │   │   └── validation.jl           # 入力検証
│   │   ├── io/
│   │   │   ├── parameter_loader.jl     # パラメータ読み込み
│   │   │   ├── result_writer.jl        # 結果出力
│   │   │   ├── progress_reporter.jl    # 進捗報告
│   │   │   └── json_handler.jl         # JSON処理
│   │   └── utils/
│   │       ├── conversion.jl           # 単位変換・データ変換
│   │       ├── validation.jl           # バリデーション
│   │       ├── logger.jl               # ログ機能
│   │       └── error_handler.jl        # エラーハンドリング
│   ├── data/
│   │   ├── input/                      # 入力データ (既存input_dataから)
│   │   ├── output/                     # 出力データ
│   │   ├── temp/                       # 一時ファイル
│   │   └── examples/                   # サンプルデータ
│   └── test/
│       ├── unit/                       # 単体テスト
│       ├── integration/                # 結合テスト
│       └── benchmarks/                 # ベンチマーク
│
├── shared/                             # 共通設定・ドキュメント
│   ├── docker/
│   │   ├── docker-compose.dev.yml     # 開発環境用
│   │   ├── docker-compose.prod.yml    # 本番環境用
│   │   └── nginx/                      # リバースプロキシ設定
│   ├── scripts/
│   │   ├── setup.sh                   # 初期設定スクリプト
│   │   ├── start-dev.sh               # 開発環境起動
│   │   ├── test.sh                    # テスト実行
│   │   └── deploy.sh                  # デプロイスクリプト
│   └── docs/                          # 追加ドキュメント
│       ├── api/                       # API ドキュメント
│       ├── development/               # 開発ガイド
│       └── deployment/                # デプロイガイド
│
└── legacy/                            # 既存Juliaコード (参照用)
    ├── 1D_calculation.ipynb           # 既存ファイル (参照・テスト用)
    ├── 3D_calculation.ipynb
    ├── network_calculation.ipynb
    ├── module/                        # 既存モジュール (移植元)
    ├── input_data/                    # 既存入力データ (移植元)
    └── output_data/                   # 既存出力データ (検証用)
```

## 設計理念と特徴

### 1. 既存コードの最大活用
- **`legacy/`フォルダ**: 既存Juliaコードを参照用として保持
- **段階的移植**: `transfer_in_media.jl` → `calculation_engine.jl` など、機能ごとに移植
- **材料データベース**: 既存の40種類以上の材料物性をそのまま活用

### 2. 拡張性重視の設計
- **モジュラーアーキテクチャ**: 各機能が独立し、個別に拡張可能
- **計算モード対応**: 1D/3D/ネットワーク計算を統一的に管理
- **材料追加容易性**: 新材料の追加が簡単な構造

### 3. 開発効率の最適化
- **明確な責務分離**: フロントエンド/バックエンド/計算エンジンの独立性
- **型安全性**: TypeScript + Pydantic + Julia type annotations
- **テスト容易性**: 各層での単体・結合テストが可能

### 4. 運用・保守性
- **Docker化**: 全サービスのコンテナ化
- **ログ・監視**: 計算進捗とエラーの詳細な追跡
- **設定外部化**: 環境設定の柔軟な変更

## 実装優先順位（画面仕様書対応）

### Phase 1: 基盤構築・ホーム画面 (Week 1-2)
```
1. Docker環境構築 + CI/CD基盤
2. FastAPI基本構造 (backend/src/main.py + ヘルスチェック)
3. Julia計算エンジン基盤 (julia-engine/src/core/calculation_engine.jl)
4. Next.js基本構造 + ホーム画面 (frontend/src/app/page.tsx)
5. 基本UIコンポーネント (Button, Card, Input等)
6. システム情報画面
```

### Phase 2: 1D計算設定フロー (Week 3-4)
```
1. 1D計算設定 Step1-4の画面実装
   - frontend/src/app/calculation/1d/step1/page.tsx (基本設定)
   - frontend/src/app/calculation/1d/step2/page.tsx (材料選択)
   - frontend/src/app/calculation/1d/step3/page.tsx (境界条件)
   - frontend/src/app/calculation/1d/step4/page.tsx (確認・実行)
2. 材料データベースAPI実装 + 材料選択UI
3. フォーム状態管理 (useForm, validation)
4. StepProgress, MaterialSelector等の専用コンポーネント
```

### Phase 3: 計算実行・結果表示 (Week 5)
```
1. 計算進捗表示画面 (frontend/src/app/progress/[id]/page.tsx)
2. 結果表示画面 (frontend/src/app/results/[id]/page.tsx)
3. WebSocketベースの進捗監視
4. インタラクティブなグラフ表示
5. CSV/JSON出力機能
```

### Phase 4: 管理機能・最終調整 (Week 6)
```
1. シミュレーション履歴画面 (frontend/src/app/history/page.tsx)
2. 材料詳細画面 (frontend/src/app/materials/[id]/page.tsx)
3. エラーハンドリング強化
4. デモ用データ準備・学会発表対応
5. パフォーマンス最適化
```

## 技術選択の根拠

### 既存Juliaコード分析結果を基にした決定
1. **計算エンジン設計**: `transfer_in_media.jl`の優れた設計をそのまま活用
2. **材料データベース**: 既存の体系化された材料物性を効率的に活用
3. **境界条件処理**: 実用的な3種類の境界条件をAPI化
4. **入力データ形式**: CSV構造をJSONスキーマに自然に変換

### Web化に適した改善
1. **非同期処理**: 計算の長時間実行に対応
2. **状態管理**: 計算進捗の可視化
3. **エラーハンドリング**: ユーザーフレンドリーなエラー表示
4. **データ検証**: 入力パラメータの妥当性確認

### UI設計対応の最適化
1. **ステップ別画面構成**: 複雑な設定を4ステップに分割して使いやすさを向上
2. **shadcn/ui採用**: 高品質で一貫したUIコンポーネントライブラリ
3. **アーキテクチャ分離**: app/, components/, hooks/, services/, types/の明確な責務分離
4. **状態管理の階層化**: Global(Context) + Local(useState) + Server(API)の明確な分離
5. **ページ間遷移**: Next.js App Routerの機能を最大活用
6. **リアルタイム更新**: WebSocketとポーリングの適切な使い分け

## ディレクトリ構造の利点

### 開発効率
- **機能別分割**: 各画面が独立したディレクトリ構造
- **shadcn/ui統合**: 高品質なデザインシステムによる開発速度向上
- **アーキテクチャ分離**: hooks/, services/, types/の明確な分離による保守性向上
- **コンポーネント再利用**: ui/, forms/, visualization/での適切な分類
- **型安全性**: TypeScript型定義の体系的管理

### 保守性
- **責務分離**: フロントエンド/バックエンド/計算エンジンの独立性
- **拡張性**: 新しい計算タイプ(3D, network)の追加が容易
- **テスト容易性**: 各層での単体・結合テストが可能

### デプロイ・運用
- **Docker化**: 全サービスのコンテナ化
- **環境分離**: dev/prod環境の明確な分離
- **ログ・監視**: 計算進捗とエラーの詳細な追跡

この構造により、既存の高品質なJuliaコードを最大限活用しながら、画面仕様書で定義されたユーザー体験を実現するモダンなWebアプリケーションとして再構築できます。