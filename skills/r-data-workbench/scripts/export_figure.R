#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# export_figure.R — 图表统一导出
#
# 用法：
#   source("scripts/export_figure.R")
#   export_figure(p, "fig01_trend")                    # 默认 screen：PNG
#   export_figure(p, "fig02_box", use = "journal",
#                 width = 85, height = 70)             # 单栏 85 mm
#   export_figure(p, "fig03_heat", use = "print")      # 600 dpi TIFF
#
# 设计要点：
#   1) 显式控制 width / height / units / dpi，不依赖画布大小；
#   2) PDF 优先 cairo_pdf（可嵌入中文），不可用时自动回退到 pdf()，不静默失败；
#   3) 每个候选设备都会校验产物文件是否真实生成，失败则换下一个；
#   4) 输出目录统一 output/figures/，并打印文件大小。
# ---------------------------------------------------------------------------

.fig_presets <- list(
  screen  = list(width = 180, height = 130, dpi = 300, formats = "png"),
  journal = list(width = 85,  height = 70,  dpi = 300, formats = c("png", "pdf")),
  slide   = list(width = 254, height = 143, dpi = 300, formats = "png"),
  print   = list(width = 170, height = 130, dpi = 600, formats = "tif")
)

# 英寸换算
.to_inch <- function(x, units) {
  switch(units,
         mm = x / 25.4,
         cm = x / 2.54,
         `in` = x,
         inch = x,
         px = x / 96,
         stop("不支持的 units: ", units, "（可用 mm / cm / in / px）"))
}

# 打开设备并绘制；返回 TRUE 表示产物有效
# draw 为无参函数：ggplot 对象传 function() print(p)，base 图形传绘图函数本身
.render_with <- function(draw, path, open_fun, ...) {
  if (file.exists(path)) unlink(path)
  dev_id <- grDevices::dev.cur()
  ok <- FALSE
  ok <- tryCatch({
    suppressWarnings(open_fun(path, ...))
    dev_id <- grDevices::dev.cur()
    if (identical(dev_id, grDevices::dev.cur()) && dev_id <= 1) stop("设备未打开")
    suppressWarnings(draw())
    grDevices::dev.off(dev_id)
    file.exists(path) && file.size(path) > 500
  }, error = function(e) {
    if (grDevices::dev.cur() != 1 && grDevices::dev.cur() == dev_id) {
      try(grDevices::dev.off(dev_id), silent = TRUE)
    }
    FALSE
  })
  if (!isTRUE(ok)) {
    if (file.exists(path)) unlink(path)
    return(FALSE)
  }
  TRUE
}

# 各格式的候选设备（按优先级）
.device_chain <- function(fmt, bg) {
  if (fmt == "png") {
    l <- list()
    if (requireNamespace("ragg", quietly = TRUE)) {
      l$ragg <- function(path, w, h, dpi) {
        ragg::agg_png(path, width = w, height = h, units = "in",
                      res = dpi, background = bg)
      }
    }
    l$cairo <- function(path, w, h, dpi) {
      # Cairo_type 支持 alpha 透明与抗锯齿，跨平台渲染最一致
      grDevices::png(path, width = w, height = h, units = "in",
                     res = dpi, bg = bg, type = "cairo")
    }
    l$base <- function(path, w, h, dpi) {
      grDevices::png(path, width = w, height = h, units = "in",
                     res = dpi, bg = bg)
    }
    return(l)
  }

  if (fmt == "pdf") {
    return(list(
      cairo = function(path, w, h, dpi) {
        grDevices::cairo_pdf(path, width = w, height = h, bg = bg)
      },
      base = function(path, w, h, dpi) {
        grDevices::pdf(path, width = w, height = h, bg = bg, useDingbats = FALSE)
      }
    ))
  }

  if (fmt == "svg") {
    l <- list()
    if (requireNamespace("svglite", quietly = TRUE)) {
      l$svglite <- function(path, w, h, dpi) {
        svglite::svglite(path, width = w, height = h, bg = bg)
      }
    }
    l$base <- function(path, w, h, dpi) {
      grDevices::svg(path, width = w, height = h, bg = bg)
    }
    return(l)
  }

  if (fmt %in% c("tif", "tiff")) {
    return(list(
      cairo = function(path, w, h, dpi) {
        grDevices::tiff(path, width = w, height = h, units = "in",
                        res = dpi, bg = bg, compression = "lzw", type = "cairo")
      },
      base = function(path, w, h, dpi) {
        grDevices::tiff(path, width = w, height = h, units = "in",
                        res = dpi, bg = bg, compression = "lzw")
      }
    ))
  }

  stop("不支持的格式: ", fmt, "（可用 png / pdf / svg / tif）")
}

#' 导出图形
#'
#' @param plot   要导出的图：ggplot/patchwork 对象，或直接给绘图函数
#'               （如 function() barplot(...)；用于 base R 图形，
#'               因为 base 图形是"画在设备上"的，无法像 ggplot 那样先构造后打印）
#' @param name    文件名主干（不含扩展名），建议 fig01_topic
#' @param use     预设：screen / journal / slide / print
#' @param width,height 覆盖预设尺寸，单位由 units 指定
#' @param units   "mm"（默认）/ "cm" / "in" / "px"
#' @param dpi     位图分辨率，覆盖预设
#' @param formats 覆盖预设格式，可选 "png","pdf","svg","tif"
#' @param out_dir 输出目录，默认 output/figures
#' @param bg      背景色，默认 white；需透明背景时传 "transparent"（PNG 有效）
#' @param scale   尺寸整体缩放系数
#' @return 成功生成的文件路径（字符向量，不可见）
export_figure <- function(plot,
                          name,
                          use     = c("screen", "journal", "slide", "print"),
                          width   = NULL,
                          height  = NULL,
                          units   = "mm",
                          dpi     = NULL,
                          formats = NULL,
                          out_dir = "output/figures",
                          bg      = "white",
                          scale   = 1) {

  draw <- if (is.function(plot)) {
    plot
  } else if (inherits(plot, c("ggplot", "gg", "patchwork", "grob"))) {
    function() print(plot)
  } else {
    stop("plot 需为 ggplot/patchwork 对象或绘图函数；",
         "base 图形请传 function() plot(...)", call. = FALSE)
  }

  use    <- match.arg(use)
  preset <- .fig_presets[[use]]

  w_mm <- if (is.null(width))  preset$width  else width
  h_mm <- if (is.null(height)) preset$height else height
  d    <- if (is.null(dpi))    preset$dpi    else dpi
  fmts <- if (is.null(formats)) preset$formats else formats

  w <- .to_inch(w_mm, units) * scale
  h <- .to_inch(h_mm, units) * scale

  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  made <- character(0)
  for (fmt in fmts) {
    path  <- file.path(out_dir, paste0(name, ".", fmt))
    chain <- .device_chain(fmt, bg)
    ok    <- FALSE
    for (dev_name in names(chain)) {
      ok <- .render_with(draw, path, chain[[dev_name]], w = w, h = h, dpi = d)
      if (ok) {
        if (dev_name != names(chain)[1] && length(chain) > 1) {
          message(sprintf("  [note] %s 使用回退设备 '%s'", fmt, dev_name))
        }
        break
      }
    }
    if (ok) {
      made <- c(made, path)
      cat(sprintf("  saved: %-40s %5.1f KB  (%.1f x %.1f mm @ %d dpi)\n",
                  path, file.size(path) / 1024,
                  w * 25.4, h * 25.4, d))
    } else {
      warning("导出失败: ", path, " —— 所有设备均不可用，",
              "请先运行 check_env.R 检查图形设备", call. = FALSE)
    }
  }
  invisible(made)
}

#' 批量导出：命名列表，列表名即文件名
export_figures <- function(plots, ...) {
  stopifnot(is.list(plots), length(plots) > 0, !is.null(names(plots)))
  for (nm in names(plots)) {
    cat("[", nm, "]\n", sep = "")
    export_figure(plots[[nm]], nm, ...)
  }
  invisible(TRUE)
}

#' base R 图形的便捷包装：export_base(function() barplot(...), "fig01", ...)
#' @param fun 无参绘图函数，在设备打开后执行
export_base <- function(fun, name, ...) {
  stopifnot(is.function(fun))
  export_figure(fun, name, ...)
}

#' 输出结果表（CSV，可选 xlsx）
export_table <- function(df, name, out_dir = "output/tables", xlsx = FALSE) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  p <- file.path(out_dir, paste0(name, ".csv"))
  utils::write.csv(df, p, row.names = FALSE, fileEncoding = "UTF-8")
  cat("  saved:", p, "\n")
  if (xlsx && requireNamespace("writexl", quietly = TRUE)) {
    px <- file.path(out_dir, paste0(name, ".xlsx"))
    writexl::write_xlsx(df, px)
    cat("  saved:", px, "\n")
  }
  invisible(p)
}

#' 落盘会话信息，保证可复现
save_session_info <- function(out_dir = "output") {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  p <- file.path(out_dir, "session_info.txt")
  writeLines(capture.output(utils::sessionInfo()), p)
  cat("  saved:", p, "\n")
  invisible(p)
}
