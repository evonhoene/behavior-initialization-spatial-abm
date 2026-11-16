# =============================================================================
# assigning_vaccinated_pop_with_NHTS_mobility.R
#
# Adds daily mobility to the synthetic population and writes the vaccination
# scenarios used by the agent-based model (ABM).
#
#   Section 1  Match agents to NHTS respondents and assign homes
#   Section 2  Replace school trips with school IDs
#   Section 3  Assign workplaces
#   Section 4  Build trip chains and write the vaccination scenarios
#              (synthesized, uniform, no behavior)
#   Section 5  Build activity timing (dwell times) for the ABM
#
#
# Each section reads the file written by the previous section, so sections can
# be run separately. Choose which to run in `sections_to_run` below.

# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readxl)
  library(stringr)
  library(jsonlite)
})

# Write large IDs in full (e.g. 200000, not 2e+05) in CSV files and trip chains
options(scipen = 999)

# ---- Sections to run ------------------------------------------------------------
sections_to_run <- c("homes", "schools", "workplaces", "scenarios", "dwell_times")

# ---- File paths (relative to the repository root) -------------------------------------
public_dir       <- file.path("data", "public")
intermediate_dir <- file.path("data", "intermediate")
population_dir   <- file.path("data", "population")

# Inputs
replicated_file  <- file.path(intermediate_dir, "uas282_ACS2019_replicated_individuals.csv")
nhts_person_file <- file.path(public_dir, "nhts", "nhts.csv")           # 2017 NHTS persons
nhts_trips_file  <- file.path(public_dir, "nhts", "revised_trips.csv")  # trip purposes and agent_type
nhts_dwell_file  <- file.path(public_dir, "nhts", "NHTS2017_dwell_time.csv")
nhts_start_file  <- file.path(public_dir, "nhts", "NHTS2017_start_time.csv")
buildings_file   <- file.path(public_dir, "input_buildings_spatially_joined_blocks.xlsx")
school_ids_file  <- file.path(intermediate_dir, "uas_pop_with_school_ids.csv")  # from school assignment script
work_tracts_file <- file.path(intermediate_dir,
  "uas282_ACS2019_population_with_NHTS_trip_chains_EDITED_with_HOMES_SCHOOLS_WORKTRACTS.csv")  # from processing_LODES.R

# Intermediate outputs
nhts_clean_file  <- file.path(intermediate_dir, "nhts_persons_cleaned_for_matching.csv")
homes_file       <- file.path(intermediate_dir,
  "uas282_ACS2019_population_with_NHTS_trip_chains_EDITED_with_HOMES.csv")
schools_file     <- file.path(intermediate_dir,
  "uas282_ACS2019_population_with_NHTS_trip_chains_EDITED_with_HOMES_SCHOOLS.csv")
workplaces_file  <- file.path(intermediate_dir,
  "uas282_ACS2019_population_with_NHTS_trip_chains_EDITED_with_HOMES_SCHOOLS_WORK_PLACES.csv")

# Final ABM inputs
prefix <- file.path(population_dir, "uas282_ACS2019_population_with_NHTS_trip_chains")
synthesized_full_file <- paste0(prefix, "_SYNTHESIZED_vaccine_behavior_BEFORE_FILTERING.csv")
synthesized_file      <- paste0(prefix, "_SYNTHESIZED_vaccine_behavior.csv")
uniform_full_file     <- paste0(prefix, "_IMPOSED_vaccine_behavior_BEFORE_FILTERING.csv")
uniform_file          <- paste0(prefix, "_IMPOSED_vaccine_behavior.csv")
no_behavior_file      <- paste0(prefix, "_NO_vaccine_behavior.csv")
tract_vax_synth_file   <- file.path(population_dir, "synthesized_vaccinated_census_tracts.csv")
tract_vax_uniform_file <- file.path(population_dir, "uniform_vaccinated_census_tracts.csv")
dwell_time_file       <- file.path(population_dir, "dwell_time_nhts17_updated.csv")
trip_sequences_file   <- file.path(population_dir, "trip_sequences.json")

# ---- Parameters ----------------------------------------------------------------------
seed                 <- 123   # random seed for every sampling step
uniform_vaccine_rate <- 0.70  # proportion vaccinated under uniform assignment
max_trips            <- 20    # agents with more trips than this are removed

demographic_vars <- c(
  "age1", "age2", "age3", "age4",
  "male", "female",
  "bach", "n_bach",
  "income1", "income2", "income3", "income4",
  "race1", "race2", "race3", "race4"
)

# Columns read by the ABM
abm_columns <- c("agent_id", "nhts_id", "agent_type", "census_tract", "trip_chain", "vaccinated")

for (d in c(intermediate_dir, population_dir)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

# ---- Helper functions ------------------------------------------------------------------
# Samples one element from a vector. Unlike sample(x, 1), this is safe when x
# has length 1 (sample() would otherwise draw from 1:x for a single number).
sample_one <- function(x) x[sample.int(length(x), 1)]

# Picks one building at random for each agent from the list in `buildings`.
assign_building <- function(df) {
  df %>%
    rowwise() %>%
    mutate(building_id = if (length(buildings) > 0) sample_one(buildings) else NA) %>%
    ungroup() %>%
    select(-buildings)
}

# Lists building IDs of one type for each census tract.
buildings_by_tract <- function(type) {
  read_excel(buildings_file) %>%
    mutate(tract_id = substr(GEOID10, 1, 11)) %>%
    filter(bldg_type == type) %>%
    group_by(tract_id) %>%
    summarise(buildings = list(bldg_id), .groups = "drop")
}

# Replaces a trip purpose code with each agent's location ID.
replace_trip_code <- function(df, code, ids) {
  trip_cols <- grep("^trip_purpose", names(df), value = TRUE)
  df %>% mutate(across(all_of(trip_cols), ~ ifelse(. == code, ids, .)))
}

# Warns if a trip purpose code was not fully replaced.
check_code_replaced <- function(df, code) {
  trip_cols <- grep("^trip_purpose", names(df), value = TRUE)
  remaining <- sum(sapply(df[trip_cols], function(x) sum(x == code, na.rm = TRUE)))
  if (remaining > 0) warning(sprintf("%d trips still have purpose code %s.", remaining, code))
}

require_file <- function(path, made_by) {
  if (!file.exists(path)) stop(sprintf("%s not found. It is created by %s.", path, made_by))
}

# =============================================================================
# Section 1: Match agents to NHTS respondents and assign homes
# =============================================================================
if ("homes" %in% sections_to_run) {
  nhts_pop   <- read.csv(nhts_person_file)
  nhts_trips <- read.csv(nhts_trips_file)
  agents     <- read.csv(replicated_file)

  # Recode NHTS respondents into the same binary categories as the agents
  nhts_pop <- nhts_pop %>%
    mutate(uniquepersonID = paste0(HOUSEID, PERSONID)) %>%
    # Negative codes are missing or refused responses
    filter(R_AGE >= 0, R_RACE >= 0, R_SEX >= 0, R_HISP >= 0, EDUC >= 0, HHFAMINC >= 0) %>%
    mutate(
      age1 = ifelse(R_AGE >= 18 & R_AGE <= 29, 1, 0),
      age2 = ifelse(R_AGE >= 30 & R_AGE <= 49, 1, 0),
      age3 = ifelse(R_AGE >= 50 & R_AGE <= 64, 1, 0),
      age4 = ifelse(R_AGE >= 65, 1, 0),

      i_race1 = ifelse(R_RACE == 1, 1, 0),  # White
      i_race2 = ifelse(R_RACE == 2, 1, 0),  # Black
      i_race3 = ifelse(R_HISP == 1, 1, 0),  # Hispanic
      i_race4 = ifelse(i_race1 == 0 & i_race2 == 0 & i_race3 == 0, 1, 0),  # Other
      total_race = i_race1 + i_race2 + i_race3 + i_race4,

      bach   = ifelse(EDUC >= 4, 1, 0),  # 4 = bachelor's degree
      n_bach = ifelse(EDUC < 4, 1, 0),

      male   = ifelse(R_SEX == 1, 1, 0),
      female = ifelse(R_SEX == 2, 1, 0),

      income1 = ifelse(HHFAMINC %in% 1:3, 1, 0),  # < $25k
      income2 = ifelse(HHFAMINC %in% 4:5, 1, 0),  # $25k-49,999
      income3 = ifelse(HHFAMINC %in% 6:7, 1, 0),  # $50k-99,999
      income4 = ifelse(HHFAMINC >= 8, 1, 0)       # $100k+
    ) %>%
    # Respondents coded both White or Black and Hispanic are assigned to Other
    mutate(
      race1 = ifelse(total_race == 2, 0, i_race1),
      race2 = ifelse(total_race == 2, 0, i_race2),
      race3 = ifelse(total_race == 2, 0, i_race3),
      race4 = ifelse(total_race == 2, 1, i_race4)
    ) %>%
    # Keep adults only (respondents under 18 fall in no age category)
    filter(age1 + age2 + age3 + age4 != 0)

  stopifnot(!anyNA(nhts_pop[, demographic_vars]))

  # Keep only respondents who have a trip record
  nhts_pop <- nhts_pop[nhts_pop$uniquepersonID %in% nhts_trips$uniquepersonID, ]
  write.csv(nhts_pop, nhts_clean_file, row.names = FALSE)

  # Match each agent to a random NHTS respondent with the same combination of
  # age, sex, education, income, and race/ethnicity (stratum)
  make_stratum_key <- function(df) {
    df %>% mutate(stratum_key = do.call(paste, c(across(all_of(demographic_vars)), sep = "_")))
  }
  agents   <- make_stratum_key(agents)
  nhts_pop <- make_stratum_key(nhts_pop)

  missing_strata <- setdiff(unique(agents$stratum_key), unique(nhts_pop$stratum_key))
  if (length(missing_strata) > 0) {
    warning(sprintf("%d agent strata have no NHTS respondent.", length(missing_strata)))
  }

  donor_list <- nhts_pop %>%
    group_by(stratum_key) %>%
    summarise(donors = list(uniquepersonID), .groups = "drop")

  set.seed(seed)
  agents <- agents %>%
    left_join(donor_list, by = "stratum_key") %>%
    rowwise() %>%
    mutate(uniquepersonID = sample_one(donors)) %>%
    ungroup() %>%
    select(-donors)

  stopifnot(!anyNA(agents$uniquepersonID))

  # Join the matched respondent's trip purposes
  agents <- agents %>%
    mutate(uniquepersonID = as.character(uniquepersonID)) %>%
    left_join(mutate(nhts_trips, uniquepersonID = as.character(uniquepersonID)),
              by = "uniquepersonID")

  # NHTS trip purpose codes -> ABM activity types. Codes 1 (home), 10 (work),
  # and 20 (school) are replaced with location IDs later.
  activity_codes <- c(
    "40" = "errands",
    "97" = "errands",
    "50" = "recreation",
    "30" = "hospitals",
    "80" = "restaurants"
  )
  recode_activity <- function(x) {
    x <- as.character(x)
    hit <- x %in% names(activity_codes)
    x[hit] <- activity_codes[x[hit]]
    x
  }
  trip_cols <- grep("^trip_purpose", names(agents), value = TRUE)
  agents <- agents %>% mutate(across(all_of(trip_cols), recode_activity))

  # Assign each agent a residential building in its home tract. Tracts with
  # no residential buildings borrow homes from a neighbouring tract.
  home_tract_substitutes <- c(
    "51059452802" = "51059452801",
    "51059980100" = "51059431600"
  )

  set.seed(seed)
  agents <- agents %>%
    mutate(tract_id = substr(GEOID, nchar(GEOID) - 10, nchar(GEOID))) %>%
    mutate(tract_id = ifelse(tract_id %in% names(home_tract_substitutes),
                             home_tract_substitutes[tract_id], tract_id)) %>%
    left_join(buildings_by_tract("residential"), by = "tract_id") %>%
    assign_building() %>%
    rename(home_id = building_id)

  if (anyNA(agents$home_id)) {
    warning(sprintf("%d agents could not be assigned a home.", sum(is.na(agents$home_id))))
  }

  agents <- replace_trip_code(agents, "1", agents$home_id)
  check_code_replaced(agents, "1")

  write.csv(agents, homes_file, row.names = FALSE)
  message(sprintf("Section 1: wrote %s agents with homes to %s",
                  format(nrow(agents), big.mark = ","), homes_file))
}

# =============================================================================
# Section 2: Replace school trips with school IDs
# =============================================================================
if ("schools" %in% sections_to_run) {
  require_file(school_ids_file, "the school assignment script (Python), using the Section 1 output")
  agents <- read.csv(school_ids_file)

  agents <- replace_trip_code(agents, "20", agents$school_id)
  check_code_replaced(agents, "20")

  write.csv(agents, schools_file, row.names = FALSE)
  message(sprintf("Section 2: wrote %s agents with schools to %s",
                  format(nrow(agents), big.mark = ","), schools_file))
}

# =============================================================================
# Section 3: Assign workplaces
# =============================================================================
if ("workplaces" %in% sections_to_run) {
  require_file(work_tracts_file, "processing_LODES.R, using the Section 2 output")
  agents <- read.csv(work_tracts_file)

  # Work tracts with no workplace buildings borrow workplaces from a
  # neighbouring tract
  work_tract_substitutes <- c(
    "51059420501" = "51059420502",
    "51059431900" = "51059430802",
    "51059421702" = "51059421701"
  )

  set.seed(seed)
  agents <- agents %>%
    # Home tract, taken from the agent's synthetic population tract
    mutate(tract_id = substr(GEOID, nchar(GEOID) - 10, nchar(GEOID))) %>%
    mutate(work_tract_id = as.character(work_tract_id)) %>%
    mutate(work_tract_id = ifelse(work_tract_id %in% names(work_tract_substitutes),
                                  work_tract_substitutes[work_tract_id], work_tract_id)) %>%
    left_join(buildings_by_tract("workplace"), by = c("work_tract_id" = "tract_id")) %>%
    assign_building() %>%
    rename(work_id = building_id)

  agents <- replace_trip_code(agents, "10", agents$work_id)
  check_code_replaced(agents, "10")

  write.csv(agents, workplaces_file, row.names = FALSE)
  message(sprintf("Section 3: wrote %s agents with workplaces to %s",
                  format(nrow(agents), big.mark = ","), workplaces_file))
}

# =============================================================================
# Section 4: Build trip chains and write the vaccination scenarios
# =============================================================================
if ("scenarios" %in% sections_to_run) {
  agents <- read.csv(workplaces_file)
  trip_cols <- grep("^trip_purpose", names(agents), value = TRUE)

  # Combine trip purposes into one chain, e.g. [68933, 'errands', 103714]
  agents$trip_chain <- apply(agents[, trip_cols], 1, function(x) {
    x <- trimws(x[!is.na(x) & trimws(x) != ""])
    paste0("[", paste(x, collapse = ", "), "]")
  })
  # Quote activity names so the chain can be read as a Python list
  agents$trip_chain <- gsub("(?<=\\[|, )([A-Za-z_]+)(?=,|\\])", "'\\1'",
                            agents$trip_chain, perl = TRUE)

  agents <- agents %>%
    mutate(count_trips = str_count(trip_chain, ",") + 1) %>%
    filter(count_trips <= max_trips) %>%
    filter(uniquepersonID != 404000000) %>%  # not a valid NHTS person ID
    mutate(
      agent_id     = seq_len(n()) - 1,
      nhts_id      = uniquepersonID,
      census_tract = tract_id
    )

  summarise_tracts <- function(df) {
    df %>%
      group_by(census_tract) %>%
      summarise(percent_vaccinated = mean(vaccinated, na.rm = TRUE) * 100,
                n_agents = n(), .groups = "drop")
  }

  # Synthesized: vaccination intention from each agent's UAS respondent
  synthesized <- agents %>% mutate(vaccinated = vaccine)
  write.csv(synthesized, synthesized_full_file, row.names = FALSE)
  write.csv(synthesized[, abm_columns], synthesized_file, row.names = FALSE)
  write.csv(summarise_tracts(synthesized), tract_vax_synth_file, row.names = FALSE)

  # No behavior: no agents vaccinated
  no_behavior <- agents %>% mutate(vaccinated = 0)
  write.csv(no_behavior[, abm_columns], no_behavior_file, row.names = FALSE)

  # Uniform: a fixed share of agents vaccinated, selected at random
  set.seed(seed)
  n <- nrow(agents)
  vaccinated_idx <- sample(n, round(uniform_vaccine_rate * n))
  uniform <- agents %>% mutate(vaccinated = 0)
  uniform$vaccinated[vaccinated_idx] <- 1
  write.csv(uniform, uniform_full_file, row.names = FALSE)
  write.csv(uniform[, abm_columns], uniform_file, row.names = FALSE)
  write.csv(summarise_tracts(uniform), tract_vax_uniform_file, row.names = FALSE)

  message(sprintf("Section 4: %s agents; vaccinated %.1f%% (synthesized), %.1f%% (uniform)",
                  format(n, big.mark = ","),
                  mean(synthesized$vaccinated) * 100, mean(uniform$vaccinated) * 100))
}

# =============================================================================
# Section 5: Build activity timing (dwell times) for the ABM
# =============================================================================
# For each NHTS respondent in the population: the start time of the first trip
# and the time spent at each activity, in minutes rounded up to whole hours.
# Each sequence should contain one more element than the agent's trip chain.
if ("dwell_times" %in% sections_to_run) {
  dwell_time <- read.csv(nhts_dwell_file)
  start_time <- read.csv(nhts_start_file)
  agents     <- read.csv(synthesized_file)

  # Rounds positive values up to the next multiple of 60 minutes; leaves
  # missing codes (-9) unchanged
  round_up_to_hour <- function(x) ifelse(x > 0, ceiling(x / 60) * 60, x)

  dwell_time <- dwell_time %>%
    left_join(select(start_time, uniquepersonID, start_time1), by = "uniquepersonID") %>%
    # Start time from HHMM to minutes after midnight
    mutate(start_time1 = (start_time1 %/% 100) * 60 + (start_time1 %% 100)) %>%
    mutate(across(-uniquepersonID, round_up_to_hour)) %>%
    # Time remaining in the day after all recorded dwell times
    mutate(dwell_time_final = 1440 - rowSums(
      across(starts_with("dwell_time"), ~ ifelse(. == -9, NA, .)), na.rm = TRUE
    )) %>%
    semi_join(agents, by = c("uniquepersonID" = "nhts_id")) %>%
    # Sequence: start time, then every dwell time (including the final one),
    # excluding missing codes
    rowwise() %>%
    mutate(time_sequence = {
      v <- c(start_time1, c_across(starts_with("dwell_time")))
      paste0("[", paste(v[v != -9 & !is.na(v)], collapse = ", "), "]")
    }) %>%
    ungroup()

  write.csv(dwell_time, dwell_time_file, row.names = FALSE)

  sequences <- lapply(dwell_time$time_sequence, function(x) {
    as.numeric(strsplit(gsub("\\[|\\]", "", x), ",\\s*")[[1]])
  })
  n_negative <- sum(sapply(sequences, function(v) any(v[-1] < 0, na.rm = TRUE)))
  if (n_negative > 0) {
    warning(sprintf("%d respondents have a negative dwell time.", n_negative))
  }

  trip_dict <- setNames(sequences, dwell_time$uniquepersonID)
  write(toJSON(trip_dict, auto_unbox = TRUE), trip_sequences_file)
  message(sprintf("Section 5: wrote trip timing for %s respondents to %s",
                  format(length(trip_dict), big.mark = ","), trip_sequences_file))
}
