# 图表配方库：进阶图表的可运行写法

> 本文件提炼自《R语言数据可视化之美》配套代码库（EasyChart/Beautiful-Visualization-with-R，9 大图表族 168 个脚本）的**方法论**；全部代码为本技能原创重写（原仓库无开源许可证，禁止照抄），并已在 R 4.5.3 + ggplot2 4.0.2 逐段实测出图。原书基于 R 3.3，写法已过时的部分一律改为现代写法，详见 `legacy-code-migration.md`。

**通用约定**：

- 只依赖 `ggplot2` 的配方标注「零扩展依赖」——缺包降级时优先用这些。
- 三类高频坑先记住：
  1. **同一张图里不能混用离散 x 与连续 x**（如手写半小提琴 + 箱形图）。解法：全部转成数值位置，再用 `scale_x_continuous(breaks=, labels=)` 贴回类别标签。
  2. **父节点/分组索引时用 `%in%` 不用 `==`**：`==` 遇到 NA 会把 NA 行带进子集，导致后续计算全变 NA。
  3. **负值双向图**（金字塔、镜面图）配 `scale_y_continuous(labels = abs)`，否则轴标签出现负号。
- 中文乱码/方框：设备用 `cairo_pdf`，位图用 `png(type = "cairo")`，或脚本顶部 `showtext::showtext_auto()`。

---

## 一、数据分布型

### 1.1 云雨图（半小提琴 + 箱形 + 抖动点）— 零扩展依赖

比小提琴图信息更全：右半是密度轮廓，中间箱形，左侧原始点。样本量一目了然。

```r
# 数据形状：data.frame(group = 因子, value = 数值)
half_violin <- function(data, g, v, width = 0.42, n = 512) {
  lv <- levels(factor(data[[g]]))
  pieces <- lapply(seq_along(lv), function(i) {
    x <- data[[v]][data[[g]] == lv[i]]
    d <- density(x[is.finite(x)], n = n)
    data.frame(g = lv[i], x = i + d$y / max(d$y) * width, y = d$x)
  })
  poly <- do.call(rbind, pieces)
  poly$g <- factor(poly$g, levels = lv)
  poly
}
poly <- half_violin(df, "group", "value")
df$pos <- as.numeric(df$group)          # 关键：全部转数值位置
poly$pos <- as.numeric(poly$g)
ggplot(df, aes(x = pos, y = value)) +
  geom_polygon(data = poly, aes(x = pos + (x - pos), y = y, fill = g, group = g),
               alpha = .55, colour = NA) +
  geom_boxplot(aes(group = group, fill = group), width = .1, outlier.shape = NA,
               position = position_nudge(x = -.18)) +
  geom_point(aes(colour = group), position = position_jitter(width = .05),
             size = 1.1, alpha = .5) +
  scale_x_continuous(breaks = 1:3, labels = levels(df$group)) +
  scale_fill_brewer(palette = "Set2") + scale_colour_brewer(palette = "Set2") +
  theme_classic() + theme(legend.position = "none")
```

**坑**：不要用 `geom_violin` 想当然做半小提琴——它没有"半"参数；上面用 `density()` 自算多边形是零依赖最稳做法。

### 1.2 带显著性括号的箱形图 — 零扩展依赖

```r
pr <- combn(levels(df$group), 2, simplify = FALSE)
pv <- vapply(pr, function(g) t.test(value ~ group, data = subset(df, group %in% g))$p.value, 0)
star <- ifelse(pv < .001, "***", ifelse(pv < .01, "**", ifelse(pv < .05, "*", "ns")))
ymax <- max(df$value)
br <- data.frame(x1 = match(sapply(pr, `[`, 1), levels(df$group)),
                 x2 = match(sapply(pr, `[`, 2), levels(df$group)),
                 y = ymax * (1.02 + seq_along(pv) * .11), lab = star)
ggplot(df, aes(group, value)) +
  geom_boxplot(aes(fill = group), width = .55, outlier.shape = NA, alpha = .85) +
  geom_segment(data = br, aes(x = x1, xend = x2, y = y, yend = y), linewidth = .4) +
  geom_text(data = br, aes((x1 + x2) / 2, y + ymax * .015, label = lab), size = 3.2) +
  scale_fill_brewer(palette = "Set2") + theme_classic() + theme(legend.position = "none")
```

**要点**：括号逐层抬升（`seq_along(pv) * .11`）避免重叠；比较组数多时只挑关心的 2–3 对，全画会糊。装了 `ggpubr` 可用 `stat_compare_means()` 少写代码，效果相同。

### 1.3 人口金字塔 / 镜面图 — 零扩展依赖

```r
# 一侧取负值 + coord_flip + abs 标签
pyr$n <- ifelse(pyr$sex == "F", -pyr$n, pyr$n)
ggplot(pyr, aes(group, n, fill = sex)) +
  geom_col(width = .7) + coord_flip() +
  scale_y_continuous(labels = abs) +
  scale_fill_manual(values = c(F = "#D6604D", M = "#4393C3")) +
  theme_classic() + theme(legend.position = "top")
```

### 1.4 峰峦图 — 两个版本

```r
# 版本 A：ggridges（中位线 + 四分位线，首选）
library(ggridges)
ggplot(d, aes(v, g, fill = g)) +
  geom_density_ridges(scale = 2.2, rel_min_height = .01, alpha = .8,
                      quantile_lines = TRUE, quantiles = c(.25, .5, .75)) +
  scale_fill_viridis_d(guide = "none") + theme_ridges(font_size = 10)

# 版本 B：零扩展依赖（density() 自算，逐组下移）
dens <- do.call(rbind, lapply(seq_along(lv), function(i) {
  d <- density(df$value[df$group == lv[i]])
  data.frame(g = lv[i], x = d$x, y = d$y / max(d$y) * .9 + (length(lv) - i) * 0.5)
}))
ggplot(dens, aes(x, y, fill = g)) +
  geom_polygon(aes(group = g), alpha = .8, colour = "grey20", linewidth = .3) +
  theme_classic() + theme(legend.position = "none", axis.line.y = element_blank())
```

---

## 二、数据关系型

### 2.1 四维散点 + 参考圆图例 — 零扩展依赖

x、y、面积、颜色四编码同时用。**面积必须用 `scale_size_area()`**（半径映射会夸大差异），图例给 3 个参考圆。

```r
ggplot(b, aes(x, y)) +
  geom_point(aes(size = v, fill = cat), shape = 21, colour = "grey20", alpha = .8) +
  scale_size_area(max_size = 12, breaks = c(10, 30, 50)) +
  scale_fill_brewer(palette = "Set1") +
  guides(fill = guide_legend(override.aes = list(size = 4), order = 1),
         size = guide_legend(order = 2)) +
  theme_bw()
```

### 2.2 相关系数热力图（下三角 + 星号）— 零扩展依赖

```r
m <- cor(df_num); k <- nrow(m)
grid <- data.frame(v1 = rep(rownames(m), times = k), v2 = rep(colnames(m), each = k), r = as.vector(m))
grid$lab <- ""
for (i in 1:k) for (j in 1:k) if (i >= j) {        # 只放下三角
  p <- suppressWarnings(cor.test(df_num[[i]], df_num[[j]])$p.value)
  s <- if (i == j) "" else if (p < .001) "***" else if (p < .01) "**" else if (p < .05) "*" else ""
  grid$lab[grid$v1 == rownames(m)[i] & grid$v2 == colnames(m)[j]] <- sprintf("%.2f%s", m[i,j], s)
}
grid$r[as.numeric(grid$v1) < as.numeric(grid$v2)] <- NA   # 上三角留白
ggplot(grid, aes(v1, v2, fill = r)) +
  geom_tile(colour = "white", linewidth = .6) + geom_text(aes(label = lab), size = 3) +
  scale_fill_gradient2(low = "#4575B4", mid = "white", high = "#D73027",
                       midpoint = 0, limits = c(-1, 1), na.value = "white") +
  coord_equal() + theme_minimal() + theme(panel.grid = element_blank())
```

**要点**：相关矩阵必须用**发散色阶且中点固定为 0**；用红绿对比对色觉读者不友好。`corrplot` 一行可出图，但要进论文排版时上面的 ggplot 版更可控。

### 2.3 等值面：核密度图与插值图 — 零扩展依赖（可选 akima 加速）

散点地图/热点分布的标准前置步骤。

```r
# (a) 核密度等值面：MASS::kde2d 自带于 base R 环境
kd <- MASS::kde2d(pts$x, pts$y, n = 120, lims = c(0, 10, 0, 10))
g <- expand.grid(x = kd$x, y = kd$y); g$d <- as.vector(kd$z)
ggplot(g, aes(x, y, fill = d)) +
  geom_raster() +
  geom_contour(aes(z = d), colour = "white", linewidth = .25, alpha = .5) +
  scale_fill_gradientn(colours = c("#F7FBFF", "#6BAED6", "#08306B")) +
  coord_equal() + theme_void()

# (b) 不规则散点的 z 插值：有 akima 用 akima::interp()，没有就用 loess()
fit <- loess(z ~ x * y, data = pts, span = .5)
g2 <- expand.grid(x = seq(0, 10, length.out = 100), y = seq(0, 10, length.out = 100))
g2$z <- as.vector(predict(fit, newdata = g2))   # 注意 predict 返回矩阵，必须 as.vector
```

**坑**：`predict.loess` 对网格 newdata 返回**矩阵**，直接赋值给数据框列会错位——必须 `as.vector()`。

---

## 三、类别比较型

### 3.1 坡度图 — 零扩展依赖

两个（或多个）时点的升降对比，比双柱形图克制得多。

```r
# 宽数据：每行一个对象，列为各时点；长转短后画线
long <- data.frame(country = sl$country, year = rep(yrs, each = nrow(sl)),
                   value = as.vector(as.matrix(sl[, -1])))
long$hi <- long$country %in% c("A", "C")     # 只高亮重点对象
ggplot(long, aes(year, value)) +
  geom_line(aes(group = country, colour = hi), linewidth = .8) +
  geom_point(aes(colour = hi), size = 2.4) +
  geom_text(data = subset(long, year == max(year)),
            aes(label = country, colour = hi), hjust = -.35, show.legend = FALSE) +
  scale_colour_manual(values = c(`TRUE` = "#D73027", `FALSE` = "grey65")) +
  scale_x_continuous(breaks = yrs, expand = expansion(mult = c(.05, .12))) +
  theme_classic() + theme(legend.position = "none")
```

**要点**：灰色打底 + 少量高亮是" spaghetti 图去糊"的标准手法；末端直接标名字，不用图例。

### 3.2 不等宽柱形（Marimekko）— 零扩展依赖

宽度编码一个变量、高度编码构成，一张图讲两个维度。

```r
d$share <- d$total / sum(d$total)
d$xmax <- cumsum(d$share); d$xmin <- d$xmax - d$share
long <- rbind(data.frame(seg = d$seg, xmin = d$xmin, xmax = d$xmax, s = "s1", v = d$s1 / d$total),
              data.frame(seg = d$seg, xmin = d$xmin, xmax = d$xmax, s = "s2", v = d$s2 / d$total),
              data.frame(seg = d$seg, xmin = d$xmin, xmax = d$xmax, s = "s3", v = d$s3 / d$total))
long <- long[order(long$seg, long$s), ]
long$ymax <- ave(long$v, long$seg, FUN = cumsum); long$ymin <- long$ymax - long$v
ggplot(long) +
  geom_rect(aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = s),
            colour = "white", linewidth = .6) +
  scale_fill_brewer(palette = "Blues") +
  scale_y_continuous(labels = scales::percent) + theme_minimal()
```

### 3.3 径向柱形图 — 零扩展依赖

```r
d$id <- seq_len(nrow(d))
ggplot(d) +
  geom_rect(aes(xmin = id - .42, xmax = id + .42, ymin = 0, ymax = value, fill = value)) +
  coord_polar(start = -pi / 12) +
  scale_fill_gradient(low = "#FEE0D2", high = "#B2182B") +
  scale_x_continuous(breaks = d$id, labels = d$item) +
  theme_minimal() + theme(axis.text.y = element_blank())
```

**慎用**：极坐标下面积被外圈放大，跨类别精确比较不可靠；汇报图可用，论文图改条形图。

### 3.4 克利夫兰点图 — 零扩展依赖

```r
ggplot(d, aes(value, reorder(item, value))) +
  geom_segment(aes(x = 0, xend = value, yend = reorder(item, value)),
               colour = "grey70", linewidth = .5) +
  geom_point(colour = "#2166AC", size = 2.6) +
  geom_text(aes(label = value), hjust = -.4, size = 3) +
  scale_x_continuous(expand = expansion(mult = c(0, .12))) +
  theme_classic()
```

类别 > 10 时替代柱形图的首选；`reorder()` 必须写两处（点和线段），漏一处排序就不一致。

### 3.5 雷达图 — 零扩展依赖

```r
vars <- c("速度", "力量", "耐力", "技巧", "防守")
rad$id <- as.numeric(rad$item)                       # 因子转角度
close <- do.call(rbind, lapply(split(rad, rad$player),
  function(d) rbind(d, transform(d[1, ], id = length(vars) + 1))))   # 闭合多边形
ggplot(rad, aes(id, score, group = player, colour = player)) +
  geom_polygon(data = close, aes(fill = player), alpha = .18, linewidth = .7) +
  geom_point(size = 2) + coord_polar() +
  scale_x_continuous(breaks = 1:5, labels = vars, limits = c(0.5, 5.5)) +
  scale_y_continuous(limits = c(0, 100)) + theme_minimal()
```

**坑**：多边形必须闭合（首点追加到尾）；各轴必须同向且同量纲，否则形状无意义。能不画就不画——分组条形/线图通常更诚实。

---

## 四、时间序列型

### 4.1 螺旋柱形图 — 零扩展依赖

```r
grid$theta <- (grid$day - 1) * 24 + grid$hour       # 角度 = 天×24+时
ggplot(grid) +
  geom_rect(aes(xmin = theta - .45, xmax = theta + .45,
                ymin = day - 1, ymax = day - 1 + value / max(value) * .9, fill = value)) +
  coord_polar(start = -pi / 2) +
  scale_fill_viridis_c(option = "C") +
  scale_x_continuous(breaks = seq(1, days * 24, 24), labels = paste0("D", 1:days)) +
  theme_minimal() + theme(axis.text.y = element_blank())
```

适合看日周期 + 长期趋势叠加；必须配说明，否则读者解不出螺旋。

### 4.2 量化波形图（streamgraph）— 零扩展依赖

> 原书用 `ggTimeSeries::stat_steamgraph()`，**该包已从 CRAN 归档**，装不上。下面是纯 ggplot2 等价实现：上下对称堆叠。

```r
m <- m[order(m$s, m$t), ]
m$base <- ave(m$v, m$t, FUN = function(z) c(0, cumsum(z)[-length(z)])) -
          ave(m$v, m$t, FUN = sum) / 2      # 每个时间点整体下移一半 → 中心对称
m$top <- m$base + m$v
ggplot(m, aes(t)) +
  geom_ribbon(aes(ymin = base, ymax = top, fill = s), alpha = .9,
              colour = "white", linewidth = .2) +
  scale_fill_brewer(palette = "Set2") + theme_minimal()
```

**要点**：先按系列再按时间排序，`cumsum` 才不错位；系列顺序按峰值排序视觉更稳。

### 4.3 地平线图 — 零扩展依赖

多条长序列折叠成色带，纵向空间省 60% 以上。

```r
m$fold <- ifelse(m$v < 0, 0, pmin(floor(m$v) + 1, 3))    # 值分档
ggplot(m, aes(t, fold + s * 1.2, group = s, fill = factor(fold))) +
  geom_area(position = "identity", colour = "white", linewidth = .15) +
  scale_fill_manual(values = c("#DEEBF7", "#9ECAE1", "#4292C6", "#08519C")) +
  theme_minimal() + theme(panel.grid = element_blank())
```

**要点**：必须配"颜色越深 = 数值越高"的图例说明；单序列超过 3 档就难读。

---

## 五、局部整体型

### 5.1 华夫饼图 — 零扩展依赖

> 原书用 `waffle` 包，**已从 CRAN 归档**。10 行手写：

```r
units <- rep(d$cat, d$n)                                  # 按计数展开
waff <- data.frame(cat = units,
                   row = rep(1:10, each = 10)[seq_along(units)],
                   col = rep(1:10, times = 10)[seq_along(units)])
ggplot(waff, aes(col, row, fill = cat)) +
  geom_tile(colour = "white", linewidth = 1.2) + coord_equal() +
  scale_fill_brewer(palette = "Set2") + theme_void()
```

标题写明"1 格 = 1 人/1%"，否则读者不知道数格子。

### 5.2 马赛克图 — 零扩展依赖

> `ggmosaic` 已从 CRAN 归档。两个分类变量的联列表手写：

```r
tb$w <- ave(tb$n, tb$batch, FUN = sum) / sum(tb$n)       # 列宽 = 边际占比
tb <- tb[order(tb$batch, tb$sex), ]
tb$h <- ave(tb$n, tb$batch, FUN = function(z) z / sum(z)) # 列内高度 = 条件占比
tb$xmax <- ave(tb$w, tb$batch, FUN = cumsum); tb$xmin <- tb$xmax - tb$w
tb$ymax <- ave(tb$h, tb$batch, FUN = cumsum); tb$ymin <- tb$ymax - tb$h
ggplot(tb) +
  geom_rect(aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = sex),
            colour = "white", linewidth = 1) +
  geom_text(aes((xmin + xmax) / 2, (ymin + ymax) / 2, label = n), size = 3) +
  scale_fill_manual(values = c(F = "#D6604D", M = "#4393C3")) + theme_minimal()
```

**坑**：`cumsum` 分组用 `ave(..., FUN = cumsum)`，直接 `cumsum` 会跨组累加；零计数单元要先滤掉。

---

## 六、高维数据型

### 6.1 平行坐标 — 零扩展依赖

```r
d <- as.data.frame(scale(df_num)); d$id <- rownames(d); d$grp <- df$grp
long <- data.frame(id = d$id, grp = d$grp,
                   var = factor(rep(vars, each = nrow(d)), levels = vars),
                   idx = rep(seq_along(vars), each = nrow(d)),
                   z = as.vector(as.matrix(d[, vars])))
ggplot(long, aes(idx, z, group = id, colour = grp)) +
  geom_line(linewidth = .45, alpha = .6) +
  scale_x_continuous(breaks = seq_along(vars), labels = vars) +
  theme_classic()
```

**必做**：先 `scale()` 标准化，否则量纲大的变量主导整张图。变量 > 10 时降采样线条。

### 6.2 RadViz — 零扩展依赖

每个变量是圆周上一个锚点，样本位置 = 各维权重加权的锚点质心。

```r
X <- as.matrix(scale(df_num))
ang <- seq(0, 2 * pi, length.out = length(vars) + 1)[-(length(vars) + 1)]
anchor <- data.frame(v = vars, ax = cos(ang), ay = sin(ang))
w <- exp(X - apply(X, 1, max)); w <- w / rowSums(w)      # 归一成正权重
pos <- data.frame(x = as.vector(w %*% anchor$ax), y = as.vector(w %*% anchor$ay),
                  grp = df$grp)
ggplot(pos, aes(x, y)) +
  geom_point(aes(fill = grp), shape = 21, size = 2.6, colour = "grey20") +
  geom_text(data = anchor, aes(ax * 1.1, ay * 1.1, label = v), size = 3.4) +
  coord_equal() + theme_void()
```

只作可分性直觉展示，**不能**读坐标数值；聚类重排锚点会显著改变形状，需在图注写明锚点顺序。

---

## 七、层次与网络

### 7.1 旭日图 / 圆堆积图 — ggraph + igraph

```r
library(ggraph); library(igraph)
g <- graph_from_data_frame(edges)                          # edges: from,to 两列
V(g)$depth <- as.numeric(distances(g, v = "root")[1, V(g)$name])   # 手动补 depth

# 旭日图（径向层级）
ggraph(g, layout = "partition", circular = TRUE) +
  geom_node_arc_bar(aes(fill = depth), colour = "white", linewidth = .4) +
  geom_node_text(aes(label = name, filter = depth <= 1), size = 3) +
  coord_fixed() + scale_fill_distiller(palette = "Blues", guide = "none") +
  theme_void()

# 圆堆积图（换布局即可）
ggraph(g, layout = "circlepack") +
  geom_node_circle(aes(r = r, fill = depth), colour = "white", linewidth = .3) +
  coord_fixed() + theme_void()
```

**坑**：ggraph 2.2 起 `tree`/`dendrogram` 布局不再自动带 `depth` 列，`aes(filter = depth...)` 会报 `object 'depth' not found`——用 `distances()` 自己算。叶子多时只在 depth ≤ 1 标签。

### 7.2 冰柱图 — 零扩展依赖

不想装 ggraph 时的直角层级图；宽矩形 = 高层，窄矩形 = 叶子。

```r
nodes <- data.frame(name, parent, value)     # value 仅叶子有；NA 安全用 %in%
nodes$depth <- 0
for (i in seq_len(nrow(nodes)))
  nodes$depth[i] <- if (is.na(nodes$parent[i])) 0
                    else nodes$depth[match(nodes$parent[i], nodes$name)] + 1
lf <- nodes$name[!is.na(nodes$value)]
nodes$xmin <- NA; nodes$xmax <- NA
nodes[nodes$name %in% lf, c("xmin", "xmax")] <- cbind(seq_along(lf) - 1, seq_along(lf))
for (d in rev(sort(unique(nodes$depth))))
  for (i in which(nodes$depth == d & is.na(nodes$value))) {
    ch <- nodes$name[nodes$parent %in% nodes$name[i]]   # %in% 对 NA 安全，== 不安全
    nodes$xmin[i] <- min(nodes$xmin[match(ch, nodes$name)])
    nodes$xmax[i] <- max(nodes$xmax[match(ch, nodes$name)])
  }
ggplot(nodes) +
  geom_rect(aes(xmin = xmin, xmax = xmax, ymin = -depth, ymax = -depth + .92,
                fill = factor(depth)), colour = "white", linewidth = .8) +
  scale_fill_brewer(palette = "Blues", guide = "none") + theme_void()
```

### 7.3 矩形树状图 — treemapify

```r
library(treemapify)
ggplot(d, aes(area = n, fill = dept, label = team, subgroup = dept)) +
  geom_treemap(colour = "white", size = 1.5) +
  geom_treemap_subgroup_border(colour = "white", size = 3) +
  geom_treemap_text(colour = "white", place = "centre") +
  geom_treemap_subgroup_text(colour = "white", place = "topleft", alpha = .8) +
  scale_fill_brewer(palette = "Set2") + theme(legend.position = "none")
```

**坑**：treemapify 用的是 `size` 不是 `linewidth`（传 `linewidth` 会静默忽略）。

### 7.4 桑基图 — ggalluvial

```r
library(ggalluvial)
# long 格式：x=阶段, stratum=层名, id=个体流, flow=流量
ggplot(long, aes(x = x, y = flow, alluvium = id, stratum = stratum)) +
  geom_flow(aes(fill = factor(id)), alpha = .45, width = .28) +
  geom_stratum(width = .28, fill = "grey95", colour = "grey40") +
  geom_text(stat = "stratum", aes(label = after_stat(stratum)), size = 3) +
  theme_minimal() + theme(legend.position = "none")
```

**坑**：每个 (id, x) 组合只能一行，重复行要先 `!duplicated(paste(id, x))` 去重；`..stratum..` 现代写法是 `after_stat(stratum)`。

### 7.5 和弦图 — circlize（base 图形，非 ggplot）

```r
library(circlize)
par(mar = c(1, 1, 1, 1))
chordDiagram(m, transparency = .35, annotationTrack = c("name", "grid"),
             directional = 1, direction.type = "arrows", link.arr.type = "big.arrow")
circos.clear()          # 忘了这行，下一张图会叠在弦上
```

**坑**：`chordDiagram()` 画在 base 图形系统上，**不能直接接 ggplot 图层**，混排要用 `circlize` 的 `circos.par`/网格或导出成独立图片再拼版；结束时必须 `circos.clear()`。

### 7.6 边绑定图 — ggraph ≥ 2.1

大规模网络连线交叉成麻团时的救星。

```r
ggraph(g, layout = "dendrogram", circular = TRUE) +
  geom_edge_bundle_path(colour = "grey35", alpha = .6, linewidth = .45, tension = .85) +
  geom_node_point(aes(filter = depth == 1), size = 2.4) +
  coord_fixed() + theme_void()
```

**坑**：`tension` 越大束得越紧但失真也越大；`strength` 不是它的参数（会静默忽略）。旧版 ggraph 没有此几何，回退 `geom_edge_arc()` + 透明度。

### 7.7 径向热力图 — 零扩展依赖

角度表周期、半径表层级/深度，适合 24 小时 × 多天、基因分组等"环形时间表"。

```r
d <- expand.grid(ring = 1:4, sector = 1:36)
ggplot(d) +
  geom_tile(aes(x = sector, y = ring, fill = v), colour = "white", linewidth = .3) +
  coord_polar(start = -pi / 36) +
  scale_fill_gradient2(low = "#4575B4", mid = "white", high = "#D73027") +
  theme_minimal() + theme(axis.text.y = element_blank())
```

---

## 八、地理空间型

**合规红线（中国大陆）**：任何真实中国地图必须使用自然资源部标准地图服务（bzdt.ch.mnr.gov.cn，带审图号）或天地图数据；不要用境外来源（如 GADM）的省界直接出图对外发布。下面配方用合成网格演示方法，替换成合规边界数据后同样适用。

### 8.1 网格地图（邮标法 / 简化示意）— 零扩展依赖

每格一个行政区，面积统一、位置近似，规避边界数据合规问题，也最适合小倍数对比。

```r
grid <- expand.grid(gx = 1:8, gy = 1:6)
grid$v <- ...                                   # 按行政区聚合的指标
ggplot(grid) +
  geom_rect(aes(xmin = gx - .46, xmax = gx + .46, ymin = gy - .46, ymax = gy + .46, fill = v),
            colour = "white", linewidth = .8) +
  geom_text(aes(gx, gy, label = lab), size = 2.6, colour = "white") +
  scale_fill_gradientn(colours = c("#F7FCF5", "#74C476", "#00441B")) +
  coord_equal() + theme_void()
```

`geofacet` 包可按官方网格布局做省份分面（`facet_geo()`），但布局模板仍需自备；手写 `geom_tile` 网格同样可行且无额外依赖（已实测）。

### 8.2 标签防重叠 — ggrepel（小包，秒装）

```r
library(ggrepel)
ggplot(d, aes(wt, mpg, label = name)) +
  geom_point(size = 1.8) +
  geom_text_repel(size = 2.6, max.overlaps = 20, min.segment.length = .2, seed = 1)
```

**坑**：必须设 `seed`，否则每次渲染标签位置都不同，脚本不可复现。

---

## 九、已实测之外的进阶方向（未实测，按需自验）

以下图型原书有代码，但其依赖在本环境未能完成实测（沙箱限制），使用前先小数据自测：

| 图型 | 包 | 备注 |
|---|---|---|
| 三元相图 | `ggtern` | 仍在 CRAN，但历史上有滞后 ggplot2 大版本的传统，装完先跑一次示例 |
| 3D 散点/曲面/切面 | `plot3D` | `persp3D()`、`slice3D()`；投稿慎用 3D，需注明视角 |
| 连续型 Cartogram | `cartogram` + `sf` | `cartogram_cont()` 需要面要素；新写法用 sf 对象，原书 rgdal 写法已失效 |
| 切尔诺夫脸谱 | `aplpack::faces()` | 趣味展示可以，严谨比较不要用（五官权重无共识） |
| 词云 | `ggwordcloud` | 只表达词频量级 |
| 韦恩图 | `ggVennDiagram` | ≤ 4 集合 |

---

## 十、包可用性备忘（2026-10 在阿里云/清华/中科大三个镜像实查）

**已从 CRAN 归档、`install.packages()` 装不上的**（原书用到）：`rgdal`、`rgeos`、`maptools`（2023-10 归档，sf 生态替代）、`ggalt`、`ggTimeSeries`、`waffle`、`tabplot`、`ggmosaic`、`ggstream`。对应替代写法见本文件：坡度图 3.1、波形图 4.2、华夫饼 5.1、马赛克 5.2；`ComplexHeatmap` 在 Bioconductor 不在 CRAN。

**轻量常用且二进制秒装**：`ggrepel`、`patchwork`、`ggridges`、`viridis`、`scales`、`RColorBrewer`。**中等**：`igraph` + `ggraph` + `tidygraph`、`circlize`、`ggalluvial`、`treemapify`。**较重（需要编译或系统库）**：`sf`、`rgdal` 替代链、`cartogram`、`geofacet`、`plot3D`。
