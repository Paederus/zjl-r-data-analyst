# 统计分析与建模

原则：**先看分布，再做检验；先看效应量，再看 p 值**。任何结论都要能回答"差多少、多确定、对谁成立"。

## 1. 描述统计

```r
library(dplyr)
df |> group_by(group) |>
  summarise(n = n(),
            mean = mean(value, na.rm = TRUE),
            sd   = sd(value, na.rm = TRUE),
            se   = sd / sqrt(n),
            median = median(value, na.rm = TRUE),
            q1 = quantile(value, .25, na.rm = TRUE),
            q3 = quantile(value, .75, na.rm = TRUE),
            min = min(value), max = max(value))
```

报告规范：连续变量 `mean ± SD`（正态）或 `median [IQR]`（偏态）；分类变量 `n (%)`；**必须给 n**。

正态性：`shapiro.test()`（n < 5000）、QQ 图、偏度峰度。方差齐性：`car::leveneTest()`。

## 2. 两组比较

| 情形 | 方法 | 代码 |
|---|---|---|
| 独立、正态、方差齐 | 独立样本 t 检验 | `t.test(y ~ g, var.equal = TRUE)` |
| 独立、正态、方差不齐 | Welch t | `t.test(y ~ g)`（默认） |
| 独立、非正态 | Mann-Whitney U | `wilcox.test(y ~ g)` |
| 配对、正态 | 配对 t | `t.test(y1, y2, paired = TRUE)` |
| 配对、非正态 | Wilcoxon 符号秩 | `wilcox.test(y1, y2, paired = TRUE)` |
| 二分类 | 卡方 / Fisher | `chisq.test(table)`；期望频数 < 5 用 `fisher.test()` |

效应量：`effectsize::cohens_d()`、`effectsize::rank_biserial()`、`rstatix::cohens_d()`。

## 3. 多组比较：方差分析

```r
fit <- aov(value ~ group, data = df)
summary(fit)
TukeyHSD(fit)                       # 事后两两比较
car::leveneTest(value ~ group, data = df)   # 方差齐性
par(mfrow = c(2, 2)); plot(fit)     # 残差诊断四联图
```

- 方差不齐 → `oneway.test(value ~ group, var.equal = FALSE)` 或 Welch ANOVA + `Games-Howell` 事后检验。
- 非正态 → `kruskal.test()` + `pairwise.wilcox.test(p.adjust.method = "BH")`。
- 双因素：`aov(y ~ A * B)`；交互显著时不能只看主效应。
- 协变量：`aov(y ~ group + covariate)`（协方差分析）。
- 重复测量：`afex::aov_ez()` 或混合模型 `lme4::lmer(y ~ time * group + (1 | subject))`。

**多重比较必须校正**（Tukey / Bonferroni / BH），并说明用的哪一种。

## 4. 回归

```r
m <- lm(y ~ x1 + x2 + x1:x2, data = df)
summary(m)
confint(m)                                    # 系数置信区间
performance::check_model(m)                   # 诊断图组
car::vif(m)                                   # 共线性（> 5 需关注，> 10 严重）
broom::tidy(m, conf.int = TRUE)               # 结果表
modelsummary::modelsummary(list(m1, m2), output = "table.docx")
```

- 线性回归假设：线性、独立、同方差、残差正态、无强影响点。用残差-拟合图 + QQ 图 + Cook 距离检查。
- 交互项显著才解释交互；只在中心化后解释主效应。
- 变量选择不要用逐步回归作为最终模型（系数有偏、p 值失真）；用领域知识 + 信息准则（AIC）比较少量候选模型。
- 稳健标准误：`lmtest::coeftest(m, vcov = sandwich::vcovHC(m, type = "HC3"))`。
- 非线性：多项式、样条 `splines::ns()`、GAM `mgcv::gam()`。

### 广义线性模型

```r
glm(y_bin ~ x, family = binomial)     # logistic，报告 OR = exp(coef)
glm(count ~ x, family = poisson)      # 计数；过度离散改 quasipoisson / 负二项 MASS::glm.nb
```

logistic 回归要报告：OR 及 95%CI、AUC（`pROC::auc()`）、校准、阈值选择依据。

### 混合效应

```r
lme4::lmer(y ~ treat + time + (1 | subject), data = df)      # 随机截距
lme4::lmer(y ~ treat * time + (1 + time | subject), data = df)  # 随机斜率
```

随机效应结构由设计决定（重复测量、嵌套、分层抽样），不可随意增减。

## 4.5 重抽样与自助法（参数假设不成立时的备选）

传统检验依赖"服从某理论分布"的假设；**置换检验与自助法用经验分布替代理论分布**，适合小样本、分布未知、有异常值或假设检验在数学上难以推导的情形。

```r
library(coin)
# 独立性/组间比较的置换检验框架（distribution 用蒙特卡洛近似）
coin::oneway_test(y ~ A, data = df, distribution = approximate(nresample = 9999))  # 两样本/K 样本
coin::oneway_test(y ~ A | C, data = df)      # 含区组（分层）因子
coin::wilcox_test(y ~ A, data = df)          # 秩和检验的置换版
coin::independence_test(y ~ x, data = df)    # 两连续变量独立性
coin::chisq_test(~ A + B, data = df)         # 列联表独立性
coin::spearman_test(y ~ x, data = df)        # 秩相关

# 自助法：重复有放回抽样估计统计量的抽样分布
library(boot)
stat <- function(d, i) mean(d[i]$value)
b <- boot(df, statistic = stat, R = 2000)
boot.ci(b, type = c("perc", "bca"))          # 优先 BCa 或百分位数区间
```

要点：

- 置换检验算的是**同一个统计量**（如 t），区别在于不与理论分布比，而是与"打乱分组标签后重算"的**经验分布**比；所有可能排列穷举时称精确检验，样本大时用蒙特卡洛抽样近似。
- 置换检验的前提是**可交换性**（零假设下标签可互换），不可交换的设计（如强相关重复测量）不能直接用 `oneway_test()`。
- 置换/自助都依赖伪随机数，**必须 `set.seed()`**，否则结果不可复现。
- `boot::boot.ci()` 有多个区间类型，`"bca"`（偏差校正加速）一般最准，但未收敛时会给出 NaN。
- 自助法适合给"没有现成公式的统计量"（如相关系数之差、中位数比值）构造置信区间。
- 注意 `lmPerm` 包已从 CRAN 归档（不可再用）；线性模型与 ANOVA 的置换检验改用 `coin`、`perm` 或 `rcompanion`。

## 5. 降维、因子与聚类

```r
pca <- prcomp(df_num, scale. = TRUE)
summary(pca)                                  # 解释方差比例
factoextra::fviz_pca_biplot(pca, habillage = df$group, repel = TRUE)

fviz_nbclust(df_scaled, kmeans, method = "silhouette")   # 选 k
km <- kmeans(df_scaled, centers = 3, nstart = 25)
```

- PCA 前必须标准化，否则量纲大的变量主导。
- 聚类前同样标准化；k-means 假设球形簇，非凸结构用 DBSCAN / 层次聚类。
- t-SNE / UMAP 只用于可视化，**不能**据此断言簇间距离或做统计推断。

### 5.1 探索性因子分析（EFA）

**先分清目标**：PCA 是降维（主成分 = 观测变量的线性组合，最大化解释方差）；EFA 是发现潜在结构（因子解释变量间的相关）。选错模型，结论就错了。

```r
library(psych)
psych::fa.parallel(df_num, fa = "fa")      # 平行分析碎石图，给出因子数建议
fa <- psych::fa(df_num, nfactors = 3, rotate = "oblimin", fm = "ml")
print(fa$loadings, cutoff = 0.32)          # 载荷低于 0.32 一般不解释
fa.diagram(fa)                             # 因子结构图
psych::principal(df_num, nfactors = 3, rotate = "varimax")  # 做带旋转的主成分
```

标准步骤：① 数据预处理（可输入原始数据或相关矩阵）→ ② 选模型（PCA 还是 EFA，以及估计方法如最大似然 `fm = "ml"`）→ ③ 判断因子数（平行分析 + 碎石图 + 理论）→ ④ 选择旋转方法 → ⑤ 解释并命名因子 → ⑥ 计算因子得分。

- **旋转**：正交无相关用 `varimax`，允许因子相关用斜交 `oblimin`/`promax`——多数社科数据在理论上因子应相关，斜交更合理。
- 样本量经验规则：变量数的 **5–10 倍**，且建议 n ≥ 100。
- 建模前检查相关矩阵是否适合做因子分析：Bartlett 球形检验显著、KMO > 0.6（`psych::KMO()`、`psych::cortest.bartlett()`）。

### 5.2 监督分类（决策树 / 随机森林 / SVM）

目标是预测类别而非解释系数，关注点是**泛化误差与变量重要性**。

```r
library(rpart); library(rpart.plot); library(randomForest); library(e1071)

# 1) 经典决策树：先看 cptable，按 1-SE 规则选复杂度参数再剪枝
dtree <- rpart(class ~ ., data = df_train, method = "class",
               parms = list(split = "information"), cp = 0.01)
printcp(dtree); plotcp(dtree)
dtree_pruned <- prune(dtree, cp = dtree$cptable[which.min(dtree$cptable[, "xerror"]), "CP"])
rpart.plot::prp(dtree_pruned, type = 2, extra = 104)

# 2) 条件推断树：基于显著性检验选分割，无需剪枝，变量选择偏差更小
party::ctree(class ~ ., data = df_train)

# 3) 随机森林：默认 500 棵，无需剪枝，可直接看袋外误差与变量重要性
rf <- randomForest(class ~ ., data = df_train, importance = TRUE, ntree = 500)
print(rf)                                   # OOB estimate of error rate
importance(rf, type = 2)                    # MeanDecreaseGini 变量重要性
varImpPlot(rf)

# 4) 支持向量机：对变量尺度敏感，建模前应标准化
svm_model <- e1071::svm(class ~ ., data = df_train, kernel = "radial", cost = 1)
kernlab::ksvm(class ~ ., data = df_train)   # 更完整的实现（kernlab）

# 5) 评估：用独立验证集或交叉验证，不要只看训练集表现
tune <- e1071::tune(svm, class ~ ., data = df_train,
                    ranges = list(cost = c(0.1, 1, 10), gamma = c(0.01, 0.1)))
caret::confusionMatrix(predict(rf, df_test), df_test$class)
pROC::roc(df_test$class == "malignant", predict(rf, df_test, type = "prob")[, 2])
```

决策要点：

- 必须拆**训练集 / 验证集**（如 7:3），或用 k 折交叉验证；训练集上的准确率几乎总是虚高的。
- 类别不平衡时，准确率是无效指标，改看**灵敏度/特异度、AUC、F1、平衡准确率**。
- `rpart` 剪枝用 1-SE 规则：取交叉验证误差落在最小值一个标准差范围内**最简的那棵树**。
- 随机森林的默认 `mtry = sqrt(p)`（分类），回归用 `p/3`；如需调参用 `caret::train()` 网格搜索。
- SVM 默认会先对每个预测变量做标准化（因方差大的变量会主导超平面）；换软件复现时务必确认这一预处理是否一致。
- 结果要同时报告**模型**与**评估方式**，并把最终模型的方向写清楚：解释型问题优先 logistic 回归（有 OR），预测型问题才用树/森林/SVM。

## 6. 时间序列

```r
ts_obj <- ts(df$value, start = c(2015, 1), frequency = 12)
forecast::ggtsdisplay(ts_obj)                 # ACF/PACF + 序列图
fit <- forecast::auto.arima(ts_obj)
forecast::checkresiduals(fit)
forecast::forecast(fit, h = 12) |> autoplot()
```

- 先看趋势与季节性（STL 分解：`forecast::stl()`）。
- 平稳性：`tseries::adf.test()`；不平稳先差分。
- 预测必须给区间，并说明是点预测还是区间预测。

## 7. 样本量与功效

```r
pwr::pwr.t.test(d = 0.5, sig.level = 0.05, power = 0.8)     # 每组 n
pwr::pwr.anova.test(k = 3, f = 0.25, sig.level = 0.05, power = 0.8)
```

事后功效分析意义有限；优先报告效应量与置信区间。

## 8. 结果呈现

| 场景 | 推荐 |
|---|---|
| 系数表 | `modelsummary` / `broom::tidy()` + `gt` / `flextable` |
| 组间比较 | 箱形/小提琴 + 抖动点 + 显著性标注（`ggpubr::stat_compare_means()`） |
| 回归诊断 | 残差-拟合、QQ、Cook 距离三联图 |
| 模型比较 | AIC/BIC 表 + 交叉验证误差 |
| 预测 | 折线 + 置信带（`geom_ribbon`） |

表格规范：数值右对齐、小数位统一（一般 2–3 位）、p 值写 `p < 0.001` 而非 `p = 0.000`、单位入表头。

## 9. 解读纪律

1. **相关不等于因果**——除非有设计支持（随机化、准实验、工具变量），表述用"相关/关联"。
2. **p > 0.05 不等于无差异**——报告效应量与 CI，说"未发现统计学显著差异"。
3. **多重比较未校正**的"显著"结果不可信。
4. **样本代表性**决定结论外推边界，必须在局限中写明。
5. **异常值处理方式**会改变结论，必须披露。
6. 模型假设不满足时，换方法或说明稳健性检验结果，不要硬套。

## 10. 缺失数据与稳健性

1. **先诊断再处理**：识别缺失比例与模式（`mice::md.pattern()`、`VIM::aggr()`），判断更接近 MCAR / MAR / NMAR，再决定用行删除还是多重插补——详见 `references/missing-data.md`。
2. 默认的行删除会**悄悄减少样本**且在不同模型间不一致，必须在方法部分写明最终纳入的样本量与排除理由。
3. 不要用均值/中位数简单插补替代多重插补：前者会低估变异、扭曲相关并使 p 值失真。
4. 假设不满足时可用**置换检验或自助法**做稳健性检查（见 4.5 节），并与参数方法的结果并列报告。
5. 结论对异常值或缺失处理方式敏感时，必须做**敏感性分析**（换一种处理方式看结论是否翻转）。
