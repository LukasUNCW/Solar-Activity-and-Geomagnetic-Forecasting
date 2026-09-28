# Regenerates the README figures (light + dark) in assets/.
# Run the three model scripts first; they write output/forecast_*.csv.
#
#   Rscript R/univariate.R && Rscript R/varima.R && Rscript R/dynamicregression.R
#   Rscript R/figures.R

library(dplyr)
library(tidyr)
library(ggplot2)

dir.create("assets", showWarnings = FALSE)

solar <- read.csv("data/solar_data_clean.csv") %>%
  mutate(date = as.Date(date), f107 = f107 / 10)   # PSL file stores F10.7 in 0.1 sfu

fc <- bind_rows(
  lapply(c("Sunspot", "F107", "Ap_Index"),
         function(s) read.csv(paste0("output/forecast_arima_", s, ".csv"))),
  read.csv("output/forecast_var.csv"),
  read.csv("output/forecast_dynreg.csv")
) %>%
  mutate(date = as.Date(date),
         across(c(actual, mean, any_of(c("lo95", "hi95"))),
                ~ ifelse(series == "F107", .x / 10, .x)))

test_start <- min(fc$date)
test_end   <- max(fc$date)

SERIES_LABELS <- c(Sunspot = "Sunspot number", F107 = "F10.7 solar flux (sfu)",
                   Ap_Index = "Geomagnetic Ap index")
METHODS <- c("ARIMA", "VAR", "Dynamic regression")

# fixed categorical order, light / dark steps (colorblind-validated palette)
PALETTE <- list(
  light = c(ARIMA = "#2a78d6", VAR = "#eb6834", `Dynamic regression` = "#1baf7a"),
  dark  = c(ARIMA = "#3987e5", VAR = "#d95926", `Dynamic regression` = "#199e70")
)
THEMES <- list(
  light = list(surface = "#ffffff", ink = "#0b0b0b", ink2 = "#52514e", muted = "#898781",
               grid = "#e1e0d9", band = "#f0efec", line = "#2a78d6"),
  dark  = list(surface = "#0d1117", ink = "#ffffff", ink2 = "#c3c2b7", muted = "#898781",
               grid = "#2c2c2a", band = "#1f2328", line = "#3987e5")
)

theme_readme <- function(t) {
  theme_minimal(base_size = 11, base_family = "Arial") +
    theme(
      plot.background   = element_rect(fill = t$surface, colour = NA),
      panel.background  = element_rect(fill = t$surface, colour = NA),
      panel.grid.major.y = element_line(colour = t$grid, linewidth = 0.3),
      panel.grid.major.x = element_blank(),
      panel.grid.minor  = element_blank(),
      axis.text         = element_text(colour = t$muted, size = 9),
      axis.title        = element_blank(),
      strip.text        = element_text(colour = t$ink, hjust = 0, size = 10.5, face = "bold"),
      plot.title        = element_text(colour = t$ink, face = "bold", size = 14),
      plot.subtitle     = element_text(colour = t$ink2, size = 10, margin = margin(b = 10)),
      plot.title.position = "plot",
      legend.position   = "top",
      legend.justification = "left",
      legend.title      = element_blank(),
      legend.text       = element_text(colour = t$ink2, size = 9.5),
      legend.key.width  = unit(18, "pt"),
      legend.margin     = margin(0, 0, 0, -4),
      plot.margin       = margin(14, 16, 10, 12)
    )
}

save_both <- function(make_plot, name, width, height) {
  for (mode in c("light", "dark")) {
    p <- make_plot(THEMES[[mode]], PALETTE[[mode]])
    suffix <- if (mode == "light") "" else "_dark"
    ggsave(file.path("assets", paste0(name, suffix, ".png")), p,
           width = width, height = height, dpi = 160, bg = THEMES[[mode]]$surface)
  }
}

# 1. Sixty years of the three series ------------------------------------------
save_both(function(t, pal) {
  long <- solar %>%
    select(date, Sunspot = sunspot, F107 = f107, Ap_Index = ap) %>%
    pivot_longer(-date, names_to = "series") %>%
    mutate(series = factor(SERIES_LABELS[series], levels = SERIES_LABELS))
  ggplot(long, aes(date, value)) +
    annotate("rect", xmin = test_start, xmax = test_end, ymin = -Inf, ymax = Inf,
             fill = t$band) +
    geom_line(colour = t$line, linewidth = 0.45, na.rm = TRUE) +
    facet_wrap(~series, ncol = 1, scales = "free_y") +
    scale_x_date(breaks = as.Date(paste0(seq(1965, 2025, 10), "-01-01")), date_labels = "%Y",
                 expand = c(0.01, 0)) +
    labs(title = "Sixty years of the solar cycle, 1964–2024",
         subtitle = "Monthly data. Sunspots and F10.7 rise and fall together every ~11 years; geomagnetic Ap follows, noisily.\nShaded: held-out test period (Oct 2018 – Oct 2024)") +
    theme_readme(t)
}, "solar_cycle", 10, 6.2)

# 2. Solar activity forecasts: ARIMA vs VAR ------------------------------------
save_both(function(t, pal) {
  d <- fc %>% filter(series %in% c("Sunspot", "F107")) %>%
    mutate(series = factor(SERIES_LABELS[series], levels = SERIES_LABELS))
  hist <- solar %>% filter(date >= as.Date("2008-01-01"), date < test_start) %>%
    select(date, Sunspot = sunspot, F107 = f107) %>%
    pivot_longer(-date, names_to = "series", values_to = "actual") %>%
    mutate(series = factor(SERIES_LABELS[series], levels = SERIES_LABELS))
  actual <- bind_rows(hist, d %>% distinct(date, series, actual))
  ggplot() +
    annotate("rect", xmin = test_start, xmax = test_end, ymin = -Inf, ymax = Inf, fill = t$band) +
    geom_line(data = actual, aes(date, actual, linetype = "Actual"), colour = t$ink,
              linewidth = 0.5, na.rm = TRUE) +
    geom_line(data = d, aes(date, mean, colour = method), linewidth = 0.9) +
    facet_wrap(~series, ncol = 1, scales = "free_y") +
    scale_colour_manual(values = pal, breaks = c("ARIMA", "VAR")) +
    scale_linetype_manual(values = c(Actual = "solid")) +
    guides(linetype = guide_legend(order = 1, override.aes = list(colour = t$ink)),
           colour = guide_legend(order = 2)) +
    scale_x_date(date_breaks = "2 years", date_labels = "%Y", expand = c(0.01, 0)) +
    labs(title = "Solar Cycle 25 arrived faster than either model expected",
         subtitle = "73-month forecasts from Sep 2018. The VAR model borrows strength across series and tracks the rise better,\nbut both undershoot the peak") +
    theme_readme(t)
}, "solar_forecasts", 10, 5.6)

# 3. Ap forecasts: all three methods -------------------------------------------
save_both(function(t, pal) {
  d <- fc %>% filter(series == "Ap_Index")
  dr <- d %>% filter(method == "Dynamic regression")
  hist <- solar %>% filter(date >= as.Date("2014-01-01"), date < test_start)
  ggplot() +
    annotate("rect", xmin = test_start, xmax = test_end, ymin = -Inf, ymax = Inf, fill = t$band) +
    geom_ribbon(data = dr, aes(date, ymin = lo95, ymax = hi95),
                fill = pal[["Dynamic regression"]], alpha = 0.12) +
    geom_line(data = bind_rows(hist %>% select(date, actual = ap),
                               d %>% distinct(date, actual)),
              aes(date, actual, linetype = "Actual"), colour = t$ink, linewidth = 0.5) +
    geom_line(data = d, aes(date, mean, colour = method), linewidth = 0.9) +
    scale_colour_manual(values = pal, breaks = METHODS) +
    scale_linetype_manual(values = c(Actual = "solid")) +
    guides(linetype = guide_legend(order = 1, override.aes = list(colour = t$ink)),
           colour = guide_legend(order = 2)) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = c(0.01, 0)) +
    labs(title = "Forecasting geomagnetic activity (Ap index)",
         subtitle = "Dynamic regression (shaded: 95% interval) is conditioned on the observed sunspot and F10.7 values,\nso it tracks the level best. Month-to-month storms stay unpredictable for every method") +
    theme_readme(t)
}, "ap_forecasts", 10, 4.6)

# 4. Test RMSE relative to univariate ARIMA ------------------------------------
save_both(function(t, pal) {
  rmse <- fc %>% group_by(series, method) %>%
    summarise(rmse = sqrt(mean((actual - mean)^2, na.rm = TRUE)), .groups = "drop") %>%
    group_by(series) %>% mutate(rel = rmse / rmse[method == "ARIMA"]) %>% ungroup() %>%
    mutate(series = factor(SERIES_LABELS[series], levels = rev(SERIES_LABELS)),
           method = factor(method, levels = rev(METHODS)),
           label = sprintf("%.0f%%", 100 * rel)) %>%
    filter(method != "ARIMA")
  dodge <- position_dodge2(width = 0.8, preserve = "single", reverse = FALSE)
  ggplot(rmse, aes(rel, series, fill = method)) +
    geom_vline(xintercept = 1, colour = t$ink, linewidth = 0.4) +
    geom_col(position = dodge, width = 0.6) +
    geom_text(aes(label = label), position = position_dodge2(width = 0.6, preserve = "single", reverse = FALSE),
              hjust = -0.2, size = 3.2, colour = t$ink2) +
    scale_fill_manual(values = pal, breaks = METHODS[-1]) +
    scale_x_continuous(labels = scales::percent, limits = c(0, 1.3), expand = c(0, 0),
                       breaks = seq(0, 1.25, 0.25)) +
    labs(title = "Test-set RMSE relative to univariate ARIMA",
         subtitle = "Vertical line = univariate ARIMA. Shorter bars = more accurate on the same 73-month hold-out (Oct 2018 – Oct 2024)") +
    theme_readme(t) +
    theme(panel.grid.major.y = element_blank(),
          panel.grid.major.x = element_line(colour = t$grid, linewidth = 0.3),
          axis.text.y = element_text(colour = t$ink, size = 10))
}, "rmse_comparison", 10, 3.8)

cat("Figures written to assets/\n")
