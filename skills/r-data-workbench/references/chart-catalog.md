# 图表族全清单与实现要点

按"想表达什么"分六大族（外加高维、层次、网络、地理四类关系拓展）。选图先问：**读者要看的是规模、关系、分布、趋势、构成，还是位置？**

> 本文件是"选图地图"：看哪种图适合、用哪个 geom。**每个图的完整可运行代码**（含零依赖降级写法、逐条实测过）在 `chart-recipes.md`；老代码跑不通先查 `legacy-code-migration.md`。标注 ⛔ 的包已从 CRAN 归档装不上，必须用替代写法。

---

## 一、类别比较型

数据形态：1 个类别变量 + 1 个数值变量（或多系列）。

| 图表 | 函数 | 要点 |
|---|---|---|
| 单系列柱形 | `geom_col()` | 基线必须为 0，禁止截断纵轴夸大差异 |
| 簇状柱形 | `geom_col(position = position_dodge(0.8))` | 系列 ≤ 4；更多改用分面或点图 |
| 堆积柱形 | `geom_col(position = "stack")` | 只适合"部分+整体"，组间总量差异大时易误读 |
| 百分比堆积 | `geom_col(position = "fill")` + `scale_y_continuous(labels = scales::percent)` | 突出结构比例，弱化绝对量 |
| 条形图（横） | `geom_col()` + `coord_flip()` | 类别名长时首选，按数值排序：`reorder(x, value)` |
| 克利夫兰点图 | `geom_point()` + `geom_segment()` 从 0 引出 | 类别多（> 10）时优于柱形，省墨水 |
| 坡度图 | `geom_line()` + `geom_point()`，x 为首末两个时点 | 只比较两个时点的变化，强调升降 |
| 南丁格尔玫瑰 | `geom_col()` + `coord_polar(start = 0)` | 面积非半径编码，跨圈比较不可靠；慎用于严谨场合 |
| 径向柱形/极坐标跨度 | `coord_polar(theta = "x")` | x 轴标签需 `theme(axis.text.x = element_text(angle = ...))` 调角度 |
| 雷达图 | `ggradar` 或 `coord_polar()` 手工构造 | 变量必须同向且标准化，轴顺序影响形状 |
| 词云 | `ggwordcloud::geom_text_wordcloud()` | 只表达词频量级，不能精确比较 |
| 不等宽柱形（马利美科图） | 矩形宽度与第二变量成比例 | 面积编码，需在图注说明两个维度的含义 |

**排序**：几乎总是按数值排序，读者的第一眼应该是"谁最大"。

---

## 二、数值关系型

| 图表 | 函数 | 要点 |
|---|---|---|
| 散点图 | `geom_point()` | 点 > 500 时 `alpha = 0.3`，或改 `geom_hex()` / `geom_bin2d()` |
| 带趋势散点 | `+ geom_smooth(method = "lm", se = TRUE)` | 非线性用 `"loess"`；分组回归需 `aes(color = grp)` |
| 气泡图 | `geom_point(aes(size = v3))` + `scale_size_area(max_size = 12)` | 面积正比于数值，不要用 `scale_size()` 的半径映射 |
| 带标签散点 | `ggrepel::geom_text_repel()` | 只标关键点，标全部等于没标 |
| 椭圆置信域 | `stat_ellipse(level = 0.95, geom = "polygon", alpha = 0.2)` | 需 `fill` 映射分组 |
| 矩阵散点 | `GGally::ggpairs(df, columns = 1:5, aes(color = grp))` | 变量 ≤ 8，否则挤成一团 |
| 等高线图 | `geom_contour()` / `geom_contour_filled()` | 需要规则网格 z 值，散点数据先 `interp::interp()` 或 `akima` |
| 三维曲面 | `plot3D::persp3D()` / `rayshader` | ggplot2 不支持真三维；投稿图慎用 |
| 3D 切面图 | `plot3D::slice3D()` | 三维体的切面视图；未实测，用前先小数据自测 |
| 三元相图 | `ggtern` | 三成分和为 1 的数据（矿物、配方）；历史上常滞后 ggplot2 大版本，装完先跑示例 |
| 等值面（核密度/插值） | `MASS::kde2d()` + `geom_raster()`；插值 `akima::interp()` 或 `loess()` | 散点热点分布的标准前置；见 recipes 2.3 |
| 相关系数热力图 | `geom_tile()` + `scale_fill_gradient2(low, mid = "white", high)` | 加 `geom_text()` 写数值，或只标显著项 |
| 瀑布图 | `geom_rect()` 逐个构造矩形，累计增减 | 起点与终点用不同颜色，中间项中性色 |
| 韦恩图 | `ggVennDiagram` | 仅 2–4 集合；> 4 集合信息失真 |

---

## 三、数据分布型

| 图表 | 函数 | 要点 |
|---|---|---|
| 直方图 | `geom_histogram(bins = 30)` | 分箱数极大影响结论，尝试 3 种 `bins` 看稳健性 |
| 核密度 | `geom_density(fill, alpha = 0.4)` | 分组 > 3 时改峰峦图或小提琴 |
| 箱形图 | `geom_boxplot()` | 只显示五数概括；样本 < 10 时信息不足 |
| 箱形 + 抖动点 | `geom_boxplot(outlier.shape = NA)` + `geom_jitter(width = .15, alpha = .5)` | **推荐默认组合**：既看分布又看样本量 |
| 小提琴图 | `geom_violin(scale = "area", trim = FALSE)` | 内部嵌 `geom_boxplot(width = .1, fill = "white")` |
| 点阵图 | `geom_dotplot(binaxis = "y", stackdir = "center")` | 小样本（< 30/组）比箱形更诚实 |
| 峰峦图 | `ggridges::geom_density_ridges(scale = 2)` | 分组多（5–20）时的分布比较首选 |
| 二维直方/密度 | `geom_bin2d()` / `geom_density_2d_filled()` | 大样本双变量结构 |
| 金字塔图/镜面图 | 一侧取负值 + `scale_y_continuous(labels = abs)` | 人口金字塔、双向对比 |
| 云雨图 | `density()` 自算半小提琴 + 箱形 + 抖动 | 同时看形状、五数与样本量；见 recipes 1.1 |
| QQ 图 | `geom_qq()` + `geom_qq_line()` | 正态性检查的标准图 |

---

## 四、时间序列型

| 图表 | 函数 | 要点 |
|---|---|---|
| 折线图 | `geom_line()` + `scale_x_date(date_breaks = "3 months", date_labels = "%Y-%m")` | 时间轴用 `Date`/`POSIXct` 类型，不要用字符 |
| 多系列折线 | `aes(color = series, group = series)` | 系列 > 5 时改为分面或高亮 + 灰底（`gghighlight`） |
| 面积图 | `geom_area(alpha = .7)` | 堆积面积需 `position = "stack"` |
| 带置信带 | `geom_ribbon(aes(ymin = lo, ymax = hi), alpha = .2)` | 预测区间可视化标准做法 |
| 标注事件 | `geom_vline(xintercept = as.Date("2020-01-23"), linetype = "dashed")` + `annotate("text", ...)` | 转折点必须标注，否则读者无法归因 |
| 日历图 | `calendarHeat()` / `geom_tile()` 按周-星期排布 | 日粒度数据、看周期性 |
| 螺旋图 | `coord_polar()` + 累积角度 | 长周期节律；解读成本高，需配说明 |
| 量化波形图 | 零依赖：`geom_ribbon()` + 中心对称堆叠 | ⛔ `ggTimeSeries`/`ggstream` 已归档；见 recipes 4.2 |
| 地平线图 | `ggHoriPlot`，或零依赖折叠色带 | 多序列紧凑对比，节省纵向空间 |
| 时间序列分解 | `forecast::ggseasonplot()` / `ggsubseriesplot()` | 季节性诊断 |

---

## 五、局部整体型

| 图表 | 函数 | 要点 |
|---|---|---|
| 饼图 | `geom_col()` + `coord_polar(theta = "y")` | 类别 ≤ 5，且必须有一项明显占优；否则改条形图 |
| 圆环图 | 同上 + `xlim(c(0.5, 1.5))` 挖孔 | 中心可放总量数字 |
| 复合饼图 | 饼图 + 局部放大子饼，`patchwork` 组合 | 子类需有引线或标注对应关系 |
| 马赛克图 | 零依赖 `geom_rect()`：宽=边际、高=条件 | ⛔ `ggmosaic` 已归档；见 recipes 5.2 |
| 华夫饼图 | 零依赖 `geom_tile()` 网格 | ⛔ `waffle` 已归档；见 recipes 5.1，标题须写明"1 格 = 多少" |
| 矩形树状图 | `treemapify::geom_treemap()` | 面积编码，适合层级 + 占比同时表达 |
| 圆堆积图 | `packcircles` + `ggraph` | 层级占比，视觉友好但难精确比较 |

---

## 六、高维与结构

| 图表 | 函数 | 要点 |
|---|---|---|
| 分面图 | `facet_wrap(~ var, scales = "free_y")` | 小多图（small multiples），最被低估的高维方案 |
| 平行坐标 | `GGally::ggparcoord()` | 变量需标准化，否则尺度主导形状 |
| RadViz | 零依赖：圆周锚点 + 权重质心 | 只作可分性直觉展示，不能读坐标 |
| 切尔诺夫脸谱 | `aplpack::faces()` | 趣味展示；五官权重无共识，严谨比较勿用 |
| 图标法（星形/柱形） | `GGally::ggstars()` 或手工分面 | 每个样本一个小图标；样本多时不可读 |
| PCA 双标图 | `prcomp()` + `factoextra::fviz_pca_biplot()` | 报告解释方差比例（PC1/PC2 %） |
| t-SNE / UMAP | `Rtsne` / `uwot` | 只保留局部邻域结构，**不要解读簇间距离** |
| 热力图（聚类） | `pheatmap` / `ComplexHeatmap` | 行标准化（`scale = "row"`）与色阶中点必须说明 |
| 表格图 | `gt` / `flextable` / `kableExtra` | 数据表也是可视化；数值右对齐、单位入表头 |

---

## 七、层次与网络

| 图表 | 包 / 函数 | 要点 |
|---|---|---|
| 节点链接树 | `ggraph(layout = "dendrogram")` | 边不加箭头，方向由布局体现 |
| 树形图 | `ggraph` + `geom_edge_diagonal()` | 层级 ≤ 5 可读性最佳 |
| 旭日图 | `ggraph(layout = "partition")` + `geom_node_arc_bar()` | 环形层级；ggraph 2.2 起需手动补 `depth`（见 recipes 7.1） |
| 冰柱图 | 零依赖 `geom_rect()` 逐层累加矩形 | 直角层级图；见 recipes 7.2 |
| 圆堆积 | `ggraph(layout = "circlepack")` | 面积编码占比 |
| 桑基图 | `ggalluvial::geom_alluvium()` + `geom_stratum()` | 流量守恒，节点顺序即阶段顺序 |
| 和弦图 | `circlize::chordDiagram()` | 矩阵输入，双向流量用非对称矩阵 |
| 弧线链接图 | `geom_curve(curvature = .3)` | 大量连线时改边绑定（`ggraph::geom_edge_bundle_path()`，ggraph ≥ 2.1；`tension` 控制束紧程度，没有 `strength` 参数） |
| 蜂巢网络 | `ggraph` + 六边形布局 | 减少连线交叉 |
| 径向热力图 | `geom_tile()` + `coord_polar()` | 角度=周期、半径=层级，"环形时间表" |
| 相邻矩阵 | `geom_tile()` 邻接矩阵 | 稠密网络比节点链接图更清晰 |

---

## 八、地理空间

| 图表 | 函数 | 要点 |
|---|---|---|
| 分级统计图 | `geom_sf(aes(fill = value))` + `scale_fill_viridis_c()` | 分级方法（等距/分位/自然断点）必须写明 |
| 点描地图 | `geom_sf()` + `geom_point()` | 点大小用 `scale_size_area()` |
| 气泡地图 | 同上 + 图例给参考圆 | 图例要画 3 个尺度参照圆 |
| 流向地图 | `geom_curve()` / `geom_sf()` 配箭头 | 起点终点坐标表 |
| 沃罗诺伊图 | `ggvoronoi::geom_voronoi()` | 表达服务区/影响范围 |
| 网格地图（邮标法） | 零依赖 `geom_rect()` 网格，或 `geofacet::facet_geo()` | 每格一行政区、面积统一；规避边界合规问题的稳妥替代，见 recipes 8.1 |
| 简化示意图 | 手工构造多边形 | 地铁线路图式抽象，牺牲地理精度换可读性 |

> **中国地图合规**：必须使用自然资源部标准地图服务（含审图号）或经审核的边界数据，不得自行拼接境外来源边界。生成的地图对外发布前需提示审图要求。

**地理空间技术栈提醒**：老代码的 `readOGR()`/`fortify()` 链路已死（rgdal/maptools 2023-10 归档），一律改 `sf::st_read()` + `geom_sf()`；迁移对照见 `legacy-code-migration.md` 3.2。

---

## 九、图组与拼版

```r
library(patchwork)
(p1 | p2) / (p3 | p4) +
  plot_annotation(tag_levels = "a",
                  title = "Overview of treatment effects",
                  theme = theme(plot.title = element_text(face = "bold")))

# 控制相对宽度与高度
p1 + p2 + plot_layout(widths = c(2, 1))
```

- 组合图共用图例：`patchwork::plot_layout(guides = "collect")` + `& theme(legend.position = "bottom")`。
- 各子图字号应一致；拼版后整体字号不得小于 7 pt。
