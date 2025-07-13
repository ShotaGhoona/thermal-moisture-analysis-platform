# 技術仕様書: 熱水分移動解析Webアプリケーション

## プロジェクト前提条件

### 開発環境・制約
- **開発者**: 個人開発（Next.js中級、FastAPI経験あり、Julia初心者）
- **動作環境**: ローカル環境のみ（インフラ不要）
- **コンテナ化**: Docker Compose で全サービス管理
- **利用目的**: 学会発表・教授への demo
- **ユーザー数**: 少数（スケーラビリティ不要）

### 優先順位
1. **計算精度**: 既存Juliaプログラムとの完全一致
2. **開発効率**: 最小限の工数で実用的なデモ作成
3. **保守性**: シンプルで理解しやすいアーキテクチャ

## システム構成

### 全体アーキテクチャ
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   フロントエンド   │    │   バックエンド    │    │  Julia Engine   │
│    (Next.js)    │◄──►│   (FastAPI)     │◄──►│   (計算実行)     │
│     Port:3000   │    │    Port:8000    │    │   (プロセス実行)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Docker Compose 構成
```yaml
# docker-compose.yml
version: '3.8'
services:
  frontend:
    build: ./frontend
    ports: 
      - "3000:3000"
    volumes:
      - ./frontend:/app
    
  backend:
    build: ./backend  
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
      - ./julia-engine:/julia-engine
    depends_on:
      - julia-engine
      
  julia-engine:
    build: ./julia-engine
    volumes:
      - ./julia-engine:/app
      - ./input_data:/app/input_data
      - ./output_data:/app/output_data
```

## フロントエンド仕様 (Next.js)

### 技術スタック
```typescript
// package.json
{
  "dependencies": {
    "next": "^14.0.0",
    "react": "^18.0.0", 
    "typescript": "^5.0.0",
    "tailwindcss": "^3.0.0",        // スタイリング
    "@radix-ui/react-*": "^1.0.0", // shadcn/ui基盤
    "class-variance-authority": "^0.7.0", // スタイル管理
    "clsx": "^2.0.0",               // クラス名結合
    "tailwind-merge": "^2.0.0",     // Tailwind結合
    "lucide-react": "^0.300.0",     // アイコン
    "recharts": "^2.8.0",           // グラフ表示
    "axios": "^1.6.0",              // API通信
    "react-hook-form": "^7.0.0",    // フォーム管理
    "zod": "^3.0.0",                // バリデーション
    "@hookform/resolvers": "^3.0.0" // React Hook Form + Zod
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/react": "^18.0.0",
    "@types/react-dom": "^18.0.0",
    "autoprefixer": "^10.0.0",
    "postcss": "^8.0.0"
  }
}
```

### ページ構成
```
frontend/src/
├── app/
│   ├── page.tsx                    # ホーム画面
│   ├── calculation/1d/
│   │   ├── step1/page.tsx         # 基本設定
│   │   ├── step2/page.tsx         # 材料選択
│   │   ├── step3/page.tsx         # 境界条件
│   │   └── step4/page.tsx         # 確認・実行
│   ├── progress/[id]/page.tsx     # 計算進捗表示
│   ├── results/[id]/page.tsx      # 結果表示
│   ├── history/page.tsx           # シミュレーション履歴
│   └── materials/page.tsx         # 材料データベース
├── components/
│   ├── ui/                        # shadcn/ui基本コンポーネント
│   │   ├── button.tsx
│   │   ├── input.tsx
│   │   ├── card.tsx
│   │   └── form.tsx
│   ├── forms/                     # フォーム関連
│   ├── visualization/             # グラフ・可視化
│   └── simulation/                # シミュレーション固有
├── hooks/
│   ├── use-simulation.ts          # シミュレーション管理
│   ├── use-materials.ts           # 材料データ管理
│   └── use-websocket.ts           # リアルタイム通信
├── services/
│   ├── api.ts                     # API通信関数
│   ├── simulation-service.ts      # シミュレーション操作
│   └── material-service.ts        # 材料操作
├── types/
│   ├── simulation.ts              # シミュレーション型
│   ├── materials.ts               # 材料型
│   └── common.ts                  # 共通型
└── lib/
    ├── utils.ts                   # ユーティリティ関数
    └── constants.ts               # 定数定義
```

### データ型定義
```typescript
// types/simulation.ts
interface SimulationParams {
  // 基本パラメータ
  roomTemp: number;        // 室温 [°C]
  outsideTemp: number;     // 外気温 [°C] 
  roomHumidity: number;    // 室内湿度 [%]
  outsideHumidity: number; // 外気湿度 [%]
  
  // 壁体設定
  wallMaterial: string;    // 材料名
  wallThickness: number;   // 厚さ [m]
  
  // 計算設定
  duration: number;        // 計算時間 [時間]
  timeStep: number;        // 時間刻み [秒]
}

interface SimulationResult {
  id: string;
  status: 'running' | 'completed' | 'error';
  progress: number;        // 進捗 0-100
  results?: {
    time: number[];        // 時間軸
    temperature: number[]; // 温度変化
    humidity: number[];    // 湿度変化
  };
  error?: string;
}
```

## バックエンド仕様 (FastAPI)

### 技術スタック
```python
# requirements.txt
fastapi==0.104.1
uvicorn==0.24.0
pydantic==2.5.0
python-multipart==0.0.6
aiofiles==23.2.1
pandas==2.1.4
```

### API エンドポイント
```python
# main.py
from fastapi import FastAPI, BackgroundTasks
from pydantic import BaseModel

app = FastAPI(title="熱水分移動解析API")

# POST /simulation/start - シミュレーション開始
@app.post("/simulation/start")
async def start_simulation(
    params: SimulationParams, 
    background_tasks: BackgroundTasks
):
    simulation_id = generate_id()
    background_tasks.add_task(run_julia_simulation, simulation_id, params)
    return {"simulation_id": simulation_id, "status": "started"}

# GET /simulation/{id}/status - 実行状況確認
@app.get("/simulation/{simulation_id}/status")
async def get_simulation_status(simulation_id: str):
    status = get_status_from_file(simulation_id)
    return {"id": simulation_id, "status": status, "progress": get_progress(simulation_id)}

# GET /simulation/{id}/result - 結果取得
@app.get("/simulation/{simulation_id}/result")
async def get_simulation_result(simulation_id: str):
    result = load_result_csv(simulation_id)
    return {"id": simulation_id, "results": result}

# GET /materials - 利用可能材料一覧
@app.get("/materials")
async def get_materials():
    return {"materials": ["mud_wall", "plywood", "concrete_goran", "glass_wool_16K"]}
```

### Julia実行処理
```python
# julia_runner.py
import subprocess
import json
import asyncio

async def run_julia_simulation(simulation_id: str, params: SimulationParams):
    """Juliaプロセスを実行してシミュレーションを行う"""
    
    # 1. パラメータファイル作成
    create_parameter_file(simulation_id, params)
    
    # 2. Julia実行
    command = [
        "julia", 
        "/julia-engine/run_simulation.jl",
        f"--id={simulation_id}",
        f"--params=/tmp/{simulation_id}_params.json"
    ]
    
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE,
        text=True
    )
    
    # 3. 進捗監視
    while process.poll() is None:
        update_progress(simulation_id)
        await asyncio.sleep(1)
    
    # 4. 結果処理
    if process.returncode == 0:
        convert_result_to_json(simulation_id)
        update_status(simulation_id, "completed")
    else:
        update_status(simulation_id, "error")
```

## Julia Engine 仕様

### ディレクトリ構成
```
julia-engine/
├── Dockerfile
├── Project.toml              # Julia依存関係
├── run_simulation.jl         # メイン実行スクリプト
├── src/
│   ├── simplified_1d.jl     # 簡略化1次元計算
│   ├── parameter_loader.jl   # パラメータ読み込み
│   └── result_writer.jl      # 結果出力
├── input_data/               # 入力データ（マウント）
└── output_data/              # 出力データ（マウント）
```

### メイン実行スクリプト
```julia
# run_simulation.jl
using ArgParse
using JSON
using Dates

include("src/simplified_1d.jl")
include("src/parameter_loader.jl") 
include("src/result_writer.jl")

function main()
    # コマンドライン引数解析
    args = parse_args()
    simulation_id = args["id"]
    params_file = args["params"]
    
    # パラメータ読み込み
    params = load_parameters(params_file)
    
    # 進捗ファイル初期化
    write_progress(simulation_id, 0)
    
    try
        # シミュレーション実行
        results = run_1d_simulation(params)
        
        # 進捗更新
        write_progress(simulation_id, 50)
        
        # 結果出力
        write_results(simulation_id, results)
        
        # 完了
        write_progress(simulation_id, 100)
        write_status(simulation_id, "completed")
        
    catch e
        write_status(simulation_id, "error")
        write_error(simulation_id, string(e))
    end
end

main()
```

### 簡略化1次元計算
```julia
# src/simplified_1d.jl
function run_1d_simulation(params)
    # 既存のJuliaコードを最小限に簡略化
    
    # 1. モジュール読み込み（必要最小限）
    include("../module/cell.jl")
    include("../module/air.jl") 
    include("../module/boundary_condition.jl")
    include("../module/transfer_in_media.jl")
    
    # 2. モデル構築
    wall = create_simple_wall(params)
    air_in, air_out = create_boundary_conditions(params)
    target_model = vcat(air_in, wall, air_out)
    
    # 3. 計算ループ
    results = run_calculation_loop(target_model, params)
    
    return results
end

function create_simple_wall(params)
    # パラメータから壁体を生成
    # 材料名、厚さ、初期条件を設定
end

function run_calculation_loop(target_model, params) 
    # 既存の計算ループを簡略化
    # 進捗更新を追加
end
```

## 開発フロー

### 開発環境構築
```bash
# 1. プロジェクト作成
mkdir thermal-simulation-web
cd thermal-simulation-web

# 2. Docker環境起動
docker-compose up -d

# 3. 開発開始
# フロントエンド: http://localhost:3000
# バックエンドAPI: http://localhost:8000/docs
```

### 段階的実装計画

#### Phase 1: 基本機能実装 (2週間)
- [ ] Docker環境構築
- [ ] FastAPI基本構造作成
- [ ] Next.js基本画面作成
- [ ] Julia簡易計算スクリプト作成
- [ ] API連携テスト

#### Phase 2: 機能拡張 (2週間)  
- [ ] パラメータ入力フォーム実装
- [ ] 計算進捗表示機能
- [ ] 結果グラフ表示機能
- [ ] エラーハンドリング強化

#### Phase 3: 完成・テスト (1週間)
- [ ] UI/UX改善
- [ ] 結果精度検証
- [ ] デモ用データ準備
- [ ] ドキュメント整備

## 技術的課題と対策

### Julia初心者への対策
```julia
# 既存コードの段階的理解
1. 単純な1次元計算から開始
2. 必要最小限のモジュールのみ使用
3. エラーハンドリングを充実
4. デバッグ用ログ出力を追加
```

### 開発効率化
- **Hot Reload**: フロントエンド・バックエンド共に開発時自動更新
- **API Doc**: FastAPIの自動ドキュメント生成活用
- **型安全**: TypeScript + Pydantic で型エラー事前検出

### デモ対応
- **サンプルデータ**: 事前に動作確認済みパラメータセット準備
- **エラー処理**: 想定外入力に対する適切なエラーメッセージ
- **レスポンス性**: 計算時間の可視化でユーザー体験向上

---

**この技術仕様は、あなたのスキルセットと制約条件に最適化されています。まずはPhase 1から段階的に実装していきましょう！**