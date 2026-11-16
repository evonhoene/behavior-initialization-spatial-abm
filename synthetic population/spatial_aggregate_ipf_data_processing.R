# =============================================================================
# spatial_aggregate_ipf_data_processing.R
#
# Builds census tract-level counts of adults (18+) by sex, age, race/ethnicity,
# education, and household income from ACS 2015-2019 5-year detailed tables,
# for use as constraints (marginals) in population synthesis.
#
# Run from the repository root:
#   Rscript src/01_population_synthesis/spatial_aggregate_ipf_data_processing.R
#
# Categories
#   sex        male, female
#   age        age1 18-29, age2 30-49, age3 50-64, age4 65+
#   race       race1 White non-Hispanic, race2 Black, race3 Hispanic,
#              race4 Other (remainder)
#   education  bach bachelor's degree or higher, n_bach less than bachelor's
#   income     income1 <$25k, income2 $25k-49,999, income3 $50k-99,999,
#              income4 $100k+ (household income shares applied to adults)
# Health insurance and percent urban are also calculated but are not used as
# constraints in this study.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readxl)
  library(stringr)
  library(writexl)
})

# ---- File paths (relative to the repository root) ---------------------------
acs_dir <- file.path("data", "public", "acs")
acs_files <- list(
  sex_age   = file.path(acs_dir, "ACSDT5Y2019.B01001-Data.csv"),
  white     = file.path(acs_dir, "ACSDT5Y2019.B01001H-Data.csv"),
  black     = file.path(acs_dir, "ACSDT5Y2019.B01001B-Data.csv"),
  hispanic  = file.path(acs_dir, "ACSDT5Y2019.B01001I-Data.csv"),
  education = file.path(acs_dir, "ACSDT5Y2019.B15001-Data.csv"),
  insurance = file.path(acs_dir, "ACSDT5Y2019.B27001-Data.csv"),
  income    = file.path(acs_dir, "ACSDT5Y2019.B19001-Data.csv")
)
urban_file  <- file.path("data", "public", "tract_percent_urban.xlsx")  # optional
output_file <- file.path("data", "intermediate", "FAIRFAX_census_tract_ACS_19FY_cleaned.xlsx")

# Study area: Fairfax County (51059) and the City of Fairfax (51600), Virginia
study_area_county_fips <- c("51059", "51600")

dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)

# ---- Helper functions ----------------------------------------------------------
# Reads a data.census.gov table: drops the label row and converts estimates
# to numbers.
read_acs_table <- function(path) {
  read.csv(path) %>%
    slice(-1) %>%
    mutate(across(starts_with("B"), ~ as.numeric(gsub(",", "", .x))))
}

# Sums ACS estimate columns given the table ID and line numbers.
sum_cols <- function(df, table_id, lines) {
  rowSums(df[, sprintf("%s_%03dE", table_id, lines)])
}

# Lines for adults aged 18+ in the race-specific tables (B01001H/B/I):
# male 18+ = lines 7-16, female 18+ = lines 22-31
adult_lines_race_tables <- c(7:16, 22:31)

# ---- Sex and age (B01001) -------------------------------------------------------
sex_age <- read_acs_table(acs_files$sex_age) %>%
  mutate(
    male   = B01001_002E - sum_cols(., "B01001", 3:6),    # all males minus under 18
    female = B01001_026E - sum_cols(., "B01001", 27:30),  # all females minus under 18
    total_pop_18o = male + female,
    age1 = sum_cols(., "B01001", c(7:11, 31:35)),   # 18-29
    age2 = sum_cols(., "B01001", c(12:15, 36:39)),  # 30-49
    age3 = sum_cols(., "B01001", c(16:19, 40:43)),  # 50-64
    age4 = sum_cols(., "B01001", c(20:25, 44:49))   # 65+
  )

# ---- Race/ethnicity (B01001H, B01001B, B01001I) ---------------------------------
white <- read_acs_table(acs_files$white) %>%
  mutate(race1 = sum_cols(., "B01001H", adult_lines_race_tables))
black <- read_acs_table(acs_files$black) %>%
  mutate(race2 = sum_cols(., "B01001B", adult_lines_race_tables))
hispanic <- read_acs_table(acs_files$hispanic) %>%
  mutate(race3 = sum_cols(., "B01001I", adult_lines_race_tables))

marginals <- white %>%
  select(GEO_ID, race1) %>%
  left_join(select(black, GEO_ID, race2), by = "GEO_ID") %>%
  left_join(select(hispanic, GEO_ID, race3), by = "GEO_ID") %>%
  left_join(
    select(sex_age, GEO_ID, age1, age2, age3, age4, male, female, total_pop_18o),
    by = "GEO_ID"
  ) %>%
  mutate(race4 = total_pop_18o - (race1 + race2 + race3)) %>%
  # Where "Other" is negative (overlap between race tables), subtract the
  # excess from Hispanic and set Other to 0
  mutate(
    race3 = race3 + ifelse(race4 < 0, race4, 0),
    race4 = ifelse(race4 < 0, 0, race4)
  )

# ---- Education (B15001) -------------------------------------------------------------
education <- read_acs_table(acs_files$education) %>%
  mutate(bach = sum_cols(., "B15001", c(9, 10, 17, 18, 25, 26, 33, 34, 41, 42)))

marginals <- marginals %>%
  left_join(select(education, GEO_ID, bach), by = "GEO_ID") %>%
  mutate(n_bach = total_pop_18o - bach)

# ---- Health insurance (B27001; not used as a constraint) ---------------------------
insurance <- read_acs_table(acs_files$insurance) %>%
  mutate(perc_insured = sum_cols(., "B27001",
    c(4, 7, 10, 13, 16, 19, 22, 25, 28, 32, 35, 38, 41, 44, 47, 50, 53, 56)) / B27001_001E)

marginals <- marginals %>%
  left_join(select(insurance, GEO_ID, perc_insured), by = "GEO_ID") %>%
  mutate(
    insured   = round(total_pop_18o * perc_insured),
    n_insured = total_pop_18o - insured,
    GEOID     = str_sub(GEO_ID, -11, -1)
  )

# ---- Percent urban (optional; not used as a constraint) ----------------------------
if (file.exists(urban_file)) {
  urban <- read_excel(urban_file)
  marginals <- marginals %>%
    left_join(select(urban, GEOID, perc_urban), by = "GEOID") %>%
    mutate(
      p_urban   = round((perc_urban * total_pop_18o) / 100),
      p_n_urban = total_pop_18o - p_urban
    )
}

# ---- Household income (B19001) -------------------------------------------------------
# Household income shares are applied to the adult population; income4 takes
# the remainder so the four categories sum to the adult total.
income <- read_acs_table(acs_files$income) %>%
  mutate(
    perc_income1 = sum_cols(., "B19001", 2:5)   / B19001_001E,
    perc_income2 = sum_cols(., "B19001", 6:10)  / B19001_001E,
    perc_income3 = sum_cols(., "B19001", 11:13) / B19001_001E,
    perc_income4 = sum_cols(., "B19001", 14:17) / B19001_001E
  )

marginals <- marginals %>%
  left_join(
    select(income, GEO_ID, perc_income1, perc_income2, perc_income3, perc_income4),
    by = "GEO_ID"
  ) %>%
  mutate(
    income1 = round(total_pop_18o * perc_income1),
    income2 = round(total_pop_18o * perc_income2),
    income3 = round(total_pop_18o * perc_income3),
    income4 = total_pop_18o - (income1 + income2 + income3)
  )

# ---- Restrict to the study area and check constraints ------------------------------
marginals <- marginals %>%
  filter(total_pop_18o != 0) %>%
  mutate(
    state_fips  = str_sub(GEO_ID, 10, -10),
    county_fips = str_sub(GEO_ID, 10, -7)
  ) %>%
  filter(county_fips %in% study_area_county_fips) %>%
  mutate(
    age_check       = total_pop_18o - (age1 + age2 + age3 + age4),
    gender_check    = total_pop_18o - (male + female),
    race_check      = total_pop_18o - (race1 + race2 + race3 + race4),
    education_check = total_pop_18o - (bach + n_bach),
    income_check    = total_pop_18o - (income1 + income2 + income3 + income4),
    insured_check   = total_pop_18o - (insured + n_insured)
  )

checks <- c("age_check", "gender_check", "race_check", "education_check", "income_check")
if (any(as.matrix(marginals[, checks]) != 0, na.rm = TRUE)) {
  warning("Some tracts have category totals that differ from the adult total.")
}

write_xlsx(marginals, output_file)
message(sprintf("Wrote %d census tracts to %s", nrow(marginals), output_file))
