# UI駆動開発プロセス

## 概要

**目的**: JSONダミーデータを活用したフロントエンド先行開発により、早期にUIイメージを確立し、ユーザビリティを検証する

**期間**: 1週間（7日間）  
**前提**: 画面仕様書・画面遷移図完成済み  
**成果物**: 全画面の動作するUIプロトタイプ

## 開発戦略

### なぜUI駆動開発なのか
1. **早期視覚化**: 学会発表用の具体的なイメージを即座に確認
2. **要件確認**: 実際のUIで操作性・情報設計を検証
3. **並行開発**: バックエンド開発と並行して進行可能
4. **リスク軽減**: UI/UX問題の早期発見・修正

### ダミーデータ活用方針
- **リアルなデータ**: 実際の材料名・物性値を使用
- **完全なフロー**: 全画面遷移を体験可能
- **エラーケース**: 正常系・異常系の両方を想定
- **レスポンシブ**: 実際のAPI応答時間をシミュレート

## 7日間開発プロセス

### Day 1: 環境構築・基盤整備

#### 作業内容 (8時間)
```bash
# 1. プロジェクト初期化 (1時間)
npx create-next-app@latest thermal-simulation-ui --typescript --tailwind --app
cd thermal-simulation-ui
npx shadcn-ui@latest init

# 2. 基本依存関係インストール (0.5時間)
npm install recharts axios react-hook-form zod @hookform/resolvers
npm install lucide-react class-variance-authority clsx tailwind-merge

# 3. shadcn/ui基本コンポーネント追加 (0.5時間)
npx shadcn-ui@latest add button input card form label progress table
npx shadcn-ui@latest add select dialog alert badge separator skeleton
```

#### ディレクトリ構築 (1時間)
```
src/
├── app/                     # Next.js App Router
├── components/ui/           # shadcn/ui (自動生成)
├── components/forms/        # フォームコンポーネント
├── components/visualization/ # グラフ・チャート
├── components/simulation/   # シミュレーション固有
├── components/shared/       # 共通コンポーネント
├── hooks/                   # カスタムフック
├── services/               # API モック
├── types/                  # TypeScript型定義
└── lib/                    # ユーティリティ
```

#### ダミーデータ作成 (4時間)
```typescript
// data/mock-materials.json - 材料データベース
[
  {
    "id": "mud_wall",
    "name": "土壁",
    "category": "traditional",
    "basic_properties": {
      "density": 1650,
      "thermal_conductivity": 0.23,
      "specific_heat": 900
    }
  }
  // 40種類の材料データ
]

// data/mock-simulations.json - シミュレーション履歴
[
  {
    "simulation_id": "sim_001",
    "name": "土壁の熱水分解析",
    "status": "completed",
    "created_at": "2024-01-13T10:30:00Z",
    "progress": 100
  }
  // 複数のシミュレーション例
]

// data/mock-results.json - 計算結果
{
  "time_series": [
    {
      "timestamp": "2024-01-01T00:00:00Z", 
      "positions": [
        {"x": 0.0, "temperature": 20.0, "relative_humidity": 0.6},
        {"x": 0.05, "temperature": 22.5, "relative_humidity": 0.65}
      ]
    }
    // 24時間分のデータ
  ]
}
```

#### 型定義作成 (1時間)
```typescript
// types/simulation.ts, materials.ts, common.ts
// 画面仕様書の型定義をそのまま実装
```

### Day 2: ホーム画面・レイアウト構築

#### 作業内容 (8時間)
1. **全体レイアウト** (2時間)
   - Header, Navigation, Breadcrumbs
   - レスポンシブ対応

2. **ホーム画面** (3時間)
   - アクションカード実装
   - システム状況表示
   - ダミーAPIとの連携

3. **共通コンポーネント** (2時間)
   - LoadingSpinner, StatusIndicator
   - ErrorBoundary実装

4. **ナビゲーション** (1時間)
   - 画面遷移の動作確認
   - パンくずリスト

#### 完成画面
- ✅ ホーム画面 (`/`)
- ✅ 基本レイアウト・ナビゲーション

### Day 3: 1D計算設定画面 (Step 1-2)

#### 作業内容 (8時間)
1. **Step 1: 基本設定** (4時間)
   - フォーム実装 (react-hook-form + zod)
   - バリデーション・エラー表示
   - ステップ進捗表示

2. **Step 2: 材料選択** (4時間)
   - 材料一覧・検索・フィルタ
   - 壁体層エディタ
   - 壁体断面図の可視化

#### ダミーAPI実装
```typescript
// services/mock-api.ts
export const mockMaterialService = {
  async getMaterials(filter?: string) {
    // 300ms遅延でリアルなAPI体験
    await delay(300);
    return mockMaterials.filter(/* filter logic */);
  }
};
```

#### 完成画面
- ✅ Step 1: 基本設定 (`/calculation/1d/step1`)
- ✅ Step 2: 材料選択 (`/calculation/1d/step2`)

### Day 4: 1D計算設定画面 (Step 3-4)

#### 作業内容 (8時間)
1. **Step 3: 境界条件** (4時間)
   - 室内外環境設定フォーム
   - 高度な設定の展開UI
   - 推奨値の自動設定

2. **Step 4: 確認・実行** (4時間)
   - 設定サマリー表示
   - 推定計算情報
   - バリデーション結果表示

#### 状態管理実装
```typescript
// hooks/use-form-state.ts
export const useCalculationForm = () => {
  // 4ステップ間でのデータ永続化
  // ローカルストレージ活用
};
```

#### 完成画面
- ✅ Step 3: 境界条件 (`/calculation/1d/step3`)
- ✅ Step 4: 確認・実行 (`/calculation/1d/step4`)

### Day 5: 計算進捗・結果表示画面

#### 作業内容 (8時間)
1. **計算進捗画面** (4時間)
   - リアルタイム進捗バー
   - ログ表示（WebSocketシミュレート）
   - 中断機能UI

2. **結果表示画面** (4時間)
   - インタラクティブグラフ (recharts)
   - データテーブル
   - エクスポート機能

#### リアルタイム機能シミュレート
```typescript
// hooks/use-websocket.ts (モック版)
export const useWebSocket = (url: string) => {
  // setIntervalで進捗更新をシミュレート
  // 3秒ごとに進捗+10%等
};
```

#### グラフ実装
```typescript
// components/visualization/TemperatureChart.tsx
// recharts使用、ズーム・パン機能付き
// 複数系列の同時表示
```

#### 完成画面
- ✅ 計算進捗表示 (`/progress/[id]`)
- ✅ 結果表示 (`/results/[id]`)

### Day 6: 管理画面・詳細機能

#### 作業内容 (8時間)
1. **シミュレーション履歴** (3時間)
   - 一覧表示・フィルタリング
   - ステータス別表示
   - 再実行・削除機能

2. **材料データベース** (3時間)
   - 材料一覧・詳細表示
   - カテゴリ別フィルタ
   - 物性値グラフ表示

3. **システム情報画面** (2時間)
   - システム状況表示
   - バージョン情報

#### 完成画面
- ✅ 履歴画面 (`/history`)
- ✅ 材料データベース (`/materials`, `/materials/[id]`)
- ✅ システム情報 (`/system`)

### Day 7: 統合・仕上げ・テスト

#### 作業内容 (8時間)
1. **画面間連携確認** (3時間)
   - 全画面遷移フローテスト
   - データの引き継ぎ確認
   - URL・ルーティング検証

2. **UI/UX改善** (3時間)
   - アニメーション・トランジション
   - ローディング状態の改善
   - エラーハンドリング強化

3. **レスポンシブ対応** (1時間)
   - モバイル・タブレット表示確認

4. **ドキュメント整備** (1時間)
   - README更新
   - コンポーネント使用方法

## 技術実装詳細

### モックAPI設計
```typescript
// services/mock-api.ts
export class MockApiService {
  // 実際のAPI仕様に準拠したモック
  // レスポンス遅延、エラーケースも含む
  
  async createSimulation(params: SimulationParams) {
    await this.delay(500);
    if (this.shouldSimulateError()) {
      throw new Error('計算パラメータに問題があります');
    }
    return { simulation_id: 'sim_' + Date.now() };
  }
}
```

### 状態管理戦略
```typescript
// 3層の状態管理
1. ローカル状態: useState (コンポーネント内)
2. フォーム状態: react-hook-form (フォーム全体)
3. グローバル状態: Context + localStorage (アプリ全体)
```

### コンポーネント設計原則
```typescript
// 1. 単一責任: 各コンポーネントは1つの役割
// 2. 再利用性: propsでカスタマイズ可能
// 3. テスト可能: 副作用を分離
// 4. アクセシビリティ: shadcn/uiベース
```

## 品質保証

### チェックリスト
- [ ] 全画面遷移が正常動作
- [ ] フォームバリデーションが適切
- [ ] エラーケースの表示が分かりやすい
- [ ] レスポンシブ表示が適切
- [ ] アクセシビリティ要件を満たす
- [ ] パフォーマンスが良好（3秒以内表示）

### ユーザビリティテスト観点
1. **直感性**: 初見でも操作方法が分かる
2. **効率性**: 目的の操作を素早く完了できる
3. **満足度**: ストレスなく利用できる
4. **エラー回復**: 間違った操作からの復旧が容易

## 次フェーズへの引き継ぎ

### 成果物
1. **動作するUIプロトタイプ**: 全画面完成
2. **コンポーネントライブラリ**: 再利用可能な部品
3. **モックAPIサービス**: バックエンド開発の仕様書
4. **ユーザビリティレポート**: 改善点の洗い出し

### バックエンド開発への要件
```typescript
// モックAPIから実APIへの移行要件
// 1. エンドポイント仕様の確定
// 2. レスポンス形式の統一
// 3. エラーレスポンスの標準化
// 4. 認証・権限の実装方針
```

このプロセスにより、1週間で完全に動作するUIプロトタイプが完成し、学会発表でのデモ準備とバックエンド開発の要件確定が同時に達成されます。