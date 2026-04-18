# Solar Activity & Geomagnetic Forecasting - STT 592

This project analyzes and forecasts three interrelated space weather time series using monthly data sourced from NOAA. We fit and compare three modeling approaches to evaluate which best captures the dynamics of solar activity and its effect on Earth's geomagnetic field.

## Background: The Solar Cycle
The sun is not constant, it goes through a repeating cycle of activity roughly every 11 years, swinging between periods of relative calm (solar minimum) and intense activity (solar maximum). During solar maximum, the Sun's magnetic fields becomes highly tangled and unstable, producing more sunspots, solar flares, and bursts of energy. During solar minimum, the surface is quieter and sunspot counts drop close to zero. 

This cycle has measurable effects all the way out to Earth: 
- Sunspots are dark, cooler patches on the Sun's surface caused by concentrated magnetic fields. Scientists have been counting them since the 1700s, making it one of the longest continuous records in all of science. More sunspots = more solar activity.
- Solar Flux (F10.7 Index) measures the amount of radio energy the Sun emits at a wavelength of 10.7 cm. It's recorded daily at an obvservatory in Penticton, British Columbia, and tracks solar activity extremely closely, it is ofted used as a direct proxy for sunspot number. Unlike physically counting sunspots, it can be measured automatically in any weather.
- Geomagnetic Ap Index measures how disturbed Earth's magnetic field is on a given day, caused by charged particles streaming out from the Sun (the "solar wind") interacting with Earth's magnetosphere. When the Sun is active, these disturbances are stronger. Severe geomagnetic storms can disrupt GPS, power grids, satellites, and radio communications.

These three variables are deeply connected: sunspot activity drives solar flux, solar flux drives the solar wind, and the solar wind drives geomagnetic disturbances. This chain of cause and effect makes them an ideal set of time series to model together, and to test whether knowing about upstream solar activity helps predict downstream geomagnetic behavior.

## Datasets

| Dataset | Description | Source |
|---|---|---|
| Sunspot Number | Monthly mean total sunspot number | [WDC-SILSO, Royal Observatory of Belgium](https://www.sidc.be/silso/datafiles) |
| Solar Flux (F10.7 Index) | Monthly 10.7cm solar radio flux | [NOAA Physical Sciences Laboratory](https://psl.noaa.gov/data/correlation/solar.csv) |
| Geomagnetic Ap Index | Monthly averaged geomagnetic Ap index | [GFZ Potsdam Kp Index](https://kp.gfz.de/en/data) |

All three datasets share the same monthly frequency and overlapping time period, and are physically related, solar output (sunspots, F10.7) drives geomagnetic disturbances (Ap Index).

## Methodology

The last 10% of observations from each series are held out as a test set; the remaining data form the training set.

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
Ap Index is used as the response variable, with Sunspot Number and F10.7 as covariates. A dynamic regression model is fit on the training set and used to forecast Ap Index values over the test period.

### 4. Model Comparison
All three approaches are compared on forecasting accuracy (test set) and in-sample fit (train set), with discussion of why results differ across methods.

## Data Sources

- [WDC-SILSO Sunspot Number Data](https://www.sidc.be/silso/datafiles) — Royal Observatory of Belgium
- [F10.7 Solar Flux CSV](https://psl.noaa.gov/data/correlation/solar.csv) — NOAA Physical Sciences Laboratory
- [Kp/Ap Index Data](https://kp.gfz.de/en/data) — GFZ Helmholtz Centre for Geosciences, Potsdam
