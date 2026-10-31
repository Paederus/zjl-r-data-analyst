#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# theme_academic.R — 学术图表主题与配色
# 用法：
#   source("scripts/theme_academic.R")
#   theme_set(theme_academic())          # 全局生效
#   p + scale_fill_wb("qual")            # 定性色板
#   register_cn_font()                   # 注册中文字体（可选）
# 依赖：ggplot2 ≥ 3.4（线宽参数为 linewidth）
# ---------------------------------------------------------------------------

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  message("提示：未检测到 ggplot2（安装：install.packages('ggplot2')）。")
  message("      主题与色板函数需在安装 ggplot2 后调用；本文件仍可安全 source()。")
}

# --- 色板 ------------------------------------------------------------------
# Okabe-Ito：色盲友好八色
pal_okabe_ito <- c("#000000", "#E69F00", "#56B4E9", "#009E73",
                   "#F0E442", "#0072B2", "#D55E00", "#CC79A7")

# 期刊常用定性色（NPG / Lancet 风格，取自 ggsci 配色）
pal_npg    <- c("#E64B35", "#4DBBD5", "#00A087", "#3C5488",
                "#F39B7F", "#8491B4", "#91D1C2", "#DC0000")
pal_lancet <- c("#00468B", "#ED0000", "#42B540", "#0099B4",
                "#925E9F", "#FDAF91", "#AD002A", "#ADB6B6")

# 双向渐变（低于均值 → 白 → 高于均值）
grad_diverging <- c(low = "#2166AC", mid = "#FFFFFF", high = "#B2182B")

#' 定性色板（离散变量）
#' @param palette "okabe" / "npg" / "lancet" / "brewer"
scale_fill_wb <- function(palette = "okabe", ..., na.value = "grey85") {
  pal <- switch(palette,
                okabe  = pal_okabe_ito,
                npg    = pal_npg,
                lancet = pal_lancet,
                brewer = NULL,
                stop("未知色板: ", palette))
  if (palette == "brewer") {
    return(ggplot2::scale_fill_brewer(palette = "Set2", na.value = na.value, ...))
  }
  # 扩展到 24 色：分组数超过 8 时仍能出图，不会报 "Insufficient values in manual scale"
  ggplot2::scale_fill_manual(values = grDevices::colorRampPalette(pal)(24),
                             na.value = na.value, ...)
}

#' 定性色板（点/线颜色）
scale_color_wb <- function(palette = "okabe", ..., na.value = "grey85") {
  pal <- switch(palette,
                okabe  = pal_okabe_ito,
                npg    = pal_npg,
                lancet = pal_lancet,
                brewer = NULL,
                stop("未知色板: ", palette))
  if (palette == "brewer") {
    return(ggplot2::scale_colour_brewer(palette = "Set2", na.value = na.value, ...))
  }
  ggplot2::scale_colour_manual(values = grDevices::colorRampPalette(pal)(24),
                               na.value = na.value, ...)
}

#' 连续色板（viridis 或单色渐变）
#' @param type "viridis" / "seq" / "div"
scale_fill_wb_c <- function(type = "viridis", ..., midpoint = 0) {
  if (type == "viridis") {
    if (requireNamespace("viridisLite", quietly = TRUE)) {
      return(ggplot2::scale_fill_viridis_c(..., option = "D"))
    }
    return(ggplot2::scale_fill_gradient(low = "#F7FBFF", high = "#08306B", ...))
  }
  if (type == "seq") {
    return(ggplot2::scale_fill_gradient(low = "#F7FBFF", high = "#08306B", ...))
  }
  ggplot2::scale_fill_gradient2(low = grad_diverging[["low"]],
                                mid = grad_diverging[["mid"]],
                                high = grad_diverging[["high"]],
                                midpoint = midpoint, ...)
}

# --- 主题 ------------------------------------------------------------------
#' 学术图表主题
#' @param base_size 基础字号，论文建议 8–10，PPT 建议 14–18
#' @param base_family 字体族，留空则用设备默认
#' @param grid 是否保留浅灰主网格（TRUE 便于读数，FALSE 更干净）
#' @param border 是否画完整面板边框（FALSE 为 L 形轴线）
theme_academic <- function(base_size = 9, base_family = "", grid = FALSE, border = FALSE) {
  th <- ggplot2::theme_bw(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      panel.background  = ggplot2::element_rect(fill = "white", colour = NA),
      plot.background   = ggplot2::element_rect(fill = "white", colour = NA),
      panel.grid.minor  = ggplot2::element_blank(),
      axis.text         = ggplot2::element_text(colour = "black", size = base_size * 0.92),
      axis.title        = ggplot2::element_text(colour = "black", size = base_size),
      axis.ticks        = ggplot2::element_line(colour = "black", linewidth = 0.35),
      axis.ticks.length = ggplot2::unit(1.2, "mm"),
      legend.title      = ggplot2::element_text(size = base_size * 0.95),
      legend.text       = ggplot2::element_text(size = base_size * 0.9),
      legend.key        = ggplot2::element_blank(),
      legend.background = ggplot2::element_blank(),
      strip.background  = ggplot2::element_rect(fill = "grey95", colour = NA),
      strip.text        = ggplot2::element_text(colour = "black", size = base_size * 0.95,
                                                face = "bold"),
      plot.title        = ggplot2::element_text(size = base_size * 1.15, face = "bold",
                                                hjust = 0, margin = ggplot2::margin(b = 3)),
      plot.subtitle     = ggplot2::element_text(size = base_size * 0.95, hjust = 0),
      plot.tag          = ggplot2::element_text(size = base_size * 1.2, face = "bold"),
      plot.margin       = ggplot2::margin(4, 6, 4, 4)
    )

  if (isTRUE(grid)) {
    th <- th + ggplot2::theme(
      panel.grid.major = ggplot2::element_line(colour = "grey90", linewidth = 0.3)
    )
  } else {
    th <- th + ggplot2::theme(panel.grid.major = ggplot2::element_blank())
  }

  if (isTRUE(border)) {
    th <- th + ggplot2::theme(
      panel.border = ggplot2::element_rect(colour = "black", fill = NA, linewidth = 0.5),
      axis.line    = ggplot2::element_blank()
    )
  } else {
    th <- th + ggplot2::theme(
      panel.border = ggplot2::element_blank(),
      axis.line    = ggplot2::element_line(colour = "black", linewidth = 0.4)
    )
  }
  th
}

#' 幻灯片主题（大字号、浅网格）
theme_slide <- function(base_size = 16, base_family = "") {
  theme_academic(base_size = base_size, base_family = base_family, grid = TRUE)
}

# --- 中文字体 --------------------------------------------------------------
#' 注册中文字体（showtext 方案）
#' @param family 自定义族名
#' @param path   字体文件路径；留空则自动在常见路径中查找
register_cn_font <- function(family = "cn", path = NULL) {
  if (!requireNamespace("showtext", quietly = TRUE)) {
    message("需要 showtext：install.packages('showtext')；已跳过字体注册")
    return(invisible(FALSE))
  }
  if (is.null(path)) {
    cands <- c(
      "/System/Library/Fonts/Supplemental/Songti.ttc",          # macOS
      "/System/Library/Fonts/PingFang.ttc",                     # macOS
      "/System/Library/Fonts/Hiragino Sans GB.ttc",             # macOS
      "C:/Windows/Fonts/msyh.ttc",                              # Windows 微软雅黑
      "C:/Windows/Fonts/simhei.ttf",                            # Windows 黑体
      "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", # Linux
      "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"          # Linux
    )
    hit <- cands[file.exists(cands)]
    if (!length(hit)) {
      message("未找到常见中文字体文件，请通过 path 参数显式指定")
      return(invisible(FALSE))
    }
    path <- hit[1]
  }
  showtext::font_add(family = family, regular = path)
  showtext::showtext_auto()
  options(workbuddy.fig_family = family)
  message("已注册中文字体族 '", family, "' -> ", path)
  invisible(TRUE)
}

# --- 便捷包装 --------------------------------------------------------------
#' 带统计标注的分组比较图（需 ggpubr）
plot_group_compare <- function(df, x, y, fill = x, method = "t.test") {
  if (!requireNamespace("ggpubr", quietly = TRUE)) {
    stop("plot_group_compare() 需要 ggpubr：install.packages('ggpubr')；",
         "可改用 ggplot2 + geom_boxplot() + ggsignif 自行标注", call. = FALSE)
  }
  ggplot2::ggplot(df, ggplot2::aes(x = .data[[x]], y = .data[[y]],
                                   fill = .data[[fill]])) +
    ggplot2::geom_boxplot(width = 0.6, outlier.shape = NA, alpha = 0.85) +
    ggplot2::geom_jitter(width = 0.12, size = 1.1, alpha = 0.55,
                         colour = "grey25") +
    scale_fill_wb("okabe") +
    ggpubr::stat_compare_means(method = method, label = "p.signif") +
    ggplot2::labs(x = NULL, y = y, fill = x) +
    theme_academic()
}

message("theme_academic.R loaded. 可用: theme_academic(), theme_slide(), ",
        "scale_fill_wb(), scale_color_wb(), scale_fill_wb_c(), register_cn_font()")
