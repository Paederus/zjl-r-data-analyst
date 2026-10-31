# ggplot2 图形语法速查

ggplot2 的核心是"图形语法"：一张图 = 数据 + 映射 + 图层 + 标度 + 坐标 + 分面 + 主题。图层之间用 `+` 叠加，越往后越在上层。

## 1. 骨架

```r
ggplot(data = df, mapping = aes(x = var_x, y = var_y, color = grp)) +
  geom_point(size = 2, alpha = 0.7) +
  scale_color_brewer(palette = "Dark2") +
  coord_cartesian(ylim = c(0, 100)) +
  facet_wrap(~ year, ncol = 3) +
  labs(title = "", subtitle = "", x = "", y = "", caption = "") +
  theme_bw()
```

- `ggplot()` 只声明数据与默认映射，不画东西；必须至少加一个图层才会出图。
- `aes()` 在 `ggplot()` 中设默认映射，在 `geom_*()` 中设该图层专属映射或覆盖。
- **映射 vs 固定**：`aes(color = grp)` 是映射（随数据变）；`geom_point(color = "red")` 是固定（常量）。

## 2. 几何对象（geom）

| 需求 | 函数 | 要点 |
|---|---|---|
| 散点 | `geom_point()` | `shape = 21` 时同时支持 `fill` 与 `color` |
| 抖动散点 | `geom_jitter(width, height)` | 分组时配 `position_jitterdodge()` |
| 折线 | `geom_line()` | 多组需 `group = grp`，否则连线串组 |
| 阶梯线 | `geom_step()` | 阶梯方向由 `direction` 控制 |
| 柱形 | `geom_col()` / `geom_bar(stat = "identity")` | 已聚合数据用 `geom_col()`；计数用 `geom_bar()` |
| 直方图 | `geom_histogram(bins, binwidth)` | 分箱数直接影响形态，两种参数择一 |
| 密度 | `geom_density(fill, alpha)` | 多组叠加需 `alpha ≈ 0.3` |
| 箱形 | `geom_boxplot()` | `outlier.shape = NA` 后叠加抖动点，避免双重表达离群点 |
| 小提琴 | `geom_violin(scale = "area")` | 配 `geom_boxplot(width = 0.1)` 提供中位数信息 |
| 面积 | `geom_area()` | 需先 `stat = "identity"` 或已聚合 |
| 误差条 | `geom_errorbar()` / `geom_pointrange()` | 先 `summarise()` 算 `mean`、`sd`，或用 `stat_summary()` |
| 文本/标签 | `geom_text()` / `geom_label()` / `ggrepel::geom_text_repel()` | 点密集时必须用 repel，否则标签重叠 |
| 热力/网格 | `geom_tile()` | 配 `scale_fill_viridis_c()` |
| 等高线 | `geom_contour()` / `geom_contour_filled()` | 需 z 值网格 |
| 平滑 | `geom_smooth(method = "lm"/"loess")` | 默认带 95% 置信带，`se = FALSE` 可关闭 |
| 参考线 | `geom_hline()` / `geom_vline()` / `geom_abline()` | `linetype = "dashed"`，`color = "grey40"` |

**图元**（自造图形用）：`geom_rect()`、`geom_polygon()`、`geom_segment()`、`geom_curve()`、`geom_ribbon()`、`geom_linerange()`。

## 3. stat 与 geom 的关系

每个 `geom_*()` 都内含一个 `stat`，每个 `stat_*()` 都内含一个 `geom`。两者等价写法：

```r
stat_summary(fun = mean, geom = "point")          # 等价于
geom_point(stat = "summary", fun = mean)
```

常用汇总函数：`mean_se`、`mean_cl_normal`、`mean_sdl`、`median_hilow`（传给 `fun.data`）；`mean`、`median`（传给 `fun`）。

> 注意：ggplot2 3.0 之后 `fun.y` / `fun.ymin` / `fun.ymax` 已废弃，统一为 `fun`；旧代码需改写。

## 4. 视觉通道

| 通道 | 适用 | 说明 |
|---|---|---|
| `color` / `colour` | 点、线、轮廓 | 离散最多约 8 级，再多改用分面或直接标注 |
| `fill` | 面（柱、密度、多边形） | 只有 `shape = 21:25` 的点同时可设 `fill` |
| `alpha` | 全部 | 0–1，密集散点用 0.2–0.5 |
| `size` | 点、线 | 单位 pt；气泡图需 `scale_size_area(max_size = )` 保证面积正比 |
| `shape` | 离散 | 0–25，实心形状对黑白打印更友好 |
| `linetype` | 离散 | `"solid"/"dashed"/"dotted"/"dotdash"/"longdash"/"twodash"` |
| `angle` / `hjust` / `vjust` | 文本 | `hjust = 0` 左对齐，`1` 右对齐 |

**双通道冗余编码**：类别同时用颜色 + 形状（或颜色 + 线型），保证灰度打印与色盲读者仍可区分。

## 5. 标度（scale）

命名规则：`scale_<通道>_<类型>()`。

| 类型 | 示例 | 用途 |
|---|---|---|
| 手动 | `scale_fill_manual(values = c("#4E79A7","#F28E2B"))` | 品牌色 / 指定配色 |
| 定性色板 | `scale_color_brewer(palette = "Set2")`、`ggsci::scale_color_npg()` | ≤ 8 类离散变量 |
| 连续渐变 | `scale_fill_viridis_c()`、`scale_fill_gradient2(low, mid, high)` | 数值变量 |
| 连续分箱 | `scale_fill_viridis_b()`、`scale_fill_steps2()` | 分级统计图 |
| 轴 | `scale_y_continuous(labels = scales::percent, limits, breaks)` | 改标签/刻度 |
| 轴（日期） | `scale_x_date(date_breaks = "3 months", date_labels = "%Y-%m")` | 时间轴 |
| 轴（对数） | `scale_y_log10()` | 跨越多个数量级 |
| 反转 | `scale_y_reverse()` | 条形图自上而下排序 |

**因子顺序 = 图例顺序 = 绘图顺序**。想让柱子按数值排序，用 `reorder(x, value)` 或 `forcats::fct_reorder()`。

## 6. 坐标系（coord）

| 函数 | 用途 |
|---|---|
| `coord_cartesian(xlim, ylim)` | **推荐**的缩放方式：只改视窗，不丢数据（不参与平滑/统计计算） |
| `xlim()` / `ylim()` / `scale_*_continuous(limits=)` | 会**删除**范围外数据，影响 `geom_smooth()` 与箱线统计，慎用 |
| `coord_flip()` | 横向条形图（ggplot2 ≥ 3.3 可用 `orientation = "y"` 替代） |
| `coord_fixed(ratio)` | 等比例，地图与几何图形必需 |
| `coord_polar(theta, start)` | 饼图、圆环图、南丁格尔玫瑰图、径向柱图 |
| `coord_sf()` | 地理空间，配合 `geom_sf()` |
| `coord_trans()` | 变换坐标系而非数据 |

饼图最小实现：

```r
ggplot(df, aes(x = "", y = value, fill = category)) +
  geom_col(width = 1) +
  coord_polar(theta = "y") +
  theme_void()
```

## 7. 分面（facet）

```r
facet_wrap(~ var, ncol = 3, scales = "free_y")     # 单变量分面
facet_grid(rows ~ cols, scales = "free")           # 双变量网格
```

- `scales = "fixed"`（默认）便于横向比较；`"free_y"` 展示各组自身波动，但**必须提醒读者纵轴不同**。
- 分面标签用 `labeller = label_both` 可显示变量名与水平值。
- 分面过多（> 12）时改热力图、峰峦图或直接分文件出图。

## 8. 位置调整（position）

| 参数 | 效果 | 典型场景 |
|---|---|---|
| `"identity"` | 不调整 | 折线、散点 |
| `"stack"` | 堆叠 | 堆积柱形、面积图（`geom_col` 默认） |
| `"fill"` | 百分比堆叠 | 百分比堆积柱形 |
| `position_dodge(width = 0.8)` | 并列 | 簇状柱形；**同时用于 `geom_errorbar` 才能对齐** |
| `position_jitter(width = 0.15)` | 抖动 | 重叠散点 |
| `position_jitterdodge(dodge.width = 0.8)` | 并列抖动 | 箱形图 + 散点 |
| `position_stack(vjust = 0.5)` | 堆叠且标签居中 | 堆积柱内文字 |

## 9. 主题（theme）

结构三层：`theme_*()` 选基底 → `theme()` 微调 → `element_*()` 定细节。

```r
theme_bw(base_size = 11, base_family = "sans") +
  theme(
    panel.grid.minor  = element_blank(),
    panel.grid.major  = element_line(color = "grey90", linewidth = 0.3),  # 3.4+ 用 linewidth
    panel.border      = element_rect(color = "black", fill = NA, linewidth = 0.5),
    axis.text         = element_text(color = "black", size = 9),
    axis.title        = element_text(color = "black", size = 10),
    legend.position   = "right",
    legend.key        = element_blank(),
    plot.tag          = element_text(face = "bold", size = 12),
    plot.margin       = margin(5, 5, 5, 5)
  )
```

- 基底主题：`theme_bw()`/`theme_classic()`（论文）、`theme_minimal()`（简洁）、`theme_gray()`（默认，适合 PPT）、`theme_void()`（无轴，饼图/地图）。
- **`size` → `linewidth`**：ggplot2 ≥ 3.4 起线宽用 `linewidth`，`size` 只留给文本与点，旧代码会报废弃警告。
- 元素函数三兄弟：`element_text()`、`element_line()`、`element_rect()`，加 `element_blank()` 删除。
- 想全局固定：`theme_set(theme_academic())`，之后每张图自动继承。

## 10. 图例（guides）

```r
guides(fill = guide_legend(title = "Treatment", nrow = 1, order = 1),
       color = "none")                       # 关掉多余图例
```

- 图例顺序由因子水平决定，用 `scale_*_discrete(limits = c(...))` 可重排。
- 图例标题与轴标签一致用业务语言，不要出现 `value`、`grp` 这种变量名。

## 11. 扩展包生态

| 包 | 解决什么 |
|---|---|
| `patchwork` / `cowplot` | 多图拼版、a/b/c 自动标注 |
| `ggpubr` | 统计标注（`stat_compare_means()`）、期刊风格快速出图 |
| `ggrepel` | 标签防重叠 |
| `scales` | 百分比/千分位/科学计数标签 |
| `ggsci` | Nature/Science/Lancet/JAMA 配色 |
| `ggthemes` |  economist/wsj/fivethirtyeight 等风格 |
| `ggridges` | 峰峦图（分布随分组变化） |
| `GGally` | `ggpairs()` 矩阵散点、平行坐标 |
| `ggalluvial` | 桑基图、冲积图 |
| `ggraph` + `igraph` | 层次与网络关系图 |
| `circlize` | 和弦图、圆形布局 |
| `plot3D` / `rayshader` | 三维散点、曲面、柱形 |
| `sf` + `geom_sf()` | 地理空间矢量地图 |
| `treemapify` | 矩形树状图 |
| `showtext` / `systemfonts` | 中文字体注册与 PDF 渲染 |

## 12. 常见错误对照

| 现象 | 原因 | 修法 |
|---|---|---|
| 折线把所有点连成一团 | 缺 `group` 映射 | `aes(group = grp)` 或用 `color` 映射 |
| 柱形图高度都一样 | 用了 `geom_bar()` 但数据已聚合 | 改 `geom_col()` |
| 误差条与柱子错位 | `geom_errorbar` 没设同样的 `position_dodge` | 两处写相同 `width` |
| 图例出现 `fill` 与 `color` 两组 | 同一变量映射了两个通道且未合并 | 统一用一个通道，或 `guides(color = "none")` |
| 设了 `ylim` 后平滑曲线消失 | `ylim()` 删除了数据 | 改 `coord_cartesian(ylim = )` |
| 中文变方框 | 设备无中文字体 | `cairo_pdf` 或 `showtext_auto()` |
| 保存的图与预览不一致 | `ggsave` 尺寸变了导致字号相对变化 | 显式设 `width/height/units`，字号按目标尺寸定 |
