---
name: r-data-workbench
displayName: R 数据分析与可视化工作台
version: 1.3.2
license: MIT
description: R 语言数据分析与可视化工作台。当需要用 R 读写与清洗数据（dplyr/tidyr/data.table）、做统计分析与建模（回归、方差分析、检验、PCA/EFA/聚类、时间序列、重抽样、决策树/随机森林/SVM 分类）、处理缺失数据（机制诊断、多重插补）、用 ggplot2 及扩展包绘制各类专业图表（含云雨图、坡度图、波形图、冰柱图、边绑定等 30 种进阶图表的实测配方与零依赖降级写法）、修复跑不通的老代码（归档包与过时语法迁移表）、把图导出为 PNG/PDF/SVG/TIFF 供论文或汇报使用时，加载本技能。包含图形语法参考、图表族全清单、出版级图表规范、缺失数据处理、环境故障排查，以及可直接运行的脚本（环境自检、统一导出、学术主题、统计汇总工具、图表画廊）。
---

# R 数据分析与可视化工作台

本技能提供 R 数据分析与绘图的可执行方法论：**先定图表族，再写图层，最后按规范导出**。

## 使用顺序

| 你的任务 | 先读 |
|---|---|
| 用 ggplot2 搭图层、调标度/坐标/分面/主题 | @references/ggplot2-grammar.md |
| 选图表类型、查某个 geom 的写法与坑 | @references/chart-catalog.md |
| 画进阶图表（云雨图、坡度图、波形图、冰柱图、边绑定、网格地图等 30 种）要现成代码 | @references/chart-recipes.md（逐段实测过，含零依赖降级写法） |
| 接手的旧代码/教程代码跑不通、包装不上 | @references/legacy-code-migration.md |
| 数据清洗、宽长表转换、分组汇总、多表连接 | @references/data-wrangling.md |
| 描述统计、检验、回归、方差分析、降维、因子分析、分类、时间序列、重抽样 | @references/statistics-modeling.md |
| 缺 NA / NaN / Inf、判断缺失机制、选择处理方案、多重插补 | @references/missing-data.md |
| 论文/汇报图表的配色、字体、尺寸、拼版、导出格式与设备 | @references/academic-figure-spec.md |
| 中文乱码、字体缺失、包装不上、图跑不出来 | @references/environment-and-troubleshooting.md |

## 脚本与示例

| 脚本 | 用途 |
|---|---|
| `scripts/check_env.R` | 检查 R 版本、关键包、图形设备（真实冒烟测试）、中文字体；装包时自动测速选国内镜像、失败换源、支持二进制/代理/用户库/写入 `.Rprofile` |
| `scripts/export_figure.R` | 统一定义 `export_figure()`：ggplot 与 base R 图形通用，按用途（screen/journal/slide/print）一次导出 PNG+PDF，设备失败自动回退 |
| `scripts/theme_academic.R` | 学术图表主题 `theme_academic()`、色盲友好调色板（分组数超出色板时自动扩展）、中文字体注册 |
| `scripts/stats-utils.R` | `summarise_ci()`（分组均值+SE+95%CI，直接接 `geom_errorbar`；无 dplyr 时自动走 base R 实现）、`describe_all()`、`tidy_model()`、`compare_models()` |
| `examples/quickstart.R` | 一键自检：读示例数据 → 汇总 → 出图 → 校验产物，仅依赖 base R；接手新环境时先跑它 |
| `examples/chart-gallery.R` | 图表画廊自检：一键渲染 10 张代表性进阶图表（云雨图、坡度图、波形图、冰柱图、旭日图等），缺包自动跳过不中断，退出码 0 = 执行正常 |
| `assets/sample-data.csv` | 72 行 × 7 列合成示例数据（含缺失值），演示与冒烟测试用，禁止冒充用户数据 |

用法：在分析脚本开头 `source()` 所需脚本，之后所有图都用 `export_figure(p, name = "fig01_trend")` 落盘，禁止裸 `ggsave()` 各自为政；误差条所需的汇总一律用 `summarise_ci()`，不要手写 `mean()/sd()` 再拼 `se`。

## 缺包安装策略（中国大陆网络）

顺序固定为：**自动测速选镜像 → 失败自动换源 → 仍失败才手动下载 → 最后 base R 降级**。

```bash
# 1) 自动安装（默认测速挑最快的国内镜像，失败自动换下一个）
Rscript scripts/check_env.R --install --optional

# 2) 想免编译（macOS/Windows 走二进制，绕开 gfortran 缺失等编译错误）
Rscript scripts/check_env.R --install --binary

# 3) 公司网络 / 需要代理（Clash、V2Ray 默认 7890）
Rscript scripts/check_env.R --install --proxy=http://127.0.0.1:7890

# 4) 系统库无写权限 → 装到用户库
Rscript scripts/check_env.R --install --lib=~/Library/R/arm64/4.5/library   # macOS arm64
Rscript scripts/check_env.R --install --lib=~/R/library                      # Linux

# 5) 把最优镜像永久写进 ~/.Rprofile（自动备份原文件）
Rscript scripts/check_env.R --install --save

# 6) 看各镜像延迟与二进制支持情况
Rscript scripts/check_env.R --list-mirrors
```

镜像用**阿里云 / 中科大 / 北外 / 清华**（均提供源码 + macOS/Windows 二进制）；**不要用 `cloud.r-project.org`**，国内经常几十 KB/s；**Posit 公共包源在国内大陆基本不可用**，不要推荐给国内用户。

镜像清单、二进制路径、代理配置与安装报错对照表见 @references/environment-and-troubleshooting.md 第 1 节。

## 硬性约定

1. **先结构后图形**：任何绘图前先 `str()`/`summary()` 数据；因子水平顺序决定图例顺序，必须显式 `factor(x, levels = ...)`。
2. **颜色不用 rainbow**：离散 ≤ 8 类用 ColorBrewer 定性色板或 `ggsci`，连续用 `viridis` 或单色渐变。
3. **导出三参数必写**：`width`、`height`、`units`（外加位图的 `dpi`）。
4. **PDF 中文用 `cairo_pdf`**，或在脚本顶部用 `showtext` 注册字体。
5. **图必须自解释**：轴标签带单位，图例标题用业务语言，关键点直接标注而非依赖读者对照图例。
6. **先诊断缺失再做分析**：出现 NA 时先判比例与机制（MCAR/MAR/NMAR），禁止直接 `na.omit()` 了事；详见 @references/missing-data.md。
7. **结论跟着图走**：每张图配一句"看什么、说明什么"，不交付没有解读的图。
8. **环境降级不断链**：缺 ggplot2 走 base R 绘图，缺 dplyr 走内置 base R 汇总实现；降级必须在交付说明中写明原因与代价。
9. **进阶图表优先零扩展依赖写法**：`chart-recipes.md` 里每个图都给了零依赖版与扩展包版；除非扩展包是必需（如 circlize 和弦图），否则选零依赖版，少一个安装失败点。
10. **旧代码先迁移再美化**：接手教程/书附/历史脚本，先按 `legacy-code-migration.md` 对照表修（归档包、`size=`→`linewidth=`、`melt()`→`pivot_longer()`、rgdal→sf），改完小数据复现再上全量。

## 常用代码骨架

```r
library(ggplot2); library(dplyr); library(readr)

df <- read_csv("data/input.csv", show_col_types = FALSE)

p <- df |>
  mutate(group = factor(group, levels = c("Control", "Treat_A", "Treat_B"))) |>
  ggplot(aes(x = group, y = value, fill = group)) +
  geom_boxplot(width = 0.6, outlier.shape = NA, alpha = 0.85) +
  geom_jitter(width = 0.12, size = 1.2, alpha = 0.6) +
  scale_fill_brewer(palette = "Set2") +
  labs(x = NULL, y = "Response (mg/L)", fill = "Treatment",
       title = "Treatment effect on response", tag = "a") +
  theme_academic()

export_figure(p, "fig01_treatment_effect", use = "journal", width = 85, height = 70)
```
