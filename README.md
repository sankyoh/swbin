# swbin

**swbin** is a Stata command for creating stabilized weights for a binary treatment or exposure.

`swbin` estimates the denominator propensity score `P(A=1|L)` using `logit`, `probit`, or Firth logistic regression with intercept correction (FLIC), and estimates the numerator probability `P(A=1)` using an intercept-only standard logistic regression.

エラーやバグなどがありましたらお知らください。できるだけ対応します。
If you encounter any errors or bugs, please let me know. I'll do our best to address them.

---

## 日本語

### 概要

`swbin` は、二値曝露・二値治療に対する **Stabilized Weight（安定化重み）** を作成するための Stata ユーザー定義コマンドです。

曝露変数を `A`、共変量を `L` とすると、以下の重みを作成します。

```text
A = 1:  SW = P(A=1) / P(A=1|L)
A = 0:  SW = P(A=0) / P(A=0|L)
```

分母モデル `P(A=1|L)` は、`method()` オプションで以下から選択できます。

- `method(logit)`: 通常のロジスティック回帰
- `method(probit)`: プロビット回帰
- `method(firthlogit)`: Firth ロジスティック回帰 + FLIC

分子モデル `P(A=1)` は、常に切片のみの通常ロジスティック回帰で推定します。

### インストール

Stata から以下のコマンドでインストールできます。

```stata
net install swbin, from("https://raw.githubusercontent.com/sankyoh/swbin/main/stata") replace
```

インストールが正常にできたかどうかは、下記のコマンドで確認できます。

```stata
which swbin
help swbin
```

### `method(firthlogit)` を使う場合

`method(firthlogit)` を使う場合のみ、外部コマンド `firthlogit` が必要です。

```stata
ssc install firthlogit
```

### 基本構文

```stata
swbin exposure covariates [if] [in], ///
    sw(new_weight_var) ///
    [ psden(new_ps_den_var) ///
      psnum(new_ps_num_var) ///
      method(logit|probit|firthlogit) ///
      replace ]
```

### 最小例

```stata
sysuse auto, clear

swbin foreign price mpg weight length, sw(sw)

summarize ps_den ps_num sw, detail
```

### 出力変数名を指定する例

```stata
sysuse auto, clear

swbin foreign price mpg weight length, ///
    psden(ps_foreign_den) ///
    psnum(ps_foreign_num) ///
    sw(sw_foreign)

summarize ps_foreign_den ps_foreign_num sw_foreign, detail
```

### FLIC の例

```stata
ssc install firthlogit
sysuse auto, clear

swbin foreign price mpg weight length, ///
    sw(sw_flic) ///
    psden(ps_den_flic) ///
    psnum(ps_num) ///
    method(firthlogit) ///
    replace

summarize ps_den_flic ps_num sw_flic, detail
```

### 推奨される確認

`swbin` は重みを作成しますが、共変量バランスの診断や重みのトリミングは行いません。作成後は、少なくとも以下を確認することを推奨します。

なお、確認に用いるために適したコマンドも作成を予定しています。

```stata
summarize sw, detail
histogram sw, bin(50)

summarize ps_den, detail
histogram ps_den, bin(50)

tabstat ps_den sw, by(foreign) statistics(n mean sd min p25 p50 p75 max)
```

### 戻り値

`swbin` は `rclass` コマンドです。

```stata
return list
```

主な戻り値は以下です。

- `r(N_initial)`: 初期解析サンプル数
- `r(N_denominator)`: 分母モデルサンプル数
- `r(N_final)`: 最終重み付きサンプル数
- `r(sw_mean)`: Stabilized Weight の平均
- `r(sw_min)`: Stabilized Weight の最小値
- `r(sw_max)`: Stabilized Weight の最大値

### 制限

- 二値曝露・二値治療専用です。
- 多値治療、連続曝露、時間依存曝露には対応していません。
- 重みの trimming / truncation は行いません。
- SMD、variance ratio、Love plot などのバランス診断は行いません。
- `swbin` コマンド自体は Stata の weight syntax を受け取りません。

---

## English

### Overview

`swbin` is a user-written Stata command that creates stabilized weights for a binary treatment or exposure.

Let `A` denote a binary treatment/exposure and `L` denote baseline covariates. `swbin` creates:

```text
A = 1:  SW = P(A=1) / P(A=1|L)
A = 0:  SW = P(A=0) / P(A=0|L)
```

The denominator propensity score `P(A=1|L)` can be estimated using one of the following methods:

- `method(logit)`: standard logistic regression
- `method(probit)`: probit regression
- `method(firthlogit)`: Firth logistic regression with intercept correction (FLIC)

The numerator probability `P(A=1)` is always estimated using an intercept-only standard logistic regression.

### Installation

Install directly from GitHub with:

```stata
net install swbin, from("https://raw.githubusercontent.com/sankyoh/swbin/main/stata") replace
```

Then check the installation:

```stata
which swbin
help swbin
```

### Requirement for `method(firthlogit)`

The `method(firthlogit)` option requires the user-written command `firthlogit`.

```stata
ssc install firthlogit
```

### Syntax

```stata
swbin exposure covariates [if] [in], ///
    sw(new_weight_var) ///
    [ psden(new_ps_den_var) ///
      psnum(new_ps_num_var) ///
      method(logit|probit|firthlogit) ///
      replace ]
```

### Minimal example

```stata
sysuse auto, clear

swbin foreign price mpg weight length, sw(sw)

summarize ps_den ps_num sw, detail
```

### Example with user-specified output names

```stata
sysuse auto, clear

swbin foreign price mpg weight length, ///
    psden(ps_foreign_den) ///
    psnum(ps_foreign_num) ///
    sw(sw_foreign)

summarize ps_foreign_den ps_foreign_num sw_foreign, detail
```

### Example using FLIC

```stata
ssc install firthlogit
sysuse auto, clear

swbin foreign price mpg weight length, ///
    sw(sw_flic) ///
    psden(ps_den_flic) ///
    psnum(ps_num) ///
    method(firthlogit) ///
    replace

summarize ps_den_flic ps_num sw_flic, detail
```

### Suggested diagnostics after creating weights

`swbin` creates weights but does not perform balance diagnostics or weight truncation. After creating weights, users should examine the propensity score and weight distributions and assess covariate balance.

I also plan to create commands suitable for verification purposes.

```stata
summarize sw, detail
histogram sw, bin(50)

summarize ps_den, detail
histogram ps_den, bin(50)

tabstat ps_den sw, by(foreign) statistics(n mean sd min p25 p50 p75 max)
```

### Stored results

`swbin` is an `rclass` command.

```stata
return list
```

Main stored results include:

- `r(N_initial)`: initial analysis sample size
- `r(N_denominator)`: denominator model sample size
- `r(N_final)`: final weighted sample size
- `r(sw_mean)`: mean stabilized weight
- `r(sw_min)`: minimum stabilized weight
- `r(sw_max)`: maximum stabilized weight

### Limitations

- Binary treatment/exposure only.
- No support for multivalued, continuous, or time-varying treatments.
- No built-in weight trimming or truncation.
- No built-in balance diagnostics such as SMD, variance ratio, or Love plot.
- The command itself does not accept Stata weight syntax.

---

## Files

```text
README.md
docs/swbin.md
stata/stata.toc
stata/swbin.pkg
stata/swbin.ado
stata/swbin.sthlp
stata/sample.do
```

## References

- Robins JM, Hernán MA, Brumback B. Marginal structural models and causal inference in epidemiology. *Epidemiology*. 2000;11(5):550-560. [LINK](https://doi.org/10.1097/00001648-200009000-00011) 
- Cole SR, Hernán MA. Constructing inverse probability weights for marginal structural models. *American Journal of Epidemiology*. 2008;168(6):656-664. [LINK](https://doi.org/10.1093/aje/kwn164)
- Hernán MA, Robins JM. *Causal Inference: What If*. Chapman & Hall/CRC. [Book Site](https://miguelhernan.org/whatifbook)
- Firth D. Bias reduction of maximum likelihood estimates. *Biometrika*. 1993;80(1):27-38. [LINK](https://doi.org/10.1093/biomet/80.1.27)
- Puhr R, Heinze G, Nold M, Lusa L, Geroldinger A. Firth's logistic regression with rare events: accurate effect estimates and predictions? *Statistics in Medicine*. 2017;36(14):2302-2317. [LINK](https://doi.org/10.1002/sim.7273)

## Author

Toshiharu Mitsuhashi  
GitHub: [@sankyoh](https://github.com/sankyoh)

