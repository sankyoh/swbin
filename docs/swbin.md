# swbin.ado マニュアル（v1.2.0）⚖️

`swbin` は、二値曝露・二値治療に対する **Stabilized Weight（安定化重み）** を、Stataでワンコマンド作成するためのユーザー定義コマンドです。  
分母モデル `P(A=1|L)` は `logit`、`probit`、または **Firthロジスティック + 切片補正（FLIC）** で推定でき、分子モデル `P(A=1)` は常に切片のみの通常ロジスティック回帰で推定します。

---

## 0. 目的と特徴（Overview）

- ✅ 二値曝露・二値治療に対する Stabilized Weight を作成
- ✅ 分母傾向スコア `P(A=1|L)` を変数として保存
- ✅ 分子確率 `P(A=1)` を変数として保存
- ✅ Stabilized Weight を変数として保存
- ✅ `if` / `in` に対応
- ✅ Factor-variable notation（例：`i.sex`, `c.age##c.age`）に対応
- ✅ 分母モデルは `method()` で選択可能
  - `method(logit)`：通常のロジスティック回帰
  - `method(probit)`：プロビット回帰
  - `method(firthlogit)`：Firthロジスティック + FLIC
- ✅ 曝露変数が **0/1の二値変数** か事前チェック
- ✅ 出力変数名の重複を事前チェック
- ✅ 既存変数は `replace` オプションがない限り上書き禁止
- ✅ 推定失敗・非収束・不正な予測確率を検出して停止
- ✅ 重みの欠損数、平均、最小値、最大値、曝露群別要約を表示

---

## 1. 動作要件（Requirements）

- Stata 16 以上
  - `swbin.ado` 内で `version 16.0` を指定しています。
- `swbin.ado` が ado パス（例：`PERSONAL`）に配置されていること
- `method(firthlogit)` を使う場合のみ、外部コマンド `firthlogit` が必要

`firthlogit` を使う場合は、事前にインストールしてください。

~~~stata
ssc install firthlogit
~~~

---

## 2. インストール（Installation）

1) nte install

下記のコマンドを実行します。

~~~stata
net install swbin, from("https://raw.githubusercontent.com/sankyoh/swbin/main/stata") replace
~~~

2) 読み込み確認を行います。

~~~stata
which swbin
~~~

`method(firthlogit)` を使う予定がある場合は、こちらも確認します。

~~~stata
which firthlogit
~~~

インストールされていなければ、firthlogitをインストールしてください。

~~~stata
ssc install firthlogit
~~~

---

## 3. コマンド仕様（AI-readable spec）🤖

~~~yaml
command: swbin
version: 1.2.0
purpose: "Create stabilized weights for binary treatment/exposure"
syntax: "swbin exposure covariates [if] [in], sw(newvar) [psden(newvar) psnum(newvar) method(logit|probit|firthlogit) replace]"
inputs:
  exposure: "binary numeric variable coded 0/1; first variable in varlist"
  covariates: "variables for denominator treatment/exposure model; factor-variable notation allowed"
required_options:
  sw: "name of variable to store stabilized weight"
optional_options:
  psden: "name of denominator propensity score variable; default = ps_den"
  psnum: "name of numerator probability variable; default = ps_num"
  method: "denominator model method; default = logit; allowed = logit, probit, firthlogit"
  replace: "overwrite existing output variables"
sample_definition:
  - "marksample is used"
  - "if/in restrictions are respected"
  - "observations with missing exposure or missing covariates are excluded from the initial analysis sample"
denominator_model:
  logit: "logit exposure covariates"
  probit: "probit exposure covariates"
  firthlogit: "firthlogit exposure covariates followed by FLIC intercept correction"
numerator_model:
  method: "intercept-only logit"
  note: "Always standard logit, even when method(firthlogit) is specified"
outputs:
  - "denominator propensity score variable"
  - "numerator probability variable"
  - "stabilized weight variable"
prechecks:
  - "method() must be logit, probit, or firthlogit"
  - "output variable names must be distinct"
  - "output variable names cannot equal the exposure variable"
  - "existing output variables require replace"
  - "firthlogit must be installed when method(firthlogit) is used"
  - "exposure variable must be numeric"
  - "exposure variable must contain only 0 and 1 in the analysis sample"
  - "both exposure levels 0 and 1 must be present"
  - "model convergence is checked when e(converged) is available"
  - "predicted probabilities must be non-missing and inside the open interval (0, 1)"
display:
  - "analysis sample N"
  - "denominator model N"
  - "final weighted N"
  - "missing SW in full data"
  - "missing SW in analysis sample"
  - "FLIC calibration check when method(firthlogit) is used"
  - "overall SW mean/min/max"
  - "SW summary by exposure group"
stored_results:
  scalars:
    - r(N_initial)
    - r(N_denominator)
    - r(N_final)
    - r(N_missing_all)
    - r(N_missing_analysis_sample)
    - r(sw_mean)
    - r(sw_min)
    - r(sw_max)
    - r(trt_mean_den), only when method(firthlogit)
    - r(psden_mean_flic), only when method(firthlogit)
  locals:
    - r(exposure)
    - r(covariates)
    - r(method)
    - r(den_method)
    - r(num_method)
    - r(psden)
    - r(psnum)
    - r(sw)
limitations:
  - "binary exposure/treatment only"
  - "baseline/single-time treatment only"
  - "no built-in trimming or truncation"
  - "no built-in balance diagnostics"
  - "no support for Stata weight syntax in the propensity score model"
~~~

---

## 4. 基本構文（Syntax）

~~~stata
swbin exposure covariates [if] [in], ///
    sw(new_weight_var) ///
    [ psden(new_ps_den_var) ///
      psnum(new_ps_num_var) ///
      method(logit|probit|firthlogit) ///
      replace ]
~~~

### 引数（必須）

- `exposure`
  - 最初に指定する変数
  - 0/1でコード化された二値曝露・二値治療変数
  - 数値変数である必要があります。

- `covariates`
  - 分母モデル `P(A=1|L)` に入れる共変量リスト
  - `i.sex`、`i.hosp`、`c.age##c.age` などの factor-variable notation が使えます。

- `sw()`
  - 作成する Stabilized Weight 変数名
  - 必須オプションです。

### 引数（任意）

- `psden()`
  - 分母モデルの予測確率 `P(A=1|L)` を保存する変数名
  - 省略時は `ps_den`

- `psnum()`
  - 分子モデルの予測確率 `P(A=1)` を保存する変数名
  - 省略時は `ps_num`

- `method()`
  - 分母モデルの推定方法
  - 省略時は `method(logit)`
  - 指定可能な値は `logit`、`probit`、`firthlogit`

- `replace`
  - 既存の `psden()`、`psnum()`、`sw()` 変数を削除して再作成します。
  - 指定しない場合、同名変数が既に存在するとエラーで停止します。

---

## 5. 作成される重み（Formula）

曝露変数を `A`、共変量を `L` とすると、`swbin` は次の Stabilized Weight を作成します。

\[
SW_i =
\begin{cases}
\dfrac{P(A=1)}{P(A=1|L)} & A_i = 1 \\
\dfrac{P(A=0)}{P(A=0|L)} & A_i = 0
\end{cases}
\]

Stataコードとしては、概念的に次と同じです。

~~~stata
replace sw = ps_num / ps_den if exposure == 1
replace sw = (1 - ps_num) / (1 - ps_den) if exposure == 0
~~~

ここで：

- `ps_den` は分母モデルによる `P(A=1|L)`
- `ps_num` は分子モデルによる `P(A=1)`
- `sw` は Stabilized Weight

---

## 6. 分母モデルと分子モデルの扱い

### 6.1 分母モデル：`P(A=1|L)`

`method()` で指定したモデルを使います。

~~~stata
method(logit)      // logit exposure covariates
method(probit)     // probit exposure covariates
method(firthlogit) // firthlogit exposure covariates + FLIC
~~~

### 6.2 分子モデル：`P(A=1)`

分子モデルは、常に切片のみの通常ロジスティック回帰です。

~~~stata
logit exposure
predict ps_num, pr
~~~

切片のみの通常ロジスティック回帰では、予測確率は推定サンプル内の曝露割合と一致します。  
そのため、`method(firthlogit)` を指定した場合でも、分子モデルにはFirth補正を使いません。

---

## 7. FLICの扱い：`method(firthlogit)` 🧪

`method(firthlogit)` を指定した場合、分母モデル `P(A=1|L)` だけを **Firthロジスティック + FLIC** で推定します。

FLICは、Firthロジスティックで推定した傾き係数を固定し、切片だけを通常の最尤法で補正する方法です。  
`swbin` では、概念的に以下の手順を実行します。

~~~stata
* 1) Firth logistic regression
firthlogit exposure covariates

* 2) Linear predictor from Firth model
predict xb_firth, xb

* 3) Remove Firth intercept
gen eta_firth = xb_firth - _b[_cons]

* 4) Re-estimate intercept only by ML with offset
logit exposure, offset(eta_firth) nolog
scalar gamma0 = _b[_cons]

* 5) FLIC predicted probability
gen ps_den = invlogit(eta_firth + gamma0)
~~~

### FLICチェック

`method(firthlogit)` の場合、結果表示に以下が追加されます。

~~~text
FLIC check: observed Pr(exposure=1), denominator sample : ...
FLIC check: mean FLIC denominator PS                 : ...
~~~

この2つがほぼ一致していることを確認します。

---

## 8. 事前チェック（Validation rules）✅

`swbin` は、以下の条件を満たさない場合にエラーで停止します。

### 8.1 `method()` が不正

許可されるのは以下のみです。

~~~stata
method(logit)
method(probit)
method(firthlogit)
~~~

### 8.2 出力変数名が重複

次の3つはすべて異なる変数名である必要があります。

~~~stata
psden()
psnum()
sw()
~~~

NG例：

~~~stata
swbin trt age sex, psden(ps) psnum(ps) sw(sw)
~~~

### 8.3 出力変数名が曝露変数名と同じ

NG例：

~~~stata
swbin trt age sex, sw(trt)
~~~

### 8.4 既存変数があるが `replace` がない

既に `ps_den`、`ps_num`、`sw` などが存在する場合、`replace` なしでは停止します。

~~~stata
swbin trt age sex, sw(sw)
~~~

上書きしたい場合：

~~~stata
swbin trt age sex, sw(sw) replace
~~~

### 8.5 曝露変数が数値変数ではない

曝露変数は数値変数である必要があります。

### 8.6 曝露変数が0/1ではない

解析対象内で、曝露変数に0/1以外の値があると停止します。

NG例：

~~~text
0, 1, 2
1, 2
0, 1, 9
~~~

### 8.7 曝露変数に0と1の両方が存在しない

解析対象内で全例0、または全例1の場合は停止します。

NG例：

~~~text
0 のみ
1 のみ
~~~

### 8.8 モデルが推定できない・収束しない

分母モデル、分子モデル、FLICの切片補正モデルで推定失敗または非収束が検出された場合は停止します。

### 8.9 予測確率が不正

以下のいずれかがある場合、Stabilized Weight は安全に計算できないため停止します。

- `ps_den` が欠損
- `ps_num` が欠損
- `ps_den <= 0`
- `ps_den >= 1`
- `ps_num <= 0`
- `ps_num >= 1`

---

## 9. 出力（Output）

### 9.1 作成される変数

既定では、以下の3変数が作成されます。

| 変数名 | 内容 |
|---|---|
| `ps_den` | 分母傾向スコア `P(A=1|L)` |
| `ps_num` | 分子確率 `P(A=1)` |
| `sw` | Stabilized Weight |

変数名はオプションで変更できます。

~~~stata
swbin trt age i.sex x1 x2, ///
    psden(ps_d) ///
    psnum(ps_n) ///
    sw(ipw)
~~~

### 9.2 表示される結果

実行後、以下が表示されます。

- 曝露変数名
- 共変量リスト
- 分母モデルの方法
- 分子モデルの方法
- 作成した変数名
- 初期解析サンプル数
- 分母モデルサンプル数
- 最終重み付きサンプル数
- Stabilized Weightの欠損数
- Stabilized Weightの平均、最小値、最大値
- 曝露群別のStabilized Weight要約

`method(firthlogit)` の場合は、FLICチェックも表示されます。

---

## 10. Stored results（戻り値）

`swbin` は `rclass` プログラムです。実行後に `return list` で確認できます。

~~~stata
return list
~~~

### 10.1 Scalars

| 戻り値 | 内容 |
|---|---|
| `r(N_initial)` | 初期解析サンプル数 |
| `r(N_denominator)` | 分母モデルサンプル数 |
| `r(N_final)` | 最終重み付きサンプル数 |
| `r(N_missing_all)` | 全データ内でのSW欠損数 |
| `r(N_missing_analysis_sample)` | 解析対象内でのSW欠損数 |
| `r(sw_mean)` | SW平均 |
| `r(sw_min)` | SW最小値 |
| `r(sw_max)` | SW最大値 |
| `r(trt_mean_den)` | 分母モデルサンプル内の曝露割合。`method(firthlogit)` のみ |
| `r(psden_mean_flic)` | FLIC後の分母PS平均。`method(firthlogit)` のみ |

### 10.2 Locals

| 戻り値 | 内容 |
|---|---|
| `r(exposure)` | 曝露変数名 |
| `r(covariates)` | 共変量リスト |
| `r(method)` | 指定した `method()` |
| `r(den_method)` | 分母モデルの方法 |
| `r(num_method)` | 分子モデルの方法 |
| `r(psden)` | 分母PS変数名 |
| `r(psnum)` | 分子PS変数名 |
| `r(sw)` | SW変数名 |

---

## 11. 例：`sysuse auto` を使った実行例 🚗

### 11.1 基本例：通常のロジスティック回帰

`foreign` を曝露変数、`price`、`mpg`、`weight`、`length` を共変量として、Stabilized Weightを作ります。

~~~stata
sysuse auto, clear

swbin foreign price mpg weight length, sw(sw)

summarize ps_den ps_num sw, detail
~~~

作成される変数：

~~~stata
ps_den   // P(foreign=1 | price, mpg, weight, length)
ps_num   // P(foreign=1)
sw       // Stabilized Weight
~~~

---

### 11.2 出力変数名を指定する例

~~~stata
sysuse auto, clear

swbin foreign price mpg weight length, ///
    psden(ps_foreign_den) ///
    psnum(ps_foreign_num) ///
    sw(sw_foreign)

summarize ps_foreign_den ps_foreign_num sw_foreign, detail
~~~

---

### 11.3 Factor-variable notationを使う例

`rep78` をカテゴリ変数として扱う例です。`rep78` には欠損があるため、解析対象から除外されます。

~~~stata
sysuse auto, clear

swbin foreign price mpg weight i.rep78, ///
    sw(sw) ///
    replace
~~~

---

### 11.4 `if` を使う例

解析対象を `price < 10000` に制限します。

~~~stata
sysuse auto, clear

swbin foreign mpg weight length if price < 10000, ///
    sw(sw_price_lt10000) ///
    replace
~~~

---

### 11.5 `method(probit)` を使う例

~~~stata
sysuse auto, clear

swbin foreign price mpg weight length, ///
    sw(sw_probit) ///
    psden(ps_den_probit) ///
    psnum(ps_num_probit) ///
    method(probit) ///
    replace
~~~

---

### 11.6 `method(firthlogit)` を使う例：Firth + FLIC

事前に `firthlogit` をインストールしておきます。

~~~stata
ssc install firthlogit
~~~

その後、`method(firthlogit)` を指定します。

~~~stata
sysuse auto, clear

swbin foreign price mpg weight length, ///
    sw(sw_flic) ///
    psden(ps_den_flic) ///
    psnum(ps_num) ///
    method(firthlogit) ///
    replace
~~~

この場合、分母PS `ps_den_flic` は Firth + FLIC によって作成されます。  
分子PS `ps_num` は、通常の切片のみロジスティック回帰で作成されます。

---

## 12. 作成後に推奨される確認 ✅

`swbin` は重みを作成しますが、重みの妥当性やバランス診断までは行いません。  
作成後は、少なくとも以下を確認することを推奨します。

### 12.1 重みの分布

~~~stata
summarize sw, detail
histogram sw, bin(50)
~~~

### 12.2 分母PSの分布

~~~stata
summarize ps_den, detail
histogram ps_den, bin(50)
~~~

### 12.3 極端なPSの確認

~~~stata
count if ps_den < 0.01 | ps_den > 0.99
count if ps_den < 0.05 | ps_den > 0.95
~~~

### 12.4 曝露群別のPSと重み

~~~stata
tabstat ps_den sw, by(foreign) statistics(n mean sd min p25 p50 p75 max)
~~~

### 12.5 共変量バランスの確認

`swbin` 自体にはSMDやLove plot作成機能はありません。  
必要に応じて、別途SMDやVariance Ratioを計算してください。

---

## 13. 解析での利用例

### 13.1 修正Poisson回帰でリスク比を推定

~~~stata
glm outcome exposure [pweight = sw], ///
    family(poisson) link(log) vce(robust) eform
~~~

### 13.2 ロジスティック回帰

~~~stata
logit outcome exposure [pweight = sw], vce(robust)
~~~

### 13.3 線形回帰

~~~stata
regress outcome exposure [pweight = sw], vce(robust)
~~~

### 13.4 Cox比例ハザードモデル

~~~stata
stset time, failure(event == 1)
stcox exposure [pweight = sw], vce(robust)
~~~

### 13.5 クラスター単位のロバスト分散

多施設研究などで施設クラスターを考慮したい場合は、解析モデル側で指定します。

~~~stata
glm outcome exposure [pweight = sw], ///
    family(poisson) link(log) vce(cluster hosp_id) eform
~~~

---

## 14. 重みのトリミング・truncation例

`swbin` には、重みのtrimming / truncation機能はありません。  
必要な場合は、事前にルールを決めたうえで、別変数として作成してください。

### 14.1 1パーセンタイル・99パーセンタイルでwinsorize

~~~stata
_pctile sw, p(1 99)

gen double sw_trunc = sw
replace sw_trunc = r(r1) if sw < r(r1)
replace sw_trunc = r(r2) if sw > r(r2)

summarize sw sw_trunc, detail
~~~

### 14.2 固定範囲でtruncation

例として、0.1未満を0.1、10超を10に丸めます。

~~~stata
gen double sw_trunc_01_10 = sw
replace sw_trunc_01_10 = 0.1 if sw_trunc_01_10 < 0.1
replace sw_trunc_01_10 = 10  if sw_trunc_01_10 > 10

summarize sw sw_trunc_01_10, detail
~~~

---

## 15. よくあるエラーと対処（Troubleshooting）🧯

### (A) `method() must be one of: logit, probit, firthlogit`

原因：`method()` に指定できない値を入れています。  
対処：以下のいずれかを指定します。

~~~stata
method(logit)
method(probit)
method(firthlogit)
~~~

---

### (B) `Variable ... already exists.`

原因：作成予定の変数が既に存在しています。  
対処：既存変数を上書きする場合は `replace` を付けます。

~~~stata
swbin trt age sex, sw(sw) replace
~~~

または、出力変数名を変更します。

~~~stata
swbin trt age sex, sw(sw_new)
~~~

---

### (C) `Output variable names must be distinct.`

原因：`psden()`、`psnum()`、`sw()` に同じ名前を指定しています。  
対処：3つの出力変数名をすべて異なる名前にします。

---

### (D) `Exposure variable ... must be numeric.`

原因：曝露変数が文字列変数です。  
対処：0/1の数値変数に変換してください。

例：

~~~stata
gen byte trt01 = .
replace trt01 = 1 if trt == "treated"
replace trt01 = 0 if trt == "control"
~~~

---

### (E) `Exposure variable ... must contain only 0 and 1`

原因：解析対象内で、曝露変数に0/1以外が含まれています。  
対処：コードを確認します。

~~~stata
tabulate trt, missing
~~~

必要に応じて再コード化します。

~~~stata
recode trt (2 = 1), gen(trt01)
~~~

---

### (F) `Exposure variable ... must contain both 0 and 1`

原因：`if` / `in` や欠損除外後の解析対象内で、片方の群しか残っていません。  
対処：解析対象条件や欠損状況を確認します。

~~~stata
tabulate trt if !missing(age, sex, x1, x2), missing
~~~

---

### (G) `firthlogit is not installed.`

原因：`method(firthlogit)` を指定したが、`firthlogit` がインストールされていません。  
対処：インストールします。

~~~stata
ssc install firthlogit
~~~

---

### (H) `Denominator model did not converge.`

原因：分母モデルが収束していません。  
考えられる原因：

- 共変量が多すぎる
- 完全分離・準完全分離がある
- カテゴリ水準が細かすぎる
- サンプルサイズに対してモデルが複雑すぎる

対処例：

- 共変量を見直す
- カテゴリ変数の水準を統合する
- `method(firthlogit)` を検討する
- 欠損や外れ値を確認する

---

### (I) `Some predicted probabilities are missing or outside the open interval (0, 1).`

原因：予測確率が欠損、0、1、または不正な値になっています。  
対処：モデル、共変量、完全分離、極端な予測確率を確認します。

~~~stata
summarize ps_den ps_num, detail
~~~

---

## 16. 設計上の固定仕様（Notes）

- `swbin` は二値曝露・二値治療専用です。
- 多値治療、連続曝露、時間依存曝露には対応していません。
- 分子モデルは常に切片のみの通常ロジスティック回帰です。
- `method(firthlogit)` の場合でも、Firth + FLIC を使うのは分母モデルのみです。
- `replace` を指定すると、既存の出力変数は `drop` されて再作成されます。
- `swbin` はSMD、Variance Ratio、Love plotなどのバランス診断を行いません。
- `swbin` は重みのtrimming / truncationを行いません。
- `swbin` の構文自体は `[pweight=]` などのStata weight構文を受け取りません。

---

## 17. 推奨ワークフロー（Suggested workflow）🧭

1) 曝露変数が0/1であることを確認

~~~stata
tabulate trt, missing
~~~

2) 共変量の欠損を確認

~~~stata
misstable summarize trt age sex x1 x2
~~~

3) Stabilized Weightを作成

~~~stata
swbin trt age i.sex x1 x2, sw(sw)
~~~

4) 重みの分布を確認

~~~stata
summarize sw, detail
histogram sw, bin(50)
~~~

5) 分母PSの分布を確認

~~~stata
summarize ps_den, detail
histogram ps_den, bin(50)
~~~

6) 共変量バランスを確認

~~~stata
* 例：別途SMDやVRを計算する
~~~

7) 重み付き解析を実行

~~~stata
glm outcome trt [pweight = sw], ///
    family(poisson) link(log) vce(robust) eform
~~~

---

## 18. 変更履歴（Changelog）

- v1.0.0
  - 二値曝露に対する基本的な Stabilized Weight 作成
  - `psden()`、`psnum()`、`sw()` に対応
  - `method(logit)`、`method(probit)`、`method(firthlogit)` に対応
- v1.1.0
  - 曝露変数の0/1チェックを強化
  - 0と1の両方が存在することを確認
  - 出力変数名の重複チェックを強化
- v1.2.0
  - `method(firthlogit)` の分母モデルを Firth + FLIC に変更
  - 分子モデルは常に切片のみ通常ロジスティック回帰に固定
  - FLICチェックとして、観測曝露割合と平均FLIC予測確率を表示

---

## 19. 関連コマンド（Related commands）

- `logit`
- `probit`
- `predict`
- `firthlogit`（外部コマンド）
- `glm`
- `stcox`
- `tabstat`
- `summarize`

---

## 20. 関連文献（References）

- Robins JM, Hernán MA, Brumback B. Marginal structural models and causal inference in epidemiology. *Epidemiology*. 2000;11(5):550-560.
- Cole SR, Hernán MA. Constructing inverse probability weights for marginal structural models. *American Journal of Epidemiology*. 2008;168(6):656-664.
- Hernán MA, Robins JM. *Causal Inference: What If*. Chapman & Hall/CRC.
- Firth D. Bias reduction of maximum likelihood estimates. *Biometrika*. 1993;80(1):27-38.
- Puhr R, Heinze G, Nold M, Lusa L, Geroldinger A. Firth's logistic regression with rare events: accurate effect estimates and predictions? *Statistics in Medicine*. 2017;36(14):2302-2317.

---

## 21. 最小例（Minimal example）

~~~stata
sysuse auto, clear

swbin foreign price mpg weight length, sw(sw)

summarize ps_den ps_num sw, detail
~~~

---

## 22. FLIC最小例（Minimal FLIC example）

~~~stata
ssc install firthlogit
sysuse auto, clear

swbin foreign price mpg weight length, ///
    sw(sw_flic) ///
    psden(ps_den_flic) ///
    psnum(ps_num) ///
    method(firthlogit) ///
    replace

summarize ps_den_flic ps_num sw_flic, detail
~~~

---

（このマニュアルは `swbin.ado v1.2.0` の実装に合わせて記述）
