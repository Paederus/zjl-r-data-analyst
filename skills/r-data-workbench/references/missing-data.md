# 缺失数据处理

原则：**先诊断缺失机制，再选方法；不要无脑 `na.omit()`**。多数统计方法假定输入是完整矩阵，而真实数据几乎总有缺失——处理方式直接影响结论。

## 1. 三种缺失机制（决定方法选择）

| 机制 | 定义 | 后果与策略 |
|---|---|---|
| MCAR 完全随机缺失 | 缺失与任何已观测/未观测变量都无关 | 完整样本是大样本的随机抽样；行删除可接受 |
| MAR 随机缺失 | 缺失与其他**已观测**变量相关，与自身未观测值无关 | 可用多重插补得到无偏且有效的结果 |
| NMAR 非随机缺失 | 缺失与自身未观测值相关 | 需专门的模式混合/选择模型，或补采数据 |

无法观测真实值，所以严格区分三者不可能。**默认前提通常是 MCAR 或 MAR**，且必须在报告中写明这一假设与其对结论的影响。

## 2. 识别缺失值

```r
is.na(x); is.nan(x); is.infinite(x)          # NA / NaN / Inf 三类，语义不同
sum(is.na(df$var)); mean(is.na(df$var))      # 个数与比例：> 5% 必须处理
mean(!complete.cases(df))                    # 含缺失的行占比
naniar::miss_var_summary(df)                 # 逐变量缺失汇总（推荐）
```

三个易踩的坑：

1. `complete.cases()` **只把 NA 与 NaN 视为缺失**，把 `Inf` / `-Inf` 当作有效数值——如有除零产生的无穷值，需先单独处理。
2. `x == NA` 永远返回 `NA`，**不能**用来判断缺失，必须用 `is.na()`。
3. 字符列里的空串 `""`、`"NA"`、`"N/A"`、`"999"` 不会被识别为缺失，**读入阶段就要转**：`readr::read_csv(na = c("NA", "", "N/A", "999", "-99"))`。

## 3. 诊断缺失模式

```r
# 缺失模式矩阵：行=缺失模式，1=有值 0=缺失，左边是频数、右边是缺失变量数
mice::md.pattern(df)

# 可视化：左图各变量缺失计数，右图各变量组合的缺失频数
VIM::aggr(df, prop = FALSE, numbers = TRUE)

# 逐行矩阵图：灰度表示数值大小，红色标记缺失；可与缺失值相关的扶正结构
VIM::matrixplot(df)

# 边界箱线图：两变量散点 + 边界展示各自缺失组的分布差异
VIM::marginplot(df[c("x", "y")], pch = 20, col = c("darkgrey", "red", "blue"))

# 影子矩阵：把缺失本身变成 0/1 变量，看哪些变量倾向于一起缺失
shadow <- as.data.frame(abs(is.na(df)))
cor(shadow[which(apply(shadow, 2, sum) > 0)])          # 缺失指示变量间相关
cor(df, shadow, use = "pairwise.complete.obs")         # 缺失与观测变量的关系
```

要回答四个问题：**缺失比例多大？集中在少数变量还是普遍存在？是否随机？缺失之间或缺失与观测值之间的相关能否提示生成机制？**

## 4. 方法选择（由劣到优）

| 方法 | 适用 | 风险 |
|---|---|---|
| 推理恢复 | 存在数学/逻辑冗余（如 `Total = A + B`、可由生日推出生年份） | 只能恢复可推导部分 |
| 行删除 `na.omit()` / `complete.cases()` | MCAR 且样本损失可接受 | 违反 MCAR 则有偏；损失样本 → 效力下降 |
| **多重插补 MI** | MCAR/MAR 的通用首选 | 需要迭代收敛，报告时须写插补方法 |
| 成对删除 `use = "pairwise.complete.obs"` | 不推荐 | 每次计算用不同子集，结果可能不自洽甚至相关矩阵非正定 |
| 简单插补（均值/中位数/众数） | 不推荐 | 非随机插补 → 低估标准差、扭曲相关、p 值失真 |

> 关键提醒：多数回归与相关函数默认使用**局部行删除**（只删模型涉及变量含缺失的行），不同模型实际用的样本量可能不同，导致结果前后不一致。建模前建议显式固定同一样本集。

## 5. 多重插补标准流程（mice）

```r
library(mice)

imp   <- mice(df, m = 5, seed = 1234, method = "pmm", printFlag = FALSE)
fit   <- with(imp, lm(y ~ x1 + x2))     # 对每个插补数据集分别拟合
pool  <- pool(fit)                       # 合并（Rubin 规则）
summary(pool, conf.int = TRUE)           # 标准误已含缺失带来的不确定性

complete(imp, action = 1)                # 取出第 1 个完整数据集（仅用于绘图/诊断）
densityplot(imp); stripplot(imp, pch = 20, cex = 1.2)   # 检查插补值分布是否合理
```

要点：

- `m` 取 3–10，缺失比例高时取更大值；现代做法倾向 `m ≈ 缺失比例 × 5`。
- 默认按变量类型选模型：连续型用预测均值匹配（PMM），二值用 logistic，多分类用多元 logistic，均可手动指定 `method`。
- 插补基于 Gibbs 抽样迭代收敛，最终 `pool()` 给出的标准误与 p 值才同时反映抽样变异与插补不确定性。
- **务必设 `seed`**，否则结果不可复现。
- 合并后会输出 `nmis`（缺失个数）与 `fmi`（缺失信息分数），可作为缺失影响程度的参考。

## 6. 其他场景的专用工具

| 场景 | 包 |
|---|---|
| 多元正态缺失值的最大似然估计 | `mvnmle` |
| 多元类别型变量多重插补（对数线性模型） | `cat` |
| 混合类别与连续型数据 | `mix` |
| 面板数据 / 聚类数据 | `pan` |
| 生存分析缺失值 | `kmi` |
| 微阵列数据 | `arrayImpute` / `arrayMissPattern` / `SeqKnn` |
| 纵向/时序数据插补 | `longitudinalData` |
| 探索性缺失可视化（综合） | `naniar` / `visdat` |

## 7. 绘图时的缺失处理

```r
ggplot(df, aes(x, y)) +
  geom_point(na.rm = TRUE) +
  labs(caption = "含缺失值的观测已被剔除")

dplyr::summarise(df, across(everything(), ~ mean(.x, na.rm = TRUE)))
```

- `na.rm = TRUE` 在图形里是**逐几何对象**生效的，各图层可能使用不同样本。
- 汇总统计时明确写出 `na.rm = TRUE`，否则结果会是 `NA`。
- 图表注释必须交代缺失观测的处理方式与最终样本量 n。
