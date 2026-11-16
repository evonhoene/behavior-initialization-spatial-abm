# Initializing Health Behaviors for Spatial ABMs of Disease Spread

Code and data for comparing uniform assignment and joint-distribution population synthesis for initializing health behaviors in a spatial agent-based model (ABM) of COVID-19.

> **Note for reviewers:** This repository has been anonymized for double-anonymized peer review. Author information will be added after review.

---

## Overview

This repository accompanies a study that examines how the method used to initialize a health behavior (COVID-19 vaccination intention) in a synthetic population affects the simulated disease outcomes from a spatial ABM. Two approaches are compared using the same synthetic population, mobility patterns, and disease model, differing only in how vaccination is assigned:

- **Uniform assignment** – every agent has the same probability of being vaccinated, independent of demographic attributes and location.
- **Synthesized assignment (joint-distribution population synthesis)** – vaccination is assigned jointly with demographic attributes and geography by fitting individual survey records to census tract-level demographic constraints using iterative proportional fitting (IPF).

A baseline scenario with no vaccination is also included. Outcomes are compared at the macro level (epidemic trajectory) and meso level (infection by demographic group and census tract).

## Data

### Data sources

| Dataset | Use | Availability |
|---|---|---|
| American Community Survey (ACS) 2015–2019 5-year estimates | Tract-level demographic constraints for population synthesis | Public – U.S. Census Bureau |
| Understanding America Study (UAS) survey 282 (Feb–Mar 2021) | Individual-level demographics and vaccination intention | Registered users only – [uasdata.usc.edu](https://uasdata.usc.edu). Not redistributed here. |
| 2017 National Household Travel Survey (NHTS) | Daily trip chains | Public – Federal Highway Administration |
| Advan | [TODO: describe use] | Commercial license – not redistributed here |
| Observed COVID-19 case data | Comparison with simulated spatial patterns | [TODO: source and access conditions] |
| Observed COVID-19 vaccination data (December 2021) | Comparison with simulated tract-level vaccination | [TODO: source and access conditions] |

See `data/README.md` for instructions on obtaining each dataset and where to place the files.

### What is included

- **Public inputs** in `data/public/` [TODO: list, e.g. ACS extracts, tract boundaries].
- **Model outputs** in `outputs/`, sufficient to reproduce every figure and table without rerunning the model:
  - Per-tick epidemic summaries for each scenario
  - Run-level summary metrics (agents ever infected, cumulative cases) for each scenario
  - Census tract-level infection summaries for the uniform and synthesized scenarios
  - Logistic regression coefficients for each run
  - Tract-level comparison of simulated and observed vaccination

### What is not included

The UAS microdata, Advan data, and [TODO: case data] cannot be redistributed under their terms of use. Because each agent in the synthetic population carries attributes drawn from a UAS respondent, the full synthetic population is also not distributed; it can be regenerated with the code in `src/01_population_synthesis/` once the UAS data have been obtained.

---

## Reproducing the results

Run the steps in order. Steps 1–3 require the restricted UAS data; step 4 can be run directly from the outputs included in this repository.

### 1. Generate the synthetic population

Fits UAS 282 records to ACS tract-level marginals (sex, race/ethnicity, age, education, household income) using IPF, and assigns vaccination under the uniform and synthesized approaches.

### 2. Assign mobility

Matches each agent to an NHTS trip chain based on demographic characteristics and assigns home, work, and school locations.

### 3. Run the ABM

Runs 30 independent runs for each scenario.

### 4. Analysis

Computes the IPF fit statistics, logistic regressions and Wald z-tests, tract-level statistics, and comparisons with observed data, and writes all figures and tables.

---

## ABM description
 
The model is described in full in Atwal et al. (2026) and its [original repository](https://github.com/heykuldip/mobility-affects-disease).

Main features of the original model:
 
- Agents move among home, work, school, and activity locations at hourly time steps according to their assigned trip chains.
- Agents interact at POIs, determined from trip chains, where disease spread can occur.
  
Additions made for this study:
- Agents are drawn from the synthetic populations generated here, carrying their demographic attributes, home tracts, and vaccination status.
- Vaccinated agents are fully protected from infection.

| | |
|---|---|
| Study area | Fairfax County and the City of Fairfax, Virginia (261 census tracts) |
| Agents | 893,834 adults aged 18+ |
| Simulation length | 50 days at hourly time steps (1,200 ticks) |
| Runs | 30 independent runs per scenario |
| Scenarios | Baseline (no behavior), uniform, synthesized |

---

## Citation

Citation information will be added after peer review.
