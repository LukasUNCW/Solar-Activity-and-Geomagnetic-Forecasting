# ============================================================
# 03_varima.R
# Vector ARIMA (sVARMA) modeling for all three series jointly
# ============================================================

.libPaths('~/R/library')

library(tidyr)
library(dplyr)
library(MTS)
library(forecast)
library(ggplot2)

dir.create("output", showWarnings = FALSE)

# ------------------------------------------------------------
# Load cleaned data
# ------------------------------------------------------------
solar_data <- read.csv("data/solar_data_clean.csv")
solar_data$date <- as.Date(solar_data$date)

# Remove rows with any NA
solar_data <- na.omit(solar_data)

# Split train/test (last 10%)
n       <- nrow(solar_data)
n_test  <- floor(n * 0.10)
n_train <- n - n_test

train <- solar_data[1:n_train, ]
test  <- solar_data[(n_train + 1):n, ]

cat("Training set:", n_train, "obs |", as.character(train$date[1]),
    "to", as.character(train$date[n_train]), "\n")
cat("Test set:    ", n_test,  "obs |", as.character(test$date[1]),
    "to", as.character(test$date[n_test]), "\n\n")

# ------------------------------------------------------------
# Build multivariate matrix (train and test)
# ------------------------------------------------------------
train_mat <- as.matrix(train[, c("sunspot", "f107", "ap")])
test_mat  <- as.matrix(test[,  c("sunspot", "f107", "ap")])

# ------------------------------------------------------------
# 1. Plot all three training series together
# ------------------------------------------------------------
png("output/varima_train_series.png", width = 900, height = 600)
par(mfrow = c(3, 1), mar = c(3, 4, 2, 1))
plot(train$date, train$sunspot, type = "l", col = "steelblue",
     main = "Sunspot Number (Train)", ylab = "Sunspot", xlab = "")
plot(train$date, train$f107, type = "l", col = "darkorange",
     main = "Solar Flux F10.7 (Train)", ylab = "F10.7", xlab = "")
plot(train$date, train$ap, type = "l", col = "darkgreen",
     main = "Geomagnetic Ap Index (Train)", ylab = "Ap", xlab = "Year")
dev.off()
cat(">> Training series plot saved\n")

# ------------------------------------------------------------
# 2. Cross-correlation matrix (CCM)
# ------------------------------------------------------------
cat("\n--- Cross-Correlation Matrix ---\n")
png("output/varima_ccm.png", width = 900, height = 700)
ccm(train_mat, lag = 24)
dev.off()
cat(">> CCM plot saved\n")

# ------------------------------------------------------------
# 3. Fit sVARMA model
# ------------------------------------------------------------
cat("\n--- Fitting sVARMA model ---\n")

# Try VAR orders 1 through 4 and pick best AIC
best_aic   <- Inf
best_p     <- 1
best_model <- NULL

for (p in 1:4) {
  tryCatch({
    m <- VAR(train_mat, p = p)
    a <- m$aic
    cat("VAR(", p, ") AIC:", round(a, 2), "\n")
    if (a < best_aic) {
      best_aic   <- a
      best_p     <- p
      best_model <- m
    }
  }, error = function(e) cat("VAR(", p, ") failed:", e$message, "\n"))
}

cat("\nBest model: VAR(", best_p, ") with AIC:", round(best_aic, 2), "\n")

# ------------------------------------------------------------
# 4. Model diagnostics
# ------------------------------------------------------------
cat("\n--- Residual Diagnostics ---\n")
png("output/varima_diagnostics.png", width = 900, height = 700)
MTSdiag(best_model)
dev.off()
cat(">> Diagnostics plot saved\n")

# ------------------------------------------------------------
# 5. Forecasts for test set
# ------------------------------------------------------------
cat("\n--- Forecasting test set ---\n")
h  <- nrow(test_mat)
fc <- VARpred(best_model, h = h)

fc_sunspot <- fc$pred[, 1]
fc_f107    <- fc$pred[, 2]
fc_ap      <- fc$pred[, 3]

# ------------------------------------------------------------
# 6. Overlay plot: train + test + forecast
# ------------------------------------------------------------
all_dates   <- solar_data$date
train_dates <- train$date
test_dates  <- test$date

png("output/varima_forecast_overlay.png", width = 1000, height = 700)
par(mfrow = c(3, 1), mar = c(3, 4, 2, 1))

# Sunspot
plot(train_dates, train$sunspot, type = "l", col = "steelblue",
     xlim = range(all_dates),
     ylim = range(c(train$sunspot, test$sunspot, fc_sunspot), na.rm = TRUE),
     main = "Sunspot - Train / Test / Forecast", ylab = "Sunspot", xlab = "")
lines(test_dates, test$sunspot, col = "black", lwd = 1.5)
lines(test_dates, fc_sunspot,   col = "red",   lwd = 1.5, lty = 2)
legend("topleft", legend = c("Train", "Test", "Forecast"),
       col = c("steelblue", "black", "red"), lty = c(1, 1, 2), cex = 0.8)

# F10.7
plot(train_dates, train$f107, type = "l", col = "darkorange",
     xlim = range(all_dates),
     ylim = range(c(train$f107, test$f107, fc_f107), na.rm = TRUE),
     main = "F10.7 - Train / Test / Forecast", ylab = "F10.7", xlab = "")
lines(test_dates, test$f107, col = "black", lwd = 1.5)
lines(test_dates, fc_f107,   col = "red",   lwd = 1.5, lty = 2)
legend("topleft", legend = c("Train", "Test", "Forecast"),
       col = c("darkorange", "black", "red"), lty = c(1, 1, 2), cex = 0.8)

# Ap Index
plot(train_dates, train$ap, type = "l", col = "darkgreen",
     xlim = range(all_dates),
     ylim = range(c(train$ap, test$ap, fc_ap), na.rm = TRUE),
     main = "Ap Index - Train / Test / Forecast", ylab = "Ap", xlab = "Year")
lines(test_dates, test$ap, col = "black", lwd = 1.5)
lines(test_dates, fc_ap,   col = "red",   lwd = 1.5, lty = 2)
legend("topleft", legend = c("Train", "Test", "Forecast"),
       col = c("darkgreen", "black", "red"), lty = c(1, 1, 2), cex = 0.8)

dev.off()
cat(">> Forecast overlay plot saved\n")

# ------------------------------------------------------------
# 7. Accuracy measures
# ------------------------------------------------------------
accuracy_measures <- function(actual, forecast, label) {
  e    <- actual - forecast
  mae  <- mean(abs(e), na.rm = TRUE)
  rmse <- sqrt(mean(e^2, na.rm = TRUE))
  mape <- mean(abs(e / actual) * 100, na.rm = TRUE)
  cat("\nAccuracy -", label, "\n")
  cat("  RMSE:", round(rmse, 4), "\n")
  cat("  MAE: ", round(mae,  4), "\n")
  cat("  MAPE:", round(mape, 4), "%\n")
}

cat("\n--- Test Set Accuracy ---\n")
accuracy_measures(test$sunspot, fc_sunspot, "Sunspot")
accuracy_measures(test$f107,    fc_f107,    "F10.7")
accuracy_measures(test$ap,      fc_ap,      "Ap Index")

# Train set fitted values
cat("\n--- Train Set Accuracy (Fitted vs Actual) ---\n")
fitted_vals <- fitted(best_model)
accuracy_measures(train$sunspot[(best_p+1):n_train], fitted_vals[, 1], "Sunspot")
accuracy_measures(train$f107[(best_p+1):n_train],    fitted_vals[, 2], "F10.7")
accuracy_measures(train$ap[(best_p+1):n_train],      fitted_vals[, 3], "Ap Index")

cat("\n", rep("=", 60), "\n", sep = "")
cat("Vector ARIMA analysis complete. Plots saved to output/\n")
cat(rep("=", 60), "\n", sep = "")