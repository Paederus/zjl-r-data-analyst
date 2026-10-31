# 出版级图表规范

面向论文投稿与正式汇报。核心原则：**图表是论据，不是装饰**——每个视觉元素都要承载信息，多余墨水一律删除。

## 1. 期刊通用要求（以 Nature 投稿指南为例）

| 项目 | 要求 |
|---|---|
| 颜色模式 | RGB（印刷最终版由出版社转换 CMYK） |
| 分辨率 | 位图 ≥ 300 dpi；线条图建议 600–1200 dpi |
| 格式优先级 | 矢量优先：`.pdf`、`.eps`、`.ai`、`.svg`；位图：`.tif`、`.png` |
| 字体 | 全图统一，Arial / Helvetica / Times New Roman；希腊字母用符号字体 |
| 字号 | 按最终印刷尺寸设定，最优 8 pt；不小于 6 pt |
| 线宽 | ≥ 0.25 pt（0.09 mm），坐标轴线与数据线都要满足 |
| 尺寸 | 按印刷实际大小作图：单栏 ≈ 85 mm，1.5 栏 ≈ 114 mm，双栏 ≈ 170 mm |
| 子图标注 | 左上角小写加粗 `a`、`b`、`c` |
| 配色 | 色彩区分度足够；**避免红/绿对比**（色觉障碍）；**避免 rainbow 色阶** |
| 填充 | 实色填充，避免斜线/网点纹理 |
| 背景 | 不加底纹、不加渐变背景 |
| 数字与单位 | 千分位用逗号；数值与单位间留一个空格；单位用领域通用写法 |
| 图注 | 单位、缩写、样本量 n、误差棒含义（SD/SEM/95%CI）、检验方法必须写明 |

> 不同期刊细节不同（Science、Cell、Lancet、各学科刊各有模板），投稿前须核对目标刊的 "instructions for authors → figures"。

## 2. 尺寸与字号换算

- 出版图**不要**先画大再缩小：缩小会让 8 pt 变小，线变细到看不清。
- 正确顺序：确定印刷宽度（mm）→ 以该尺寸为 `width` 绘图 → 在该尺寸下把字号设到 8–10 pt。
- `ggsave()` 的单位用 `"mm"` 或 `"in"`，务必显式声明；默认 7×7 in 会得到完全不对的字号比例。

```r
ggsave("fig.pdf", p, width = 85, height = 70, units = "mm", device = cairo_pdf)
ggsave("fig.png", p, width = 1700, height = 1400, units = "px", dpi = 300)
```

## 3. 配色

### 3.1 选色原则

1. **语义优先**：分组用定性色板，有序用序列色板，正负偏离用发散色板。
2. **可区分**：相邻色相角差 ≥ 60°；类别 > 8 时改用分面或直接标注，不要硬塞颜色。
3. **色盲安全**：避开红-绿单独对比；Okabe-Ito、ColorBrewer `Dark2`/`Set2`、`viridis` 均可。
4. **灰度可读**：打印成黑白后仍能区分（靠明度差 + 形状/线型冗余编码）。
5. **禁用 rainbow/jet**：亮度非单调，会制造虚假边界。

### 3.2 推荐色板

| 场景 | 方案 |
|---|---|
| 定性 ≤ 8 类 | `RColorBrewer::brewer.pal(n, "Set2"/"Dark2"/"Paired")`；`ggsci::scale_color_npg()`（Nature 风格） |
| 有序/连续 | `scale_fill_viridis_c()`；单色 `scale_fill_gradient(low = "#F7FBFF", high = "#08306B")` |
| 双向（正负/高低于均值） | `scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0)` |
| 指定品牌/机构色 | `scale_fill_manual(values = c(...))` |

### 3.3 Okabe-Ito 色盲友好八色

```r
okabe_ito <- c("#000000", "#E69F00", "#56B4E9", "#009E73",
               "#F0E442", "#0072B2", "#D55E00", "#CC79A7")
```

## 4. 版式细则

- **去掉图表垃圾（chartjunk）**：面板底色、多余网格线、3D 效果、阴影、装饰性图标。
- **网格线**：保留浅灰主网格（`grey90`，0.3 pt），删除次网格；或整体删除改用刻度。
- **边框**：`theme_classic()` 只留 L 形轴线；需要完整框用 `panel.border`，0.5 pt。
- **坐标轴**：柱形图基线为 0；折线图可非零起点但必须在图注声明。
- **刻度**：4–6 个主刻度为宜，标签不重叠；数值大时用 `scales::label_number(scale_cut = cut_short_scale())` 或改单位（万/百万）。
- **图例**：能直接标注就删图例（`geom_text_repel()` / `annotate()`）；图例标题用业务语言。
- **误差棒**：图注写清是 SD、SEM 还是 95% CI，以及 n。
- **显著性标记**：`*/**/***` 或 `p = 0.013` 直接写数值（后者更受推崇），并在图注说明检验方法。

## 5. 多图拼版

```r
library(patchwork)
combined <- (p1 | p2) / (p3 | p4) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(face = "bold", size = 10))
ggsave("fig_combined.pdf", combined, width = 170, height = 150, units = "mm", device = cairo_pdf)
```

- 子图共用同一套标度与图例，否则读者要反复对照。
- 需要各子图轴范围一致时用 `& coord_cartesian(ylim = common_ylim)`，不要各自 `ylim()`。
- 拼版后检查：字号是否仍 ≥ 7 pt、标签是否被裁切、图例是否重复。

## 6. 中文字体

```r
# 方案 A：showtext（推荐，PNG/PDF 都稳）
library(showtext)
showtext_auto()
font_add("SourceHan", "/System/Library/Fonts/Supplemental/Songti.ttc")  # macOS 示例
# Windows 常用：C:/Windows/Fonts/msyh.ttc（微软雅黑）、simsun.ttc（宋体）

# 方案 B：cairo_pdf 直接调系统字体
ggsave("fig.pdf", p, device = cairo_pdf, width = 85, height = 70, units = "mm")
```

- 中文论文常用组合：正文宋体/思源宋体 + 图内黑体/思源黑体。
- PDF 里若字体未嵌入，投稿系统可能报错；`cairo_pdf` 默认嵌入，`pdf()` 需手动 `embedFonts()`。
- 中英混排时数字与西文优先用 Arial，中文用思源黑体，避免基线与字重不一致。

## 7. 导出格式与设备实践

| 格式 | 设备 / 参数 | 适用场景 | 注意 |
|---|---|---|---|
| PDF | `pdf()` / `cairo_pdf()` / `ggsave(...)` | 论文、LaTeX、矢量首选 | 严重重叠的散点图，PDF 可能比 PNG 大得多（每点都存指令） |
| SVG | `svglite::svglite()` | 网页、Illustrator/Inkscape 二次编辑 | 浏览器支持好；部分排版软件支持不如 PDF |
| WMF/EMF | `win.metafile()`；跨平台用 `devEMF::emf()` | Word / PowerPoint 原生矢量 | 不支持 alpha 透明；默认仅限 Windows |
| PNG/TIFF | `png()` / `ragg::agg_png()` / `type = "cairo"` | 位图交付、Word/PPT | TIFF 建议 LZW 压缩，仅 LZW/不压缩在某些投稿系统安全 |

四条容易忽略的实践：

1. **矢量图要交给别人编辑时，务必关掉 Dingbats**：`ggsave(..., useDingbats = FALSE)`。否则默认的 `pdf()` 设备会拿 Zapf Dingbats 这套符号字体来画圆点，在 Illustrator 或 Inkscape 里打开就变成一个字母 q。
2. **位图跨平台渲染不一致**：引言的抗锯齿、alpha 透明、字体渲染在 Windows / macOS / Linux 上结果不同。要求一致时用 Cairo（`CairoPNG`、`type = "cairo"`）或 `ragg::agg_png()`。
3. **`ggsave(dpi = )` 实际是 ppi（每英寸像素数）**：印刷网点数（dpi）远高于此；300 ppi 的位图是投稿的安全线，线条图取 600–1200。
4. **非核心字体必须嵌入**：PDF 只保证 14 种核心字体（Times/Helvetica/Courier 等）通用；用了其他字体就应在投稿前嵌入（`extrafont::embed_fonts()` 或 Ghostscript），否则换机器可能显示错误或被投稿系统判为不合格。同一文档里放多张图时，可在最终文档中嵌入一次以控制体积。

```r
# 推荐的交付组合
ggsave("fig01.pdf", p, width = 85, height = 70, units = "mm", device = cairo_pdf)   # 投稿矢量
ggsave("fig01.png", p, width = 85, height = 70, units = "mm", dpi = 300, type = "cairo")  # 预览位图
```

> 用 `ggsave()` 而非手动 `pdf(); plot(); dev.off()`：后者在脚本报错时不会执行 `dev.off()`，图形设备会一直开着、PDF 文件也会损坏。

## 8. 交付检查表

- [ ] 尺寸与目标期刊单/双栏一致
- [ ] 位图 ≥ 300 dpi，矢量图字体已嵌入
- [ ] 所有字号 ≥ 6 pt（建议 8 pt），线宽 ≥ 0.25 pt
- [ ] 无 rainbow 色阶，红绿未单独用于对比
- [ ] 轴标签带单位，图例标题可读
- [ ] 子图标注 a/b/c 齐全且位置一致
- [ ] 图注含 n、误差棒定义、检验方法、缩写释义
- [ ] 图中数值与正文/表格一致（抽查）
- [ ] 中文无乱码、无方框、无重叠
