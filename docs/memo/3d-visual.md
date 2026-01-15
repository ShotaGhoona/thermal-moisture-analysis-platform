本日話していた3次元でのプロットの件ですが、参考までにコードを送っておきますね。
import numpy as np
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit

# ===== 入力データ =====
y = np.array([0, 0.213556, 0.433302, 0.680904])  # 比面積
x = np.array([0.0, 0.11, 0.25, 0.5, 0.75, 1.0])

Z = np.array([
    [0.027149933, 0.090114797, 0.156368177, 0.236211931, 0.284150632, 0.314855486],
    [0.024756232, 0.075291437, 0.131873582, 0.204709403, 0.251972706, 0.284070899],
    [0.023281238, 0.064930863, 0.114065927, 0.180241599, 0.225816233, 0.258097391],
    [0.022329834, 0.056740819, 0.099551931, 0.159296876, 0.202476999, 0.234185484]
])

# ===== 点群化 =====
Xg, Yg = np.meshgrid(x, y)
X = Xg.ravel()
Y = Yg.ravel()
Zr = Z.ravel()

# ===== 修正指数飽和型モデル（オフセット付き）=====
def exp_saturation_offset(XY, C, A, k, m):
    x, y = XY
    return (C + A * (1 - np.exp(-k * x))) * np.exp(-m * y)

# ===== フィッティング =====
initial_guess = [0.4, 5.5, 2.0, 1.0]  # C, A, k, m
params, _ = curve_fit(
    exp_saturation_offset,
    (X, Y),
    Zr,
    p0=initial_guess,
    bounds=(0, np.inf)
)

C, A, k, m = params

print(f"C = {C:.4f}, A = {A:.4f}, k = {k:.4f}, m = {m:.4f}")

# ===== フィッティング値（観測点上）=====
Z_fit = exp_saturation_offset((X, Y), C, A, k, m)

# ===== 絶対パーセント誤差（APE, %）=====
# 念のため Zr = 0 を除外（今回は不要だが汎用性のため）
mask = Zr != 0
APE = np.full_like(Zr, np.nan, dtype=float)
APE[mask] = np.abs((Z_fit[mask] - Zr[mask]) / Zr[mask]) * 100

# ===== 絶対平均パーセント誤差（MAPE, %）=====
MAPE = np.nanmean(APE)

print(f"MAPE = {MAPE:.2f} %")

# ===== 近似面作成 =====
x_fit = np.linspace(x.min(), x.max(), 60)
y_fit = np.linspace(y.min(), y.max(), 60)
Xf, Yf = np.meshgrid(x_fit, y_fit)

Zf = exp_saturation_offset((Xf, Yf), C, A, k, m)

# ===== プロット =====
plt.rcParams['font.size'] = 12
fig = plt.figure(figsize=(8, 7), dpi=300)
ax = fig.add_subplot(111, projection='3d')

# 入力データ（点）
ax.scatter(
    Xg, Yg, Z,
    color='black',
    s=50,
    label='Input data'
)

# 近似面（指数飽和）
ax.plot_surface(
    Xf, Yf, Zf,
    color='gray',
    alpha=0.4,
    edgecolor='none'
)

# ===== 軸ラベル =====
ax.set_xlabel('Ventilation rate (1/h)', labelpad=12)
ax.set_ylabel(r'Specific area (m$^2$/m$^3$)', labelpad=12)
#ax.set_zlabel('Reduction rate', labelpad=12, rotation=90)

# 軸範囲
ax.set_xlim(0, 1)
ax.set_ylim(0, 0.7)
ax.set_zlim(0, 0.3)

# y軸を100刻みにする
ax.set_xticks(np.linspace(0, 1, 6))
ax.set_yticks(np.arange(0, 0.701, 0.1))
ax.set_zticks(np.arange(0, 0.301, 0.1))

# 右側に z 軸ラベルを手動配置
ax.text2D(
    -0.05, 0.5,                     # ← 右側に配置（1.0 超え）
    "Amplitude ratio", # "Reduction rate",
    transform=ax.transAxes,
    rotation=92,                  # 縦向き
    va='center',
    ha='center',
    fontsize=12
)

# ===== ワイヤーフレーム =====
ax.plot_wireframe(
    Xg, Yg, Z,          # ← X, Y ではなく Xg, Yg
    color='black',
    linewidth=1.0
)

# ===== 数値ラベル（有効数字3桁相当）=====
for i in range(len(y)):
    for j in range(len(x)):
        ax.text(
            Xg[i, j],          # ← 修正
            Yg[i, j] - 0.01,          # ← 修正
            Z[i, j] + 0.012,
            f"{Z[i, j]:.2g}",
            ha='center',
            va='bottom',
            fontsize=14
        )

# 視点
ax.view_init(elev=25, azim=225)

plt.show()