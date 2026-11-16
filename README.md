
# Initializing Health Behaviors in Spatial Agent-Based Models of Disease Spread

Code and supporting data for evaluating how uniform assignment and joint-distribution population synthesis approaches to initializing health behaviors influence demographic and spatial patterns of infection in spatial agent-based models (ABMs).

> **Note for reviewers:** This repository accompanies a manuscript submitted for double-anonymized peer review. Author-identifying information has been omitted and will be added following peer review.

---

## 1. Overview

This repository supports a study examining how different approaches to initializing vaccination behavior in synthetic populations influence simulated infectious disease outcomes in a spatial ABM.

Using Fairfax County and the City of Fairfax, Virginia, as a case study, two approaches to vaccination assignment are compared:

- **Uniform assignment:** Vaccination is randomly assigned to agents using a common probability, independent of demographic characteristics and geographic location.
- **Synthesized assignment (joint-distribution population synthesis):** Vaccination behavior is transferred from individual-level health survey records during an iterative proportional fitting (IPF)-based population synthesis process, preserving relationships between vaccination intention, demographic characteristics, and geography.

Both approaches use the same underlying synthetic population, including demographic characteristics, home census tract locations, and assigned mobility patterns. A baseline scenario without vaccination is also included for comparison.

The resulting populations are incorporated into the same spatial ABM of infectious disease spread, with 30 independent simulation runs conducted for each scenario.

The analyses examine:

- **Macrolevel outcomes:** Population-wide epidemic dynamics and the percentage of agents ever infected.
- **Mesolevel demographic outcomes:** Differences in infection across demographic subgroups.
- **Mesolevel spatial outcomes:** Census tract-level distributions of vaccination and simulated infection.
- **External comparisons:** Correspondence between simulated spatial patterns and observed COVID-19 vaccination uptake and case rates.

---

## 2. Code and Model Components

### 2.1. Synthetic Population Generation

**Programming language:** R

The population synthesis scripts are adapted from the IPF-based approach developed by Von Hoene et al. (2025) for generating synthetic populations with public health characteristics.

**Reference:**

Von Hoene, E. et al. (2025). Synthetic population generation with public health characteristics for spatial agent-based models. *PLOS Computational Biology*, 21(3), e1012439. https://doi.org/10.1371/journal.pcbi.1012439

For the present study, the population synthesis workflow was adapted to generate a synthetic population of adults aged 18 years and older in Fairfax County and the City of Fairfax, using individual-level Understanding America Study (UAS) survey data and 2015–2019 American Community Survey (ACS) demographic constraints.

The adapted R scripts implement:

1. Processing of ACS demographic marginals into categorical constraints for IPF.
2. IPF-based population synthesis and integerization using the truncate–replicate–sample (TRS) method.
3. Uniform vaccination assignment.
4. Synthesized vaccination assignment based on survey-derived attributes.

Due to restrictions associated with the UAS data, the original survey records and UAS-specific preprocessing scripts are not included in this repository.

### 2.2. Mobility Assignment

**Programming language:** R

Mobility behavior was assigned to the synthetic population using trip chains derived from the 2017 National Household Travel Survey (NHTS).

The mobility assignment scripts match synthetic agents to NHTS respondents based on demographic characteristics, including age, sex, race/ethnicity, educational attainment, and household income.

The assigned mobility attributes include activity sequences, trip purposes, start times, and activity durations.

These mobility patterns were held constant between the uniform and synthesized vaccination assignment scenarios.

### 2.3. Spatial Agent-Based Model

**Programming language:** Python (Repast4Py)

The spatial ABM used in this study was adapted from the model developed by Atwal et al. (2026) to investigate how mobility assumptions influence contact networks and epidemic outcomes.

**Reference:**

Atwal, K.S. et al. (2026). Mobility and Contact Networks Shape Epidemic Outcomes: A Large-Scale Agent-Based Modeling Study. *arXiv*. https://doi.org/10.48550/arXiv.2607.26217

The original ABM was adapted for the present study to:

1. Incorporate the synthetic populations generated under the uniform and synthesized vaccination assignment approaches, including their demographic and mobility attributes.
2. Implement vaccination as an agent-level protective behavior that modifies susceptibility to infection.

All other model components, including agent mobility, contact formation, and disease transmission processes, follow the original implementation.

The updated ABM scripts are included in this repository. Some model input datasets were obtained from the developers of the original ABM and are not redistributed here.

Readers interested in the underlying model architecture and mobility assumptions should refer to Atwal et al. (2026).

---

## 3. Data Availability

### 3.1. Input Data Sources

| Dataset | Purpose | Availability |
|---|---|---|
| American Community Survey (ACS), 2015–2019 five-year estimates | Census tract-level demographic constraints for population synthesis | Public; processed study-area marginals included |
| Understanding America Study (UAS), Survey 282, Wave 24 (2021) | Individual-level demographic characteristics and COVID-19 vaccination intention | Access through [UAS](https://uasdata.usc.edu/); not redistributed |
| National Household Travel Survey (NHTS), 2017 | Individual-level trip chains and daily activity schedules | Public source; processed inputs included subject to applicable terms |
| LEHD Origin-Destination Employment Statistics (LODES), 2019 | Home-to-work commuting flows | Public source |
| Advan Weekly Patterns, 2019 | Destination assignment and visitation probabilities | Restricted; not redistributed |
| Fairfax County building footprints, 2024 | Residential and workplace locations | Public source |
| Observed COVID-19 vaccination data, December 2021 | External comparison of census tract-level vaccination patterns | Obtained from the Virginia Department of Health; redistribution subject to authorization |
| Observed COVID-19 case data, July 2021 | External comparison of simulated spatial infection patterns | Sourced from Fairfax County Government using VEDSS records; redistribution subject to source terms |

### 3.2. Materials Included in This Repository

#### Population Synthesis Inputs and Code

- Processed 2015–2019 ACS demographic marginals for the study area.
- R scripts for processing ACS data into categorical demographic constraints required for IPF.
- Adapted R scripts implementing IPF-based population synthesis and vaccination assignment.

#### Mobility Inputs and Code

- Shareable processed NHTS trip-chain data used for mobility assignment.
- R scripts for matching NHTS trip chains to synthetic agents and assigning activity schedules.

#### Example Synthetic Population

Subject to confirmation of redistribution permissions, an example synthetic population corresponding to the uniform vaccination assignment scenario is provided.

The dataset contains:

- Agent-level demographic characteristics.
- Home census tract identifiers.
- Assigned NHTS trip-chain identifiers.
- Mobility attributes.
- Uniformly assigned vaccination status.

This dataset demonstrates the expected input structure for the spatial ABM.

#### Spatial ABM

- Adapted Python/Repast4Py scripts for implementing the vaccination scenarios.
- Model configuration and disease transmission parameters.

#### Simulation Outputs and Analysis

Where redistribution is permitted, supporting outputs include:

- Per-tick epidemic summaries for each simulation scenario.
- Run-level summary metrics, including the number and percentage of agents ever infected.
- Census tract-level vaccination and infection summaries.
- Logistic regression coefficients.
- Aggregate outputs used for demographic and spatial analyses.
- Tract-level comparisons with observed vaccination and case data.

### 3.3. Materials Not Included

#### UAS Survey Data and Derived Synthetic Population

Individual-level UAS survey records are not redistributed because access is governed by the UAS data-use conditions.

UAS-specific preprocessing scripts are also excluded from this repository.

The full synthesized population generated using UAS survey data, including its corresponding agent-level demographic and vaccination attributes, is not provided because of restrictions associated with the source survey data.

Researchers with authorized access to the UAS data may use the population synthesis workflow to regenerate the required inputs, subject to the data provider's terms and the preprocessing requirements described in the accompanying manuscript.

#### Other Restricted Model Inputs

Advan mobility data and certain inputs obtained from the original ABM developers are not redistributed.

Access to these datasets must be obtained separately from their respective providers or authorized sources.

Consequently, the complete population synthesis and spatial ABM workflows may require additional datasets that are not included in this repository.

---

## 4. Research Workflow

The study consists of four main stages.

### Step 1. Generate the Synthetic Population

Generate a synthetic population for Fairfax County and the City of Fairfax using individual-level UAS survey records and census tract-level demographic constraints from the 2015–2019 ACS.

The IPF-based process fits demographic characteristics to ACS marginals and generates agent-level records using the truncate–replicate–sample (TRS) integerization procedure.

Vaccination is initialized using either uniform assignment or joint-distribution synthesis.

### Step 2. Assign Mobility Behavior

Assign daily activity schedules from the 2017 NHTS to synthetic agents using demographic matching.

Agents receive trip chains describing:

- Activity sequences and purposes.
- Trip start times.
- Activity durations.

These mobility characteristics are shared between the uniform and synthesized vaccination assignment scenarios.

### Step 3. Execute the Spatial ABM

Incorporate the synthetic populations and mobility attributes into the spatial ABM implemented in Repast4Py.

Simulate infectious disease spread under three scenarios:

1. **Baseline:** No vaccination behavior.
2. **Uniform:** Vaccination assigned using a common probability.
3. **Synthesized:** Vaccination assigned through joint-distribution population synthesis.

Conduct 30 independent stochastic model runs per scenario using the same model structure and disease transmission parameters.

### Step 4. Analyze Simulation Outcomes

Evaluate simulation outcomes at the population, demographic, and geographic levels.

The analyses include:

- Population-wide epidemic trajectories and cumulative infection outcomes.
- Demographic differences in the percentage of agents ever infected.
- Logistic regression analyses of demographic associations with infection.
- Census tract-level vaccination and infection patterns.
- Spatial autocorrelation and relationships between vaccination and infection.
- External comparisons with observed COVID-19 vaccination uptake and case rates.

---

## 6. Citation

Citation information for the accompanying manuscript will be added following peer review.

The original population synthesis methodology and spatial ABM should be cited using the references provided in Section 2.
