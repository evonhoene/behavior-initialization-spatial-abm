# =============================================================================
# uas282_pop_gen.R
#
# Generates a synthetic adult population for the study area by fitting
# Understanding America Study (UAS) survey 282 respondents to ACS tract-level
# marginals with iterative proportional fitting (IPF), integerising the
# weights with the truncate-replicate-sample (TRS) method, and replicating
# respondents with their survey attributes, including vaccination intention.
#
# Adapted from the population synthesis code of Von Hoene et al. (2025),
# PLOS Computational Biology, https://doi.org/10.1371/journal.pcbi.1012439
#
# Run from the repository root (after spatial_aggregate_ipf_data_processing.R):
#   Rscript src/01_population_synthesis/uas282_pop_gen.R
#
# Constraints are applied in this order: age, sex, race/ethnicity,
# education, household income.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readxl)
})

# ---- File paths (relative to the repository root) ---------------------------
survey_file     <- file.path("data", "restricted", "uas282_edited4IPF_for_syn_pops.xlsx")
marginals_file  <- file.path("data", "intermediate", "FAIRFAX_census_tract_ACS_19FY_cleaned.xlsx")
weights_file    <- file.path("data", "intermediate", "ipf_weights.csv")
integer_file    <- file.path("data", "intermediate", "ipf_integer_weights.csv")
replicated_file <- file.path("data", "intermediate", "uas282_ACS2019_replicated_individuals.csv")

# ---- Parameters ---------------------------------------------------------------------
seed           <- 123  # random seed for integerisation
ipf_iterations <- 1    # number of full IPF passes over all constraints

dir.create(dirname(replicated_file), showWarnings = FALSE, recursive = TRUE)

# ---- Read data ------------------------------------------------------------------------
survey <- read_excel(survey_file)
acs    <- read_excel(marginals_file)

constraints <- list(
  age       = c("age1", "age2", "age3", "age4"),
  sex       = c("male", "female"),
  race      = c("race1", "race2", "race3", "race4"),
  education = c("n_bach", "bach"),
  income    = c("income1", "income2", "income3", "income4")
)
constraint_vars <- unlist(constraints, use.names = FALSE)

# Individual-level binary indicators (respondents x categories)
ind <- as.matrix(survey[, constraint_vars])
rownames(ind) <- survey$ID

# Tract-level counts (tracts x categories)
cons <- as.matrix(acs[, constraint_vars])
rownames(cons) <- acs$GEO_ID
cons[, "race4"][cons[, "race4"] < 0] <- 0
cons[cons == 0] <- 0.000001  # IPF cannot scale weights to exactly zero

# Each respondent must belong to exactly one category of each constraint
for (domain in names(constraints)) {
  if (any(rowSums(ind[, constraints[[domain]], drop = FALSE]) != 1)) {
    stop(sprintf("Each respondent must belong to exactly one %s category.", domain))
  }
}

# ---- IPF ---------------------------------------------------------------------------------
# Weight of each respondent (row) in each tract (column), starting at 1
weights <- matrix(1, nrow = nrow(ind), ncol = nrow(cons),
                  dimnames = list(rownames(ind), rownames(cons)))

# Simulated tract totals for each category given the weights (categories x tracts)
simulated_totals <- function(w) t(ind) %*% w

for (iteration in seq_len(ipf_iterations)) {
  for (domain in names(constraints)) {
    sim <- simulated_totals(weights)
    for (category in constraints[[domain]]) {
      rows <- ind[, category] == 1
      # Scale the weights of respondents in this category so the simulated
      # tract totals match the ACS totals
      adjustment <- cons[, category] / sim[category, ]
      weights[rows, ] <- sweep(weights[rows, , drop = FALSE], 2, adjustment, `*`)
    }
  }
}

# Fit diagnostics
fitted <- t(simulated_totals(weights))  # tracts x categories
message(sprintf("IPF fit: correlation between constraints and fitted totals = %.4f",
                cor(as.vector(cons), as.vector(fitted))))
tract_cor <- sapply(seq_len(nrow(cons)), function(i) cor(cons[i, ], fitted[i, ]))
message(sprintf("Lowest tract-level correlation = %.4f", min(tract_cor)))

write.csv(data.frame(ID = rownames(weights), weights, check.names = FALSE),
          weights_file, row.names = FALSE)

# ---- Integerisation (truncate, replicate, sample) -------------------------------------
# Keeps the integer part of each weight, then allocates the remaining
# population by sampling respondents with probability proportional to the
# fractional parts of their weights.
int_trs <- function(x) {
  xv   <- as.vector(x)
  xint <- floor(xv)
  r    <- xv - xint
  deficit <- round(sum(r))
  topup <- sample(length(x), size = deficit, prob = r)
  xint[topup] <- xint[topup] + 1
  dim(xint) <- dim(x)
  dimnames(xint) <- dimnames(x)
  xint
}

set.seed(seed)
int_weights <- int_trs(weights)

write.csv(data.frame(ID = rownames(int_weights), int_weights, check.names = FALSE),
          integer_file, row.names = FALSE)

# ---- Expansion and replication -------------------------------------------------------
# One row per synthetic agent (respondent ID and tract), ordered by respondent
# and then by tract
nonzero <- which(int_weights > 0, arr.ind = TRUE)
nonzero <- nonzero[order(nonzero[, "row"], nonzero[, "col"]), , drop = FALSE]
counts  <- int_weights[nonzero]

expanded <- data.frame(
  uasID = as.numeric(rownames(int_weights)[nonzero[, "row"]]),
  GEOID = colnames(int_weights)[nonzero[, "col"]]
)[rep(seq_len(nrow(nonzero)), counts), ]

# Attach survey attributes, including vaccination intention
attribute_vars <- c(
  "vaccine", "depression",
  "male", "female",
  "race1", "race2", "race3", "race4",
  "age1", "age2", "age3", "age4",
  "bach", "n_bach",
  "income1", "income2", "income3", "income4",
  "attitude", "sub_norms", "benefits", "barriers", "susceptibility", "severity",
  "health_insured",
  "cr025a_binary", "cr025b_binary", "cr025c_binary", "cr025d_binary"
)

replicated <- expanded %>%
  left_join(select(survey, ID, all_of(attribute_vars)), by = c("uasID" = "ID"))

write.csv(replicated, replicated_file, row.names = FALSE)
message(sprintf("Wrote %s synthetic agents in %d tracts to %s",
                format(nrow(replicated), big.mark = ","),
                length(unique(replicated$GEOID)), replicated_file))
