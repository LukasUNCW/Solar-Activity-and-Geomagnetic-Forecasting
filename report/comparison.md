# 4. Model Comparison

## 4.1 Forecasting Accuracy (Test Set)

The table below summarizes the forecasting accuracy for each method on the held-out test set
(October 2018 – October 2024, 73 observations).

| Method | Series | RMSE | MAE | MAPE |
|---|---|---|---|---|
| Univariate ARIMA | Sunspot | 88.39 | 64.15 | 121.20% |
| Univariate ARIMA | F10.7 | 654.68 | 465.05 | 31.79% |
| Univariate ARIMA | Ap Index | 3.65 | 2.84 | 41.43% |
| Vector ARIMA (VAR) | Sunspot | 48.48 | 37.95 | 1020.11% |
| Vector ARIMA (VAR) | F10.7 | 421.58 | 298.66 | 21.72% |
| Vector ARIMA (VAR) | Ap Index | 4.17 | 3.52 | 57.65% |
| Dynamic Regression | Ap Index | 3.15 | 2.50 | 40.10% |

## 4.2 In-Sample Fit Accuracy (Train Set)

| Method | Series | RMSE |
|---|---|---|
| Univariate ARIMA | Sunspot | 22.80 |
| Univariate ARIMA | F10.7 | 137.92 |
| Univariate ARIMA | Ap Index | 4.40 |
| Dynamic Regression | Ap Index | 4.34 |

## 4.3 Discussion

### Which method produces better forecasts?

The results are mixed across the three series, and no single method dominates uniformly.

For Sunspot Number, the Vector ARIMA model produced noticeably better point forecasts
than the univariate model (RMSE of 48.48 vs 88.39, MAE of 37.95 vs 64.15), suggesting that
incorporating information from the correlated F10.7 and Ap series helped the VAR model track
the test period more closely. The MAPE for Sunspot is extremely high across both methods
(121% univariate, 1020% VAR), which reflects the fact that sunspot counts pass through near-zero
values during solar minimum, making percentage errors artificially large and not a reliable
measure of forecast quality for this series. RMSE and MAE are more appropriate here.

For F10.7 Solar Flux, the VAR model also outperformed the univariate model in terms of
RMSE (421.58 vs 654.68) and MAE (298.66 vs 465.05), again indicating that cross-series
information improved forecasting. The MAPE of 21.72% for VAR vs 31.79% for univariate
further supports this conclusion.

For Ap Index, the Dynamic Regression model produced the best forecasts, with the lowest
RMSE (3.15) and MAE (2.50) among all methods tested for this series. This is not surprising
given the physical relationship between the variables, Sunspot Number and F10.7 are direct
measures of solar output and are strong predictors of geomagnetic activity. By explicitly
incorporating these as covariates, the dynamic regression model was able to leverage this
causal structure in a way that neither the univariate model nor the VAR model could replicate
as effectively.

Overall, the **Dynamic Regression model produced the best forecasts for the Ap Index**,
and the **Vector ARIMA model produced the best forecasts for Sunspot and F10.7**.

### Which method produces better in-sample fit?

For the Ap Index, the Dynamic Regression model achieved a slightly lower train set RMSE
(4.34) compared to the univariate ARIMA (4.40), indicating a marginally better in-sample fit.
This improvement is modest, suggesting that the covariates help more with out-of-sample
forecasting than with fitting the training data — likely because the ARIMA error structure in
both models captures most of the short-term autocorrelation in Ap regardless of the covariates.

### Why do we obtain these results?

These results are consistent with the known physical relationships among the three variables.
Sunspot Number and F10.7 are both measures of solar activity and are highly correlated with
each other and with Ap. The 11-year solar cycle dominates all three series, creating strong
long-range autocorrelation that univariate ARIMA models struggle to fully capture without very
high-order terms. The VAR model benefits from cross-series information at each lag, which
helps it track cyclical turning points more accurately. The Dynamic Regression model goes
further by treating the solar activity variables as direct predictors of geomagnetic disturbance,
which reflects the true causal mechanism and produces the most accurate Ap forecasts.

The high MAPE values observed for Sunspot (across all methods) and Ap (for the VAR model)
are largely a consequence of the solar minimum periods in the test set, where values approach
zero and small absolute errors translate into very large percentage errors. These should be
interpreted cautiously — RMSE and MAE provide a more stable basis for comparison in this case.
