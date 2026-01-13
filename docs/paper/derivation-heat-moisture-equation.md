# 熱水分同時移動方程式の導出と周波数応答解析

## 概要

本文書では、熱水分同時移動方程式から出発し、重み関数による変換、フーリエ変換を経て、鉾井先生の論文に登場する周波数応答式（式(6)）を導出する過程を、初学者にもわかるように丁寧に解説する。

---

## 目次

1. [熱水分同時移動の基礎方程式](#1-熱水分同時移動の基礎方程式)
2. [重み関数の概念と定義](#2-重み関数の概念と定義)
3. [収支式の重み関数による変換](#3-収支式の重み関数による変換)
4. [フーリエ変換による周波数領域への変換](#4-フーリエ変換による周波数領域への変換)
5. [連立方程式の解法と簡略化](#5-連立方程式の解法と簡略化)
6. [最終的な振幅減衰率の式の導出](#6-最終的な振幅減衰率の式の導出)
7. [記号一覧](#7-記号一覧)

---

## 1. 熱水分同時移動の基礎方程式

### 1.1 問題設定

建築材料は一般に多孔質材料であり、材料中での熱と水分は相互に影響し合う。この現象を定量的に解析するために熱水分同時移動方程式が用いられる。

### 1.2 水分収支式

材料中の水分の保存則（蓄積量＝正味流入量）より：

$$
\frac{\partial\{(\Phi_o - \psi)\rho_v + \rho_w\psi\}}{\partial t} = -\frac{\partial J_w}{\partial x}
$$

ここで：
- $\Phi_o$：絶乾時の材料の空隙率 [-]
- $\psi$：体積含水率 [m³/m³]
- $\rho_v$：水蒸気の密度 [kg/m³]
- $\rho_w$：液水の密度 [kg/m³]
- $J_w$：全水分流（気相＋液相）[kg/m²s]

### 1.3 熱収支式（エンタルピー収支式）

$$
c\rho \frac{\partial T}{\partial t} = -\frac{\partial q}{\partial x} + rW
$$

ここで：
- $c\rho$：材料のみかけの容積比熱 [J/m³K]
- $T$：温度 [K]
- $q$：熱流 [W/m²]
- $r$：水蒸気から液水への相変化熱 [J/kg]
- $W$：水蒸気から液水に相変化した水分量 [kg/m³s]

### 1.4 ハイグロスコピック領域での簡略化

蒸気拡散が支配的な領域（相対湿度95%以下）では、水分状態量として**絶対湿度 $X$** を用いることができ、方程式は以下のように簡略化される：

**水分収支式：**
$$
(\Phi_o \gamma' + \kappa)\frac{\partial X}{\partial t} - \nu \frac{\partial T}{\partial t} = \lambda'_x \frac{\partial^2 X}{\partial x^2} \tag{1}
$$

**熱収支式：**
$$
-\gamma\kappa \frac{\partial X}{\partial t} + (c\rho + r\nu)\frac{\partial T}{\partial t} = \lambda \frac{\partial^2 T}{\partial x^2} \tag{2}
$$

ここで：
- $\gamma'$：乾燥空気の密度 [kg/m³]
- $\kappa = \rho_w \left(\frac{\partial \psi}{\partial X}\right)_T$：絶対湿度に対する含水率変化
- $\nu = -\rho_w \left(\frac{\partial \psi}{\partial T}\right)_X$：温度に対する含水率変化
- $\lambda'_x$：湿気伝導率 [kg/ms(kg/kg')]
- $\lambda$：熱伝導率 [W/mK]

### 1.5 室内の熱水分収支式

室空間の絶対湿度 $X_r$、温度 $T_r$ に対する収支式：

**水分収支式：**
$$
\gamma_a V \frac{\partial X_r}{\partial t} + \gamma_a Vn(X_r - X_o) + \sum \alpha_{xi} S_i (X_r - X_{bi}) = W(t) \tag{3}
$$

**熱収支式：**
$$
c_a \gamma_a V \frac{\partial T_r}{\partial t} + c_a \gamma_a nV(T_r - T_o) + \sum \alpha_i S_i (T_r - T_{ai}) = H(t) \tag{4}
$$

ここで：
- $V$：室容積 [m³]
- $n$：換気回数 [1/h]
- $\gamma_a$：空気密度 [kg/m³]
- $S_i$：壁 $i$ の表面積 [m²]
- $\alpha_{xi}$：壁 $i$ の湿気伝達率 [kg/m²s(kg/kg')]
- $\alpha_i$：壁 $i$ の熱伝達率 [W/m²K]
- $X_o, T_o$：外気の絶対湿度・温度
- $X_{bi}, T_{ai}$：壁 $i$ の室内側表面の絶対湿度・温度
- $W(t)$：室内水分発生量 [kg/s]
- $H(t)$：室内熱発生量 [W]

---

## 2. 重み関数の概念と定義

### 2.1 重み関数とは何か

**重み関数**とは、システムの**インパルス応答**（瞬間的な入力に対する応答）を表す関数である。これを用いることで、任意の時変入力に対するシステムの応答を**畳み込み積分**によって計算できる。

### 2.2 単位応答と重み関数の定義

**単位応答 $\phi(t)$**：
- 単位ステップ入力（例：外気温度を1℃上げる）を与えた時の応答
- 時間とともにどのように変化するかを示す

**重み関数 $\psi(t)$**：
- 単位応答の時間微分
- 「少し前の温度（湿度）変化が、現在にどれだけ影響するか」を表す

$$
\psi(t) = \frac{d\phi(t)}{dt}
$$

### 2.3 畳み込み積分による応答の計算

外乱 $F(t)$ に対する応答（例：熱流 $q(t)$）は、重み関数との畳み込み積分で表される：

$$
q(t) = \int_0^{\infty} F(t - r) \psi(r) \, dr \tag{2-1}
$$

**物理的意味：**
- 過去の全ての時刻 $t-r$ における外乱 $F(t-r)$ が
- 重み関数 $\psi(r)$ という「影響の重み」を持って
- 現在の応答に寄与している

---

## 3. 収支式の重み関数による変換

### 3.1 壁体の水分・熱移動の重み関数表現

壁体を通じた水分・熱の移動を、重み関数を用いて表現する。壁における移動の重み関数を以下のように定義する：

| 重み関数 | 駆動力 | 物理的意味 |
|---------|--------|----------|
| $w_{11}$ | 室内絶対湿度 $X_r$ | 室内湿度変化による壁への水分流入 |
| $w_{12}$ | 室内温度 $T_r$ | 室内温度変化による壁への水分流入 |
| $w_{13}$ | 外気絶対湿度 $X_a$ | 外気湿度変化による壁からの水分流出 |
| $w_{14}$ | 外気温度 $T_a$ | 外気温度変化による壁からの水分流出 |

同様に、熱移動についても $H_X, H_T, K_X, K_T$ という重み関数を定義する。

### 3.2 壁体の室内側における水分移動

壁 $i$ の室内側における単位面積あたりの水分移動量は：

$$
\int_0^{\infty} w_{11}(r) X_r(t-r) \, dr + \int_0^{\infty} w_{12}(r) T_r(t-r) \, dr - \int_0^{\infty} w_{13}(r) X_a(t-r) \, dr - \int_0^{\infty} w_{14}(r) T_a(t-r) \, dr
$$

これは、湿気伝達による移動量 $\alpha_{xi}(X_r - X_{bi})$ に相当する。

### 3.3 水分収支式の重み関数表現

式(3)の水分収支式を変形する。

**Step 1：** 元の式を展開
$$
\gamma_a V \frac{dX_r}{dt} + \gamma_a Vn(X_r - X_o) + \sum \alpha_{xi} S_i (X_r - X_{bi}) = W(t)
$$

**Step 2：** 壁体との水分交換項を重み関数で表現

$\sum \alpha_{xi} S_i (X_r - X_{bi})$ の部分を重み関数表現に置き換えると：

$$
\gamma_a V \frac{dX_r}{dt} + \gamma_a VnX_r + \sum S_i \int_0^{\infty} w_{11}(r) X_r(t-r) \, dr + \sum S_i \int_0^{\infty} w_{12}(r) T_r(t-r) \, dr
$$
$$
= W(t) + \gamma_r VnX_0 + \sum S_i \int_0^{\infty} w_{13}(r) X_a(t-r) \, dr + \sum S_i \int_0^{\infty} w_{14}(r) T_a(t-r) \, dr
$$

### 3.4 熱収支式の重み関数表現

同様に、熱収支式も重み関数を用いて表現できる：

$$
c_a \gamma_r V \frac{dT_r}{dt} + \int_0^{\infty} H_X(\tau) X_r(t-\tau) \, d\tau + \int_0^{\infty} H_T(\tau) T_r(t-\tau) \, d\tau
$$
$$
= \int_0^{\infty} K_X(\tau) X_a(t-\tau) \, d\tau + \int_0^{\infty} K_T(\tau) T_a(t-\tau) \, d\tau + H(t)
$$

---

## 4. フーリエ変換による周波数領域への変換

### 4.1 なぜフーリエ変換を使うのか

時間領域での畳み込み積分は計算が複雑である。フーリエ変換を適用すると：

1. **時間微分** → **虚数単位 $j\omega$ との積**
2. **畳み込み積分** → **単純な積**

に変換され、代数方程式として解くことができる。

### 4.2 フーリエ変換の基本公式

**時間微分のフーリエ変換：**
$$
\mathcal{F}\left\{\frac{dX_r}{dt}\right\} = j\omega X_r(\omega)
$$

**畳み込み積分のフーリエ変換：**
$$
\mathcal{F}\left\{\int_0^{\infty} w_{11}(r) X_r(t-r) \, dr\right\} = W_{11}(\omega) X_r(\omega)
$$

ここで：
- $\mathcal{F}\{\cdot\}$：フーリエ変換
- $\omega$：角周波数 [rad/s]
- $j = \sqrt{-1}$：虚数単位
- $W_{11}(\omega)$：重み関数 $w_{11}(t)$ のフーリエ変換（伝達関数）

### 4.3 水分収支式のフーリエ変換

重み関数表現の水分収支式をフーリエ変換する：

$$
(j\omega\gamma_a V + \gamma_a Vn + S_1 W_{11}(\omega))X_r(\omega) + S_1 W_{12}(\omega)T_r(\omega) = \gamma_a Vn X_0(\omega) + W(\omega)
$$

**等価外乱湿度 $\bar{X}_0$ の導入：**

右辺をまとめて等価外乱湿度として定義する：
$$
\gamma_a Vn X_0(\omega) + W(\omega) = \gamma_a Vn \bar{X}_0(\omega) \tag{6}
$$

これにより、水分収支式は：
$$
(j\omega\gamma_a V + \gamma_a Vn + S_1 W_{11}(\omega))X_r(\omega) + S_1 W_{12}(\omega)T_r(\omega) = \gamma_a Vn \bar{X}_0(\omega) \tag{7}
$$

### 4.4 熱収支式のフーリエ変換

同様に熱収支式をフーリエ変換する：
$$
S_1 W_{21}(\omega) X_r(\omega) + (j\omega c_a\gamma_v V + c_a\gamma_v Vn + S_1 W_{22} + S_2 W'_{22})T_r(\omega) = 0 \tag{8}
$$

**注：** ここでは温度外乱の影響を考慮しない（$T_a = 0$）場合を考えている。

---

## 5. 連立方程式の解法と簡略化

### 5.1 連立方程式の整理

式(7)と式(8)は、$X_r(\omega)$ と $T_r(\omega)$ に関する連立方程式である：

$$
\begin{cases}
(j\omega\gamma_a V + \gamma_a Vn + S_1 W_{11})X_r + S_1 W_{12} T_r = \gamma_a Vn \bar{X}_0 \\
S_1 W_{21} X_r + (j\omega c_a\gamma_v V + c_a\gamma_v Vn + S_1 W_{22} + S_2 W'_{22})T_r = 0
\end{cases}
$$

### 5.2 $T_r$ を消去して $X_r$ の式を得る

クラメルの公式または代入法により、$T_r$ を消去すると：

$$
\frac{X_r}{\bar{X}_0} = \frac{j\omega c_a\gamma_a V + c_a\gamma_a Vn + S_1 W_{22} + S_2 W_{22}}{(j\omega\gamma_a V + \gamma_a Vn + S_1 W_{11})(j\omega c_a\gamma_a V + c_a\gamma_a Vn + S_1 W_{22} + S_2 W_{22}) - S_1^2 W_{12} W_{21}} \tag{9}
$$

### 5.3 近似による簡略化

#### 近似1：熱と水分のカップリングを無視

温度外乱の影響と熱水分の相互連携を無視すると、$W_{12}, W_{21} \approx 0$ となり：

$$
\frac{X_r}{\bar{X}_0} = \frac{\gamma_a Vn}{j\omega\gamma_a V + \gamma_a Vn + S_1 W_{11}(\omega)} \tag{10}
$$

#### 近似2：材料を半無限体として扱う

壁材料を半無限体（厚さ無限大）として扱うと、伝達関数 $W_{11}(\omega)$ は解析的に求まる：

$$
W_{11}(\omega) = \frac{1}{\frac{1}{\alpha'_i} + \frac{1-j}{\lambda'}\sqrt{\frac{a'}{2\omega}}} \tag{11}
$$

ここで：
- $\alpha'_i$：表面湿気伝達率 [kg/m²s(kg/kg')]
- $\lambda'$：材料の湿気伝導率 [kg/ms(kg/kg')]
- $a'$：材料の湿気拡散率 [m²/s]

### 5.4 記号の整理

計算を見通しよくするため、以下の記号を導入する：

$$
R = \frac{1}{\alpha'_i}, \quad A' = \frac{1}{\lambda'}\sqrt{a'}, \quad Z = \frac{A'}{\sqrt{2\omega}}
$$

これにより、$W_{11}(\omega)$ は：

$$
W_{11}(\omega) = \frac{R + Z}{R^2 + 2RZ + 2Z^2} + j\frac{Z}{R^2 + 2RZ + 2Z^2} \tag{12}
$$

**導出の詳細：**

式(11)の分母を整理する：
$$
\frac{1}{\alpha'_i} + \frac{1-j}{\lambda'}\sqrt{\frac{a'}{2\omega}} = R + (1-j)Z
$$

複素数の逆数を計算するため、分母分子に共役複素数を掛ける：
$$
\frac{1}{R + (1-j)Z} = \frac{R + (1+j)Z}{(R + (1-j)Z)(R + (1+j)Z)}
$$

分母を展開：
$$
(R + (1-j)Z)(R + (1+j)Z) = R^2 + R(1+j)Z + R(1-j)Z + (1-j)(1+j)Z^2
$$
$$
= R^2 + 2RZ + 2Z^2
$$

よって：
$$
W_{11}(\omega) = \frac{R + Z + jZ}{R^2 + 2RZ + 2Z^2} = \frac{R + Z}{R^2 + 2RZ + 2Z^2} + j\frac{Z}{R^2 + 2RZ + 2Z^2}
$$

---

## 6. 最終的な振幅減衰率の式の導出

### 6.1 式(10)の変形

式(10)に式(12)を代入して整理する。

**Step 1：** 式(10)の分母を $D(\omega)$ とおく

$$
D(\omega) = j\omega\gamma_a V + \gamma_a Vn + S_1 W_{11}(\omega)
$$

**Step 2：** $W_{11}(\omega)$ を代入

$$
D(\omega) = j\omega\gamma_a V + \gamma_a Vn + S_1 \left\{\frac{R + Z}{R^2 + 2RZ + 2Z^2} + j\frac{Z}{R^2 + 2RZ + 2Z^2}\right\}
$$

**Step 3：** $D(\omega)$ を分子の $\gamma_a Vn$ で割った $\tilde{D}(\omega)$ を計算

$$
\tilde{D}(\omega) = \frac{D(\omega)}{\gamma_a Vn}
$$

$$
= \frac{1}{\gamma_a Vn}(\gamma_a Vn + S_1 \frac{R + Z}{R^2 + 2RZ + 2Z^2}) + j\frac{1}{\gamma_a Vn}(\omega\gamma_a V + S_1 \frac{Z}{R^2 + 2RZ + 2Z^2})
$$

**Step 4：** パラメータ $B$ を導入

$$
B = \frac{S_1}{\gamma_a Vn}
$$

これにより：
$$
\tilde{D}(\omega) = \left[1 + B\frac{R + Z}{R^2 + 2RZ + 2Z^2}\right] + j\left[\frac{\omega}{n} + B\frac{Z}{R^2 + 2RZ + 2Z^2}\right]
$$

### 6.2 振幅減衰率の計算

伝達関数の絶対値の2乗は：
$$
\left|\frac{X_r}{\bar{X}_0}\right|^2 = \left|\frac{1}{\tilde{D}(\omega)}\right|^2
$$

複素数 $a + jb$ に対して $|a + jb|^2 = a^2 + b^2$ であるから：

$$
\left|\frac{X_r}{\bar{X}_0}\right|^2 = \frac{1}{\left[1 + B\frac{R + Z}{R^2 + 2RZ + 2Z^2}\right]^2 + \left[\frac{\omega}{n} + B\frac{Z}{R^2 + 2RZ + 2Z^2}\right]^2}
$$

### 6.3 元の記号に戻す

$R, Z$ を元の物性値で表すと $Z = A'/\sqrt{2\omega}$ であるから：

$$
\boxed{
\left|\frac{X_r}{X_0}\right|^2 = \frac{1}{\left[1 + B\frac{r'_i + A'/\sqrt{2\omega}}{(r'_i + A'/\sqrt{2\omega})^2 + (A'/\sqrt{2\omega})^2}\right]^2 + \left[\frac{\omega}{n} + B\frac{A'/\sqrt{2\omega}}{(r'_i + A'/\sqrt{2\omega})^2 + (A'/\sqrt{2\omega})^2}\right]^2}
} \tag{13}
$$

ここで $r'_i = 1/\alpha'_i$（表面湿気抵抗）である。

**これが鉾井先生の論文における式(6)に対応する振幅減衰率の式である。**

### 6.4 式の物理的解釈

この式は、外気湿度変動 $X_0$ に対する室内湿度 $X_r$ の応答を周波数領域で表している：

1. **$|X_r/X_0|^2$**：振幅減衰率の2乗
   - 1に近いほど外気変動がそのまま室内に伝わる
   - 0に近いほど外気変動が減衰される（調湿効果が高い）

2. **パラメータ $B = S_1/(\gamma_a Vn)$**：
   - 壁面積 $S_1$ と換気量 $\gamma_a Vn$ の比
   - $B$ が大きいほど壁体の調湿効果が支配的

3. **周波数 $\omega$ への依存性**：
   - 高周波（短周期変動）：壁体の蓄湿効果により減衰が大きい
   - 低周波（長周期変動）：換気による影響が支配的

---

## 7. 記号一覧

### 基本物性

| 記号 | 意味 | 単位 |
|------|------|------|
| $X$ | 絶対湿度 | kg/kg' |
| $T$ | 温度 | K または ℃ |
| $\psi$ | 体積含水率 | m³/m³ |
| $\lambda$ | 熱伝導率 | W/mK |
| $\lambda'$ | 湿気伝導率 | kg/ms(kg/kg') |
| $a'$ | 湿気拡散率 | m²/s |
| $c\rho$ | 容積比熱 | J/m³K |
| $\rho_w$ | 液水密度 | kg/m³ |
| $\gamma_a$ | 空気密度 | kg/m³ |

### 境界条件関連

| 記号 | 意味 | 単位 |
|------|------|------|
| $\alpha$ | 熱伝達率 | W/m²K |
| $\alpha'_i$ | 湿気伝達率 | kg/m²s(kg/kg') |
| $r'_i = 1/\alpha'_i$ | 表面湿気抵抗 | m²s(kg/kg')/kg |

### 室・壁体関連

| 記号 | 意味 | 単位 |
|------|------|------|
| $V$ | 室容積 | m³ |
| $S_i$ | 壁面積 | m² |
| $n$ | 換気回数 | 1/h |
| $W(t)$ | 室内水分発生量 | kg/s |
| $H(t)$ | 室内熱発生量 | W |

### フーリエ変換関連

| 記号 | 意味 | 単位 |
|------|------|------|
| $\omega$ | 角周波数 | rad/s |
| $j$ | 虚数単位 ($\sqrt{-1}$) | - |
| $W_{11}(\omega)$ | 重み関数の伝達関数 | - |
| $\bar{X}_0$ | 等価外乱湿度 | kg/kg' |

### 導出で用いた補助記号

| 記号 | 定義 | 意味 |
|------|------|------|
| $R$ | $1/\alpha'_i$ | 表面湿気抵抗 |
| $A'$ | $\sqrt{a'}/\lambda'$ | 材料の湿気特性 |
| $Z$ | $A'/\sqrt{2\omega}$ | 周波数依存の湿気特性 |
| $B$ | $S_1/(\gamma_a Vn)$ | 壁面積と換気の比 |

---

## 参考文献

1. 鉾井修一, 吸放湿材の評価法 - 外乱の変動と吸放湿特性 -, 日本建築学会第26回熱シンポジウム, pp63-72, (1996)
2. 小椋大輔, 松下敬幸, 周期的定常解析による壁体の調湿効果の簡易評価, 日本建築学会大会学術講演梗概集, (2001)
3. 松本衛ほか, 新建築学大系 10 環境物理, 彰国社, (1983)
4. 長谷川房雄, 半無限固体を含む多層壁の熱湿気移動, 日本建築学会東北支部, pp277-280, (1984)
