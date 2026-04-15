# Solar Activity & Geomagnetic Forecasting — Time Series Analysis

This project analyzes and forecasts three interrelated space weather time series using monthly data sourced from NOAA. We fit and compare three modeling approaches to evaluate which best captures the dynamics of solar activity and its effect on Earth's geomagnetic field.

---

## Datasets

| Dataset | Description | Source |
|---|---|---|
| **Sunspot Number** | Monthly count of sunspots on the solar surface | NOAA / WDC-SILSO |
| **Solar Flux (F10.7 Index)** | Daily solar radio flux at 10.7 cm wavelength | NOAA Space Weather |
| **Geomagnetic Ap Index** | Daily/monthly measure of Earth's geomagnetic activity | NOAA / WDC Geomagnetism |

All three datasets share the same monthly frequency and overlapping time period, and are physically related — solar output (sunspots, F10.7) drives geomagnetic disturbances (Ap Index).

---

## Methodology

The last 10% of observations from each series are held out as a **test set**; the remaining data form the **training set**.

### 1. Univariate Time Series Models (ARIMA/SARIMA)
Each series is modeled independently using ARIMA or SARIMA. Steps include:
- Time series plot, ACF, and PACF analysis
- Stationarity testing (ADF / KPSS)
- Candidate model comparison via AIC (including `auto.arima`)
- Model diagnostics and residual analysis
- Forecasts with accuracy measures on both train and test sets

### 2. Vector ARIMA (sVARMA)
All three series are modeled jointly using a vector ARIMA model (`sVARMA` in R), capturing cross-series dynamics. Includes overlaid plots of train, test, and forecasted values, along with train/test accuracy measures.

### 3. Dynamic Regression
**Ap Index** is used as the response variable, with **Sunspot Number** and **F10.7** as covariates. A dynamic regression model is fit on the training set and used to forecast Ap Index values over the test period.

### 4. Model Comparison
All three approaches are compared on forecasting accuracy (test set) and in-sample fit (train set), with discussion of why results differ across methods.

---

## Repository Structure

```
solar-cycle-forecasting/
├── data/               # Raw and cleaned datasets
├── R/                  # R scripts for each modeling step
│   ├── 01_univariate.R
│   ├── 02_varima.R
│   └── 03_dynamic_regression.R
├── output/             # Plots and results
└── README.md
```

---

## Requirements

- R (≥ 4.0)
- Packages: `forecast`, `tseries`, `MTS`, `ggplot2`, `fable`, `feasts`

Install all packages with:
```r
install.packages(c("forecast", "tseries", "MTS", "ggplot2", "fable", "feasts"))
```

---

## Data Sources

- [NOAA Space Weather](https://www.ngdc.noaa.gov/stp/space-weather/solar-data/)
- [WDC-SILSO Sunspot Data](https://www.sidc.be/silso/datafiles)
- [WDC for Geomagnetism — Ap Index](https://wdc.kugi.kyoto-u.ac.jp/kp/index.html)
