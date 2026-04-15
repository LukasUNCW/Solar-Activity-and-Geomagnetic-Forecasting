# ============================================================
# 01_data_prep.R
# Load, clean, and merge the three solar/geomagnetic datasets
# ============================================================

library(tidyr)
library(dplyr)

# ------------------------------------------------------------
# 1. Sunspot Number (SILSO monthly mean)
# ------------------------------------------------------------
sunspot <- read.csv("data/SN_m_tot_V2_0.csv", sep = ";", header = FALSE)
colnames(sunspot) <- c("year", "month", "decimal_date", "sunspot", "sd", "n_obs", "quality")

# Replace missing values (-1) with NA
sunspot$sunspot[sunspot$sunspot == -1] <- NA

# Keep only year, month, sunspot
sunspot <- sunspot %>%
  select(year, month, sunspot) %>%
  filter(year >= 1964, year <= 2024)

# ------------------------------------------------------------
# 2. Solar Flux F10.7 (NOAA PSL monthly)
# ------------------------------------------------------------
f107 <- read.csv("data/solar.csv", skip = 1, header = FALSE)
colnames(f107) <- c("date", "f107")

# Replace missing values with NA
f107$f107[f107$f107 <= -999] <- NA

# Extract year and month
f107$date <- as.Date(f107$date)
f107$year  <- as.integer(format(f107$date, "%Y"))
f107$month <- as.integer(format(f107$date, "%m"))

f107 <- f107 %>%
  select(year, month, f107) %>%
  filter(year >= 1964, year <= 2024)

# ------------------------------------------------------------
# 3. Geomagnetic Ap Index (GFZ Potsdam monthly)
# ------------------------------------------------------------
ap_raw <- read.table("data/ap_monthly.txt", header = FALSE, fill = TRUE)
colnames(ap_raw) <- c("label", "year", "jan", "feb", "mar", "apr", "may",
                      "jun", "jul", "aug", "sep", "oct", "nov", "dec", "annual")

# Convert from wide to long format
ap_long <- ap_raw %>%
  select(year, jan:dec) %>%
  pivot_longer(cols = jan:dec, names_to = "month_name", values_to = "ap") %>%
  mutate(month = match(month_name, c("jan","feb","mar","apr","may","jun",
                                     "jul","aug","sep","oct","nov","dec"))) %>%
  select(year, month, ap) %>%
  filter(year >= 1964, year <= 2024)

# Replace any missing/placeholder values with NA
ap_long$ap[ap_long$ap <= 0] <- NA

# ------------------------------------------------------------
# 4. Merge all three into one data frame
# ------------------------------------------------------------
solar_data <- sunspot %>%
  inner_join(f107,    by = c("year", "month")) %>%
  inner_join(ap_long, by = c("year", "month")) %>%
  arrange(year, month)

# Add a proper date column
solar_data$date <- as.Date(paste(solar_data$year, solar_data$month, "01", sep = "-"))

# Reorder columns
solar_data <- solar_data %>%
  select(date, year, month, sunspot, f107, ap)

# ------------------------------------------------------------
# 5. Split into train and test sets (hold out last 10%)
# ------------------------------------------------------------
n <- nrow(solar_data)
n_test  <- floor(n * 0.10)
n_train <- n - n_test

train <- solar_data[1:n_train, ]
test  <- solar_data[(n_train + 1):n, ]

cat("Total observations:", n, "\n")
cat("Training set:      ", n_train, "obs (", train$date[1], "to", train$date[n_train], ")\n")
cat("Test set:          ", n_test,  "obs (", test$date[1],  "to", test$date[n_test],  ")\n")

# ------------------------------------------------------------
# 6. Convert to time series objects for modeling
# ------------------------------------------------------------
start_year  <- train$year[1]
start_month <- train$month[1]

ts_sunspot <- ts(train$sunspot, start = c(start_year, start_month), frequency = 12)
ts_f107    <- ts(train$f107,    start = c(start_year, start_month), frequency = 12)
ts_ap      <- ts(train$ap,      start = c(start_year, start_month), frequency = 12)

# ------------------------------------------------------------
# 7. Quick summary check
# ------------------------------------------------------------
cat("\n--- Summary of merged dataset ---\n")
print(summary(solar_data[, c("sunspot", "f107", "ap")]))

cat("\nFirst few rows:\n")
print(head(solar_data))

cat("\nLast few rows:\n")
print(tail(solar_data))

# Save the cleaned data
write.csv(solar_data, "data/solar_data_clean.csv", row.names = FALSE)
cat("\nClean data saved to data/solar_data_clean.csv\n")
