# health-behavior-initialization-abm

Code and data for comparing uniform assignment and relationship-preserving population synthesis for initializing health behaviors in a spatial agent-based model (ABM) of COVID-19.

> **Note for reviewers:** This repository has been anonymized for double-anonymized peer review. Author information will be added after review.

---

## Overview

This repository accompanies a study that examines how the method used to initialize a health behavior (COVID-19 vaccination intention) in a synthetic population affects the outputs of a spatial ABM. Two approaches are compared using the same synthetic population, mobility patterns, and disease model, differing only in how vaccination is assigned:

- **Uniform assignment** – every agent has the same probability of being vaccinated, independent of demographic attributes and location.
- **Synthesized assignment (relationship-preserving population synthesis)** – vaccination is assigned jointly with demographic attributes and geography by fitting individual survey records to census tract-level demographic constraints using iterative proportional fitting (IPF).

A baseline scenario with no vaccination is also included. Outcomes are compared at the macro level (epidemic trajectory) and meso level (infection by demographic group and census tract).

| | |
|---|---|
| Study area | Fairfax County and the City of Fairfax, Virginia (261 census tracts) |
| Agents | 893,834 adults aged 18+ |
| Simulation length | 50 days at hourly time steps (1,200 ticks) |
| Runs | 30 independent runs per scenario |
| Scenarios | Baseline (no behavior), uniform, synthesized |

---

## Repository structure

```
.
├── README.md
├── LICENSE
├── environment.yml              # software environment
├── config/                      # parameters and random seeds for each scenario
│   ├── baseline.yaml
│   ├── uniform.yaml
│   └── synthesized.yaml
├── src/
│   ├── 01_population_synthesis/ # IPF and vaccination assignment
│   ├── 02_mobility/             # NHTS trip chain assignment
│   ├── 03_abm/                  # agent-based model
│   └── 04_analysis/             # regressions, Wald tests, tract statistics, fit
├── figures/                     # one script per manuscript figure
├── tables/                      # one script per manuscript and supplementary table
├── data/
│   ├── README.md                # how to obtain each input dataset
│   ├── public/                  # publicly available inputs
│   └── restricted/              # empty; restricted data are not distributed
└── outputs/                     # model outputs used in the paper
```

---

## Requirements

- [TODO: language and version, e.g. Python 3.11]
- [TODO: ABM platform, if applicable]
- Package versions are listed in `environment.yml`.

To create the environment:

```bash
conda env create -f environment.yml
conda activate behavior-abm
```

[TODO: adjust if using pip/requirements.txt or another platform.]

**Hardware and run time:** [TODO: e.g. one model run takes approximately X hours on Y; all 90 runs take approximately Z.]

---

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

```bash
[TODO: command]
```

Fits UAS 282 records to ACS tract-level marginals (sex, race/ethnicity, age, education, household income) using IPF, and assigns vaccination under the uniform and synthesized approaches.

### 2. Assign mobility

```bash
[TODO: command]
```

Matches each agent to an NHTS trip chain based on demographic characteristics and assigns home, work, and school locations.

### 3. Run the ABM

```bash
[TODO: command for running all scenarios]
```

Runs 30 independent runs for each scenario using the parameters and seeds in `config/`. [TODO: note where outputs are written.]

### 4. Analysis, figures, and tables

```bash
[TODO: command]
```

Computes the IPF fit statistics, logistic regressions and Wald z-tests, tract-level statistics, and comparisons with observed data, and writes all figures and tables.

---

## Figures and tables

| Item | Description | Script |
|---|---|---|
| Figure 1 | Framework of behavior initialization approaches | `figures/[TODO]` |
| Figure 2 | [TODO] | `figures/[TODO]` |
| Figure 3 | [TODO] | `figures/[TODO]` |
| Figure 4 | Epidemic curves by scenario | `figures/[TODO]` |
| … | … | … |
| Table 1 | [TODO] | `tables/[TODO]` |
| Table S1 | UAS survey sample characteristics | `tables/[TODO]` |
| Table S2 | ACS tract-level summary statistics | `tables/[TODO]` |
| Table S3 | Synthetic population composition and vaccination | `tables/[TODO]` |
| Table S4 | Mobility characteristics | `tables/[TODO]` |
| Table S5 | Goodness of fit to ACS and observed vaccination | `tables/[TODO]` |
| Table S6 | Epidemic summary metrics | `tables/[TODO]` |
| Table S7 | Vaccination logistic regression | `tables/[TODO]` |
| Table S8 | Infection by demographic group | `tables/[TODO]` |
| Table S9 | Infection logistic regression and Wald tests | `tables/[TODO]` |
| Table S10 | Tract-level vaccination | `tables/[TODO]` |
| Table S11 | Tract-level infection | `tables/[TODO]` |

---

## Model description

[TODO: link to the ODD protocol if included, e.g. `docs/ODD.md`.]

Key features:

- Agents move among home, work, school, and activity locations at hourly time steps according to their assigned trip chains.
- When *n* agents are present at a location, each agent interacts with up to log₂(*n*) others, rounded to the nearest integer.
- Transmission probability is 0.10 per contact per time step.
- Vaccinated agents are fully protected from infection.
- [TODO: number of initially infected agents, disease states and durations.]

---

## License

Code is released under the [TODO: e.g. MIT License]. Model outputs in `outputs/` are released under [TODO: e.g. CC BY 4.0]. Input data remain subject to the terms of their original providers.

## Citation

Citation information will be added after peer review.
