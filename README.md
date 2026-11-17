# Initializing Health Behaviors in Spatial Agent-Based Models of Disease Spread

Code and supporting data for evaluating how two approaches to initializing health behaviors (uniform assignment and joint-distribution population synthesis) influence demographic and spatial patterns of infection in a spatial agent-based model (ABM).

> **Note for reviewers:** This repository accompanies a manuscript under double-anonymized peer review. Author-identifying information has been omitted and will be added after review.

---

## Contents

1. [Overview](#1-overview)
2. [Repository structure](#2-repository-structure)
3. [Code and model components](#3-code-and-model-components)
4. [Data availability](#4-data-availability)
5. [Research workflow](#5-research-workflow)
6. [License](#6-license)
7. [Citation](#7-citation)

---

## 1. Overview

This repository supports a study examining how the method used to initialize vaccination behavior in a synthetic population influences simulated infectious disease outcomes in a spatial ABM.

Using Fairfax County and the City of Fairfax, Virginia, as a case study, two vaccination assignment approaches are compared:

- **Uniform assignment:** vaccination is randomly assigned to agents using a common probability, independent of demographic characteristics and location.
- **Synthesized assignment (joint-distribution population synthesis):** vaccination intention is carried over from individual-level health survey records during iterative proportional fitting (IPF)-based population synthesis, preserving relationships between vaccination, demographic characteristics, and geography.

Both approaches use the same synthetic population, including demographic characteristics, home census tracts, and mobility patterns. A baseline scenario without vaccination is included for comparison. Each scenario was run 30 times in the same spatial ABM.

The analyses examine:

- **Macro-level outcomes:** population-wide epidemic dynamics and the percentage of agents ever infected.
- **Meso-level demographic outcomes:** differences in infection across demographic groups.
- **Meso-level spatial outcomes:** census tract-level patterns of vaccination and infection.
- **External comparisons:** correspondence between simulated spatial patterns and observed COVID-19 vaccination uptake and case rates.

---

## 2. Repository structure

```
.
├── README.md
├── synthetic population/    # ACS processing, IPF population synthesis, vaccination assignment (R)
├── Mobility Assignment/     # NHTS trip-chain matching and activity schedules (R)
├── ABM/                     # Adapted spatial ABM and configuration (Python, Repast4Py)
└── ABM Outputs/             # Simulation outputs and analysis inputs used in the manuscript
```

---

## 3. Code and model components

### 3.1. Synthetic population generation

**Folder:** `synthetic population/` · **Language:** R

The population synthesis scripts are adapted from the IPF-based approach of Von Hoene et al. (2025) for generating synthetic populations with public health characteristics:

> Von Hoene, E. et al. (2025). Synthetic population generation with public health characteristics for spatial agent-based models. *PLOS Computational Biology*, 21(3), e1012439. https://doi.org/10.1371/journal.pcbi.1012439

For this study, the workflow was adapted to generate a synthetic population of adults aged 18 and older in Fairfax County and the City of Fairfax, using individual-level Understanding America Study (UAS) survey data and 2015–2019 American Community Survey (ACS) demographic constraints. The scripts:

1. Process ACS tables into categorical demographic constraints for IPF.
2. Run IPF-based population synthesis and integerize the results with the truncate–replicate–sample (TRS) method.
3. Assign vaccination uniformly.
4. Assign vaccination from survey-derived attributes (synthesized approach).

### 3.2. Mobility assignment

**Folder:** `Mobility Assignment/` · **Language:** R

Daily mobility is assigned from 2017 National Household Travel Survey (NHTS) trip chains. Each synthetic agent is matched to an NHTS respondent with the same age, sex, race/ethnicity, educational attainment, and household income. Assigned attributes include activity sequences, trip purposes, start times, and activity durations. Mobility is identical in the uniform and synthesized scenarios.

### 3.3. Spatial agent-based model

**Folder:** `ABM/` · **Language:** Python (Repast4Py)

The spatial ABM is adapted from the model developed by Atwal et al. (2026) to investigate how mobility assumptions shape contact networks and epidemic outcomes:

> Atwal, K.S. et al. (2026). Mobility and contact networks shape epidemic outcomes: A large-scale agent-based modeling study. *arXiv*. https://doi.org/10.48550/arXiv.2607.26217

For this study, the original ABM was adapted only to:

1. Incorporate the synthetic populations generated under the uniform and synthesized approaches, including their demographic and mobility attributes.
2. Represent vaccination as an agent-level protective behavior; vaccinated agents are fully protected from infection.

All other components, including agent movement, contact formation, and disease transmission, follow the original implementation. See Atwal et al. (2026) for details of the model design and mobility assumptions.

### 3.4. Simulation outputs

**Folder:** `ABM Outputs/`

- Per-tick epidemic summaries for each scenario.
- Run-level summary metrics, including the number and percentage of agents ever infected.
- Census tract-level vaccination and infection summaries.
- Logistic regression coefficients.
- Aggregate outputs used for the demographic and spatial analyses.
- Tract-level comparisons with observed vaccination and case data.

---

## 4. Data availability

### 4.1. Input data sources

| Dataset | Purpose | Availability |
|---|---|---|
| American Community Survey (ACS), 2015–2019 five-year estimates | Tract-level demographic constraints for population synthesis | Public ([census.gov](https://www.census.gov/programs-surveys/acs.html)); processed study-area marginals included |
| Understanding America Study (UAS), Survey 282, Wave 24 (2021) | Individual-level demographics and COVID-19 vaccination intention | Registered users only ([uasdata.usc.edu](https://uasdata.usc.edu/)); not redistributed |
| National Household Travel Survey (NHTS), 2017 | Trip chains and daily activity schedules | Public ([nhts.ornl.gov](https://nhts.ornl.gov/downloads)); processed inputs included |
| LEHD Origin-Destination Employment Statistics (LODES), 2019 | Home-to-work commuting flows | Public ([lehd.ces.census.gov](https://lehd.ces.census.gov/data/)) |
| Advan Weekly Patterns, 2019 | Destination assignment and visitation probabilities | Commercial license; not redistributed |
| Fairfax County building footprints, 2024 | Residential and workplace locations | Public ([Fairfax County GIS](https://data-fairfaxcountygis.opendata.arcgis.com/datasets/Fairfaxcountygis::buildings-1/about)) |
| Observed COVID-19 case rates, July 2021 | External comparison of simulated infection patterns | Fairfax County Government, from VEDSS records, via the [ARPA Recovery Index](https://www.arcgis.com/home/item.html?id=a6b56a242290435e9ec94cce172b0023) |

### 4.2. Materials included

- **Population synthesis:** processed 2015–2019 ACS marginals for the study area, ACS processing scripts, and adapted IPF and vaccination assignment scripts.
- **Mobility:** shareable processed NHTS trip-chain data and the matching and scheduling scripts.
- **Example synthetic population:** a population corresponding to the uniform vaccination scenario, containing home census tracts, NHTS trip-chain identifiers, mobility attributes, and uniformly assigned vaccination status. It shows the input structure expected by the ABM. Agent-level demographic characteristics are omitted because they were synthesized from UAS data.
- **Spatial ABM:** adapted Python/Repast4Py scripts, model configuration, and disease transmission parameters.
- **Simulation outputs:** see [Section 3.4](#34-simulation-outputs).

### 4.3. Materials not included

- **UAS survey data and the full synthesized population.** Individual-level UAS records are governed by the UAS data-use conditions and are not redistributed. UAS-specific preprocessing scripts and the full synthesized population (including agent-level demographic and vaccination attributes) are also excluded. Researchers with authorized UAS access can regenerate these inputs using the population synthesis workflow and the preprocessing steps described in the manuscript.
- **Advan data and other restricted ABM inputs.** Advan mobility data and certain inputs obtained from the original ABM developers are not redistributed and must be obtained from their providers.

As a result, running the complete population synthesis and ABM workflows requires datasets that are not included here.

---

## 5. Research workflow

**Step 1: Generate the synthetic population** (`synthetic population/`)
Fit UAS survey records to 2015–2019 ACS tract-level marginals with IPF, integerize with TRS, and assign vaccination using either uniform assignment or joint-distribution synthesis.

**Step 2: Assign mobility** (`Mobility Assignment/`)
Match agents to 2017 NHTS respondents by demographic characteristics and assign activity sequences, trip start times, and activity durations. Mobility is shared by both vaccination scenarios.

**Step 3: Run the spatial ABM** (`ABM/`)
Simulate disease spread under three scenarios, with 30 independent runs each and identical model structure and transmission parameters:

1. **Baseline:** no vaccination.
2. **Uniform:** vaccination assigned using a common probability.
3. **Synthesized:** vaccination assigned through joint-distribution population synthesis.

**Step 4: Analyze outcomes** (`ABM Outputs/`)
- Population-wide epidemic trajectories and cumulative infection.
- Demographic differences in the percentage of agents ever infected.
- Logistic regression of demographic associations with infection.
- Census tract-level vaccination and infection patterns, including spatial autocorrelation.
- Comparisons with observed COVID-19 vaccination uptake and case rates.


---

## 6. Citation

Citation information for the accompanying manuscript will be added after peer review. Please also cite the original population synthesis method (Von Hoene et al., 2025) and spatial ABM (Atwal et al., 2026) listed in [Section 3](#3-code-and-model-components).
