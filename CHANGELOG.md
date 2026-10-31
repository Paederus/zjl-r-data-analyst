# 更新记录

## 1.3.2

署名一致性修正，不改能力范围。

- **移除智能体人格中的个人姓名**：`agents/zjl-r-data-analyst.md` 原先以一个人名自称（标题行与开场白各 1 处），与 `plugin.json` 的 `author`（ZhanJL）及 `displayName`（R 数据分析师）不一致。现改为职业称谓——标题为"R 语言数据分析师"，开场白为"你是一位长期从事数据分析与科学可视化的 R 语言专家"。
- 作者署名统一保留在 `plugin.json` 的 `author` 与 `README.md` 的作者段落，全包不再出现任何个人姓名。

## 1.3.1

审核前结构整改，不改能力范围。

- **修复脚本路径定位**：`Rscript` 会把路径中的空格编码为 `~+~`（`R 语言` → `R~+~语言`），原实现直接 `normalizePath()` 拿到不存在的路径，导致 `source()` 与 `read.csv()` 全部失败、退出码 1。`examples/quickstart.R` 现先还原再规范化，并逐级回退定位技能目录。
- **修复只读目录下的产物写入**：工作目录不可写时（沙箱、只读挂载），`quickstart.R` 自动改用临时目录；`chart-gallery.R` 在指定输出目录不可写时同样回退，不再逐张失败。
- **参考文档改为平台注入语法**：`SKILL.md` 与 `agents/zjl-r-data-analyst.md` 中 17 处 `references/*.md` 反引号引用改为 `@references/*.md`，确保技能加载时参考文档真正进入上下文。
- **agent 提示词去掉跨层相对路径**：`skills/r-data-workbench/scripts/...` 改为"技能目录下的 `scripts/` / `examples/`"，不再依赖工作目录。
- **新增环境问题上限约束**：装包失败不在多个镜像间反复重试，按"镜像安装 → 手动下载 → base R 降级"一次走完，把回合留给分析。
- `SKILL.md` 补 `displayName`、`version`、`license` 字段；`displayDescription.zh` 由 38 字补至 47 字（平台要求 40–50 字）。
- 新增本文件，版本号在 `plugin.json`、`SKILL.md`、`README.md` 三处贯通。

## 1.3.0

- 新增 `references/chart-recipes.md`：30 种进阶图表的可运行配方（云雨图、坡度图、量化波形图、冰柱图、边绑定、网格地图等），每段实测出图，并为已从 CRAN 归档的包给出零依赖替代写法。
- 新增 `references/legacy-code-migration.md`：老代码迁移对照表（`rgdal`/`rgeos`/`maptools` → `sf`、`size=` → `linewidth=`、`melt()` → `pivot_longer()` 等），按"报错 → 改法"组织。
- 新增 `examples/chart-gallery.R`：一键渲染 10 张代表图，缺包自动跳过并报告。
- `references/chart-catalog.md` 补齐图表类型并标注归档包；`SKILL.md`、agent 提示词、README 同步。

## 1.2.0

- 新增 `examples/quickstart.R` 一键自检与 `assets/sample-data.csv` 示例数据。
- 脚本内 `stop()` 改为提示，缺包与环境异常不再中断流程。
- `check_env.R` 增加国内镜像自动测速、失败换源、二进制安装、代理与用户库参数。

## 1.1.0

- 补充缺失数据处理（MCAR/MAR/NMAR 与多重插补）、统计建模与重抽样、学术图表规范等参考文档。

## 1.0.0

- 首个版本：数据准备、统计分析、ggplot2 图表体系、PNG/PDF 导出与可复现脚本交付。
