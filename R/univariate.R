.libPaths('~/R/library')

library(tidyr)
library(dplyr)
library(forecast)
library(tseries)
library(urca)
library(ggplot2)

# Create output directory for plots
dir.create("output", showWarnings = FALSE)

solar_data <- read.csv("data/solar_data_clean.csv")
solar_data$date <- as.Date(solar_data$date)

# Split train/test (last 10% = test)
n       <- nrow(solar_data)
n_test  <- floor(n * 0.10)
n_train <- n - n_test

train <- solar_data[1:n_train, ]
test  <- solar_data[(n_train + 1):n, ]

cat("Training set:", n_train, "obs |", as.character(train$date[1]),
    "to", as.character(train$date[n_train]), "\n")
cat("Test set:    ", n_test,  "obs |", as.character(test$date[1]),
    "to", as.character(test$date[n_test]), "\n\n")

# Build training ts objects
start_yr <- train$year[1]
start_mo <- train$month[1]

ts_sunspot <- ts(train$sunspot, start = c(start_yr, start_mo), frequency = 12)
ts_f107    <- ts(train$f107,    start = c(start_yr, start_mo), frequency = 12)
ts_ap      <- ts(train$ap,      start = c(start_yr, start_mo), frequency = 12)

# Build test ts objects
test_start_yr <- test$year[1]
test_start_mo <- test$month[1]

ts_sunspot_test <- ts(test$sunspot, start = c(test_start_yr, test_start_mo), frequency = 12)
ts_f107_test    <- ts(test$f107,    start = c(test_start_yr, test_start_mo), frequency = 12)
ts_ap_test      <- ts(test$ap,      start = c(test_start_yr, test_start_mo), frequency = 12)


univariate_analysis <- function(ts_train, ts_test, series_name) {

  cat("\n", rep("=", 60), "\n", sep = "")
  cat("SERIES:", series_name, "\n")
  cat(rep("=", 60), "\n", sep = "")


  png(paste0("output/", series_name, "_tsplot.png"), width = 900, height = 400)
  plot(ts_train, main = paste(series_name, "- Training Set"),
       ylab = series_name, xlab = "Year", col = "steelblue", lwd = 1.2)
  dev.off()
  cat(">> Time series plot saved\n")

 
  png(paste0("output/", series_name, "_acf_pacf.png"), width = 900, height = 500)
  par(mfrow = c(1, 2))
  acf(ts_train,  main = paste("ACF -",  series_name), lag.max = 48, na.action = na.pass)
  pacf(ts_train, main = paste("PACF -", series_name), lag.max = 48, na.action = na.pass)
  dev.off()
  cat(">> ACF/PACF plot saved\n")

  
  cat("\n--- Stationarity Tests ---\n")

  # ADF test (null: non-stationary)
  adf_result <- adf.test(na.omit(ts_train))
  cat("ADF Test p-value:", round(adf_result$p.value, 4),
      "->", ifelse(adf_result$p.value < 0.05, "STATIONARY", "NON-STATIONARY"), "\n")

  # KPSS test (null: stationary)
  kpss_result <- kpss.test(na.omit(ts_train))
  cat("KPSS Test p-value:", round(kpss_result$p.value, 4),
      "->", ifelse(kpss_result$p.value > 0.05, "STATIONARY", "NON-STATIONARY"), "\n")

 
  cat("\n--- auto.arima ---\n")
  auto_model <- auto.arima(ts_train, seasonal = TRUE, stepwise = FALSE,
                           approximation = FALSE, ic = "aic")
  cat("Best model from auto.arima:\n")
  print(summary(auto_model))

  
  cat("\n--- Candidate Model AIC Comparison ---\n")

  candidates <- list(
    auto   = auto_model,
    arima010 = tryCatch(Arima(ts_train, order = c(0,1,0)), error = function(e) NULL),
    arima110 = tryCatch(Arima(ts_train, order = c(1,1,0)), error = function(e) NULL),
    arima011 = tryCatch(Arima(ts_train, order = c(0,1,1)), error = function(e) NULL),
    arima111 = tryCatch(Arima(ts_train, order = c(1,1,1)), error = function(e) NULL),
    arima211 = tryCatch(Arima(ts_train, order = c(2,1,1)), error = function(e) NULL)
  )

  aic_table <- sapply(candidates, function(m) if (!is.null(m)) AIC(m) else NA)
  print(round(sort(aic_table), 2))

  # Use auto.arima model as final
  final_model <- auto_model

  # ----------------------------------------------------------
  # 6. Model diagnostics
  # ----------------------------------------------------------
  png(paste0("output/", series_name, "_diagnostics.png"), width = 900, height = 600)
  checkresiduals(final_model)
  dev.off()
  cat("\n>> Residual diagnostics plot saved\n")

  
  cat("\n--- Final Model ---\n")
  cat("Model:", as.character(final_model), "\n")
  cat("AIC:", round(AIC(final_model), 2), "\n")
  cat("Coefficients:\n")
  print(coef(final_model))

  
  h <- length(ts_test)
  fc <- forecast(final_model, h = h)

  # Plot forecasts vs test set
  png(paste0("output/", series_name, "_forecast.png"), width = 900, height = 500)
  plot(fc, main = paste(series_name, "- Forecast vs Test Set"),
       ylab = series_name, xlab = "Year")
  lines(ts_test, col = "red", lwd = 1.5)
  legend("topleft", legend = c("Forecast", "Actual (Test)"),
         col = c("blue", "red"), lty = 1)
  dev.off()
  cat(">> Forecast plot saved\n")

  
  cat("\n--- Accuracy: Test Set (Forecast vs Actual) ---\n")
  acc_test <- accuracy(fc, ts_test)
  print(round(acc_test, 4))

  cat("\n--- Accuracy: Train Set (Fitted vs Actual) ---\n")
  acc_train <- accuracy(final_model)
  print(round(acc_train, 4))

  return(final_model)
}


model_sunspot <- univariate_analysis(ts_sunspot, ts_sunspot_test, "Sunspot")
model_f107    <- univariate_analysis(ts_f107,    ts_f107_test,    "F107")
model_ap      <- univariate_analysis(ts_ap,      ts_ap_test,      "Ap_Index")

cat("\n", rep("=", 60), "\n", sep = "")
cat("All univariate models complete. Plots saved to output/\n")
cat(rep("=", 60), "\n", sep = "")
