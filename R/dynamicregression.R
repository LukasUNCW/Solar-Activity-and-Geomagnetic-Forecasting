.libPaths('~/R/library')

library(tidyr)
library(dplyr)
library(forecast)
library(tseries)
library(urca)
library(ggplot2)

dir.create("output", showWarnings = FALSE)

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


start_yr <- train$year[1]
start_mo <- train$month[1]

ts_ap      <- ts(train$ap,      start = c(start_yr, start_mo), frequency = 12)
ts_sunspot <- ts(train$sunspot, start = c(start_yr, start_mo), frequency = 12)
ts_f107    <- ts(train$f107,    start = c(start_yr, start_mo), frequency = 12)

# Covariate matrix for training
xreg_train <- cbind(sunspot = train$sunspot, f107 = train$f107)

# Covariate matrix for test (used for forecasting)
xreg_test  <- cbind(sunspot = test$sunspot,  f107 = test$f107)

png("output/dynreg_series.png", width = 900, height = 600)
par(mfrow = c(3, 1), mar = c(3, 4, 2, 1))
plot(train$date, train$ap,      type = "l", col = "darkgreen",
     main = "Ap Index (Response)",    ylab = "Ap",      xlab = "")
plot(train$date, train$sunspot, type = "l", col = "steelblue",
     main = "Sunspot Number (Covariate)", ylab = "Sunspot", xlab = "")
plot(train$date, train$f107,    type = "l", col = "darkorange",
     main = "F10.7 (Covariate)",      ylab = "F10.7",   xlab = "Year")
dev.off()
cat(">> Series plot saved\n")


cat("\n--- Fitting Dynamic Regression (auto.arima with xreg) ---\n")

auto_dynreg <- auto.arima(ts_ap,
                          xreg        = xreg_train,
                          seasonal    = TRUE,
                          stepwise    = FALSE,
                          approximation = FALSE,
                          ic          = "aic")

cat("\nBest model:\n")
print(summary(auto_dynreg))
cat("\nAIC:", round(AIC(auto_dynreg), 2), "\n")
cat("\nCoefficients:\n")
print(coef(auto_dynreg))

cat("\n--- Candidate Model AIC Comparison ---\n")

orders_to_try <- list(
  c(0,0,0), c(1,0,0), c(0,0,1), c(1,0,1),
  c(2,0,0), c(0,1,0), c(1,1,0), c(0,1,1), c(1,1,1)
)

aic_results <- data.frame(model = character(), aic = numeric())

for (ord in orders_to_try) {
  tryCatch({
    m <- Arima(ts_ap, order = ord, xreg = xreg_train)
    label <- paste0("ARIMA(", paste(ord, collapse=","), ")")
    aic_results <- rbind(aic_results,
                         data.frame(model = label, aic = round(AIC(m), 2)))
  }, error = function(e) NULL)
}

aic_results <- aic_results[order(aic_results$aic), ]
print(aic_results)

# Use auto.arima model as final
final_model <- auto_dynreg

png("output/dynreg_diagnostics.png", width = 900, height = 600)
checkresiduals(final_model)
dev.off()
cat("\n>> Residual diagnostics plot saved\n")


cat("\n--- Forecasting Ap Index using test set covariates ---\n")

fc <- forecast(final_model, xreg = xreg_test, h = nrow(test))


all_dates   <- solar_data$date
train_dates <- train$date
test_dates  <- test$date

ts_ap_test <- ts(test$ap,
                 start     = c(test$year[1], test$month[1]),
                 frequency = 12)

png("output/dynreg_forecast_overlay.png", width = 1000, height = 500)
plot(fc,
     main = "Dynamic Regression — Ap Index Forecast vs Test Set",
     ylab = "Ap Index", xlab = "Year",
     flwd = 1.5)
lines(ts_ap_test, col = "red", lwd = 1.5)
legend("topleft",
       legend = c("Fitted/Forecast", "Actual (Test)"),
       col    = c("blue", "red"),
       lty    = 1, cex = 0.85)
dev.off()
cat(">> Forecast overlay plot saved\n")


cat("\n--- Accuracy: Test Set (Forecast vs Actual) ---\n")
acc_test <- accuracy(fc, ts_ap_test)
print(round(acc_test, 4))

cat("\n--- Accuracy: Train Set (Fitted vs Actual) ---\n")
acc_train <- accuracy(final_model)
print(round(acc_train, 4))


cat("\n--- Model Summary ---\n")
cat("Dynamic Regression: Ap Index ~ Sunspot + F10.7 + ARIMA errors\n")
cat("ARIMA order on residuals:", arimaorder(final_model), "\n")
cat("AIC:", round(AIC(final_model), 2), "\n")

cat("\n", rep("=", 60), "\n", sep = "")
cat("Dynamic regression analysis complete. Plots saved to output/\n")
cat(rep("=", 60), "\n", sep = "")
