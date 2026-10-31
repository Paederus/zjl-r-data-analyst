# R 数据分析师（R Data Analyst）

> 版本 1.3.2 ｜ Agent 型专家 ｜ 作者 ZhanJL

一位能在真实环境中"把数据跑通、把图跑出来、把文件交付出去"的 R 语言专家：从数据清洗、统计建模，到 ggplot2 出版级图表，再到 PNG / PDF / SVG / TIFF 图片导出与可复现脚本交付。

> **含两个自检脚本，仅依赖 base R 即可运行验证。** `examples/quickstart.R` 验证整条分析链路（读数据 → 汇总 → 出图 → 校验），
> `examples/chart-gallery.R` 一键渲染 10 张进阶图表（缺包自动跳过、不中断）。两者在含空格或中文的路径、只读工作目录下都能跑通，
> 产物不可写时自动落到临时目录。

方法论体系基于公开领域知识整理：数据处理与统计方法（tidyverse、回归、方差分析）、ggplot2 各图表族的实现细节、图表选型与学术图表规范，全部文档为原创撰写，不含任何出版物的原文摘录。进阶图表配方（30 种）提炼自公开代码库 EasyChart/Beautiful-Visualization-with-R 的**方法论**（图表类型、数据形状、依赖选择），代码全部为本专家原创重写并逐段实测；该仓库无开源许可证，故不收录其任何代码与数据。

## 类型

Agent 型（单个 AI 专家）

## 功能

1. **数据准备**：CSV / Excel / SPSS / JSON 读写；dplyr / tidyr / data.table 清洗、宽长表转换、分组汇总、多表连接、缺失值与异常值处理。
2. **统计分析**：描述统计、t 检验与非参数检验、方差分析、线性 / 广义线性 / 混合效应回归、PCA / EFA 与聚类、时间序列、重抽样（置换检验 / 自助法）、监督分类（决策树 / 随机森林 / SVM）；配套诊断图、效应量与结果表格。
3. **缺失数据**：机制诊断（MCAR / MAR / NMAR）、缺失模式可视化、多重插补（mice 三步流程）。
4. **数据可视化**：ggplot2 图形语法（图层 / 标度 / 坐标 / 分面 / 主题），覆盖类别比较、数值关系、数据分布、时间序列、局部整体、高维、层次网络、地理空间等全部常见图表族，并善用 patchwork、ggrepel、ggpubr、ggraph、circlize 等扩展包；**内置 30 种进阶图表的实测配方**（云雨图、坡度图、量化波形图、冰柱图、边绑定图、网格地图等，每图含零扩展依赖的降级写法），并内置"老代码迁移对照表"处理已归档包（waffle、ggTimeSeries、rgdal 等）与过时语法。
5. **图片导出**：统一 `export_figure()` 出 PNG + PDF（base R 图形同样支持）；期刊规范（300 dpi、矢量优先、8 pt 字号、0.25 pt 线宽、单栏 85 mm / 双栏 170 mm、色盲友好配色、避免 rainbow）；中文字体注册与乱码处理；图形设备不可用时自动回退并显式提示。
6. **可复现交付**：脚本化流程、`set.seed()`、`sessionInfo()` 落盘、R Markdown / Quarto 报告。

## 使用示例

- 我有一份数据，帮我用 R 做探索性分析，并画出几张关键图表
- 用 ggplot2 画一张可直接投稿的分组箱线图，导出 300 dpi 的 PDF
- 用 R 做线性回归和方差分析，输出结果表格和诊断图
- 我的数据有缺失值，帮我判断缺失机制并做多重插补

## 技能资源

```
skills/r-data-workbench/
├── SKILL.md                                  # 路由入口 + 代码骨架 + 缺包安装策略
├── assets/
│   └── sample-data.csv                       # 示例数据（72 行 × 7 列，含缺失值）
├── examples/
│   ├── quickstart.R                          # 一键自检：base R 即可跑通，产出图/表并逐项校验
│   └── chart-gallery.R                       # 图表画廊自检：一键渲染 10 张进阶图表，缺包自动跳过
├── references/
│   ├── ggplot2-grammar.md                    # 图形语法速查（geom/stat/scale/coord/facet/theme/position）
│   ├── chart-catalog.md                      # 九大图表族全清单与实现要点
│   ├── chart-recipes.md                      # 30 种进阶图表实测配方（含零依赖降级写法）
│   ├── legacy-code-migration.md              # 老代码迁移对照表（归档包、过时语法逐条给改法）
│   ├── data-wrangling.md                     # 数据读取、整洁化、dplyr/tidyr/data.table
│   ├── statistics-modeling.md                # 检验、回归、方差分析、降维聚类、重抽样、分类、时间序列
│   ├── missing-data.md                       # 缺失机制诊断与多重插补
│   ├── academic-figure-spec.md               # 出版级规范（配色、字号、尺寸、拼版、导出格式与设备）
│   └── environment-and-troubleshooting.md    # 报错对照表、中文字体、缺包安装、设备回退
└── scripts/
    ├── check_env.R                           # 环境自检（图形设备冒烟测试；--install 镜像装包）
    ├── export_figure.R                       # 统一导出（PNG/PDF/SVG/TIFF，ggplot 与 base R 通用）
    ├── theme_academic.R                      # 学术主题、色盲友好色板、中文字体注册
    └── stats-utils.R                         # 分组汇总+置信区间、模型结果表、模型比较
```

## 环境要求与快速验证

- 依赖：R ≥ 4.0（`Rscript` 在 PATH 中）。ggplot2 / dplyr 等包**不是硬依赖**——未安装时脚本自动走 base R 回退路径，功能不受阻；专家首次使用时会引导按需安装。
- 一键验证（在任意目录执行，产物落在当前目录 `output/`；当前目录不可写时自动改用临时目录）：

```bash
Rscript <技能目录>/examples/quickstart.R
```

脚本会读取示例数据 → 分组汇总（含置信区间）→ 导出 2–3 张 PNG/PDF 图 → 写结果表与会话信息 → 逐项校验产物，全部通过时以退出码 0 结束并打印"全部通过"。

图表画廊自检（渲染 10 张进阶图表，验证 ggplot2 与扩展包链路，缺包自动跳过并报告）：

```bash
Rscript <技能目录>/examples/chart-gallery.R
```

所有脚本已在 R 4.5（macOS arm64）实测通过：`export_figure()` 在 cairo 设备不可用时自动回退到 `pdf()`/`png()` 并显式提示；`summarise_ci()` 在无 dplyr 环境下走 base R 实现且结果与 dplyr 版一致。**路径含空格或中文、工作目录只读两种场景也已单独实测通过**（前者的失败根因是 `Rscript` 把空格编码为 `~+~`，脚本已做还原）。

## 缺包安装（针对中国大陆网络优化）

R 包下载慢、装不上，绝大多数是**源选错**和**默认超时太短**造成的。本专家内置的 `check_env.R` 已按国内网络处理好这几点：

```bash
Rscript <技能目录>/scripts/check_env.R --install --optional   # 自动测速选源装包
Rscript <技能目录>/scripts/check_env.R --install --binary     # 免编译（macOS/Windows）
Rscript <技能目录>/scripts/check_env.R --install --proxy=http://127.0.0.1:7890
Rscript <技能目录>/scripts/check_env.R --list-mirrors         # 看各镜像延迟
Rscript <技能目录>/scripts/check_env.R --install --save       # 最优镜像永久写入 ~/.Rprofile
```

做对了四件事：

1. **自动测速选源**：安装前并发探测国内镜像（读 2 KB 校验索引，约 1–3 秒），选响应最快的那个；单个镜像安装失败**自动换下一个**，最多试 4 个。
2. **放宽超时**：默认 `timeout = 60` 秒，大包经常下不完，已改为 600 秒；下载改用 `libcurl`（支持 HTTPS 与续传）。
3. **优先二进制**：国内镜像同时提供源码、macOS arm64 与 Windows 预编译包，`--binary` 可直接免编译安装，绕开 `gfortran` 缺失等编译错误（实测 6 个包 2.4 秒装完）。
4. **用户库回退**：系统库无写权限时自动改用户库；macOS arm64 的用户库路径已按 `~/Library/R/arm64/4.x/library` 处理（含架构段，最常见的"装了却找不到"就出在这里）。

常用国内镜像（均实测可用、均有二进制）：

| 镜像 | URL |
|---|---|
| 阿里云 | `https://mirrors.aliyun.com/CRAN/` |
| 中科大 USTC | `https://mirrors.ustc.edu.cn/CRAN/` |
| 北外 BFSU | `https://mirrors.bfsu.edu.cn/CRAN/` |
| 清华 TUNA | `https://mirrors.tuna.tsinghua.edu.cn/CRAN/` |
| 南京大学 | `https://mirrors.nju.edu.cn/CRAN/` |
| 上海交大 | `https://mirror.sjtu.edu.cn/CRAN/` |
| 腾讯云 | `https://mirrors.cloud.tencent.com/CRAN/` |

不推荐：`cloud.r-project.org`（国内常几十 KB/s）、`packagemanager.posit.co`（国内大陆基本超时）。手动下载时的镜像内路径与报错对照表见 `references/environment-and-troubleshooting.md`。

## 头像

头像位于 `avatars/expert.png`（512×512，PNG，< 500KB）。如需替换为自定义头像，要求：PNG（推荐）或 JPG、512×512 px、单张不超过 500KB。

## 作者

ZhanJL（zhanjlmail@163.com）
