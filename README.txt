# ERG-Wavelet-OP
 
Energy-calibrated continuous wavelet transform (CWT, real Morlet) and
short-time Fourier transform (STFT) analysis of electroretinogram (ERG)
oscillatory potentials (OPs), with a ground-truth synthetic validation
framework. Companion code for Rosin et al. (2026), *TVST* (citation in
`CITATION.cff`).
 
**License: University of Pittsburgh Academic Use EULA (`LICENSE.txt` / `Academic_Use_EULA.docx`). Non-commercial, educational and research use only; no redistribution or derivative works; publications using these materials must cite the reference in `CITATION.cff` (EULA §4). Commercial licensing: University of Pittsburgh Innovation Institute. Not a medical device; not for clinical decision-making.**
 
## Contents
- `pipeline/` — MATLAB analysis
  - `CreateCWTFigure6.m` — wavelet composite + energy-calibrated wavelet PSD
    (real Morlet, sharp IIR notch Q = 35, zero-phase filtering)
  - `CreateFFTFigure3.m` — STFT composite + PSD (matching preprocessing)
  - `CalibrateWaveletPSD.m`, `CrossCheckParseval.m` — Parseval calibration + verification
  - `RunOPAnalysisOnAllDataInFolder.m`, `RunFFTAnalysisOnAllDataInFolder.m` —
    interactive batch drivers (per-cohort folders → .xls + figures)
  - `RunAutomatedOPAnalysis.m`, `RunAutomatedFFTAnalysis.m` — per-recording drivers
  - `ConvertAlkiesERGFile2.m` — ERG-system output file reader
  - `BuildMasterTable.m`, `PoolMasterTable.m`, `RunAllCohorts.m` — aggregation
  - `getWaveletScales.m` — single source of truth for the scale grids
    (512 log-spaced scales; ~4–324 Hz at 1000 Hz, ~1.6–1290 Hz at 2000 Hz)
  - `getWaveletPSDConstant.m` — grid-keyed cached calibration constant K
- `synthetic_validation/` — ground-truth validation
  - `GenerateSyntheticValidation.m` — AR cohort-noise surrogates + Gabor
    bursts (single-burst Family A; paired-burst Family B), fixed seeds
  - `GenerateSNRSweep.m` — fixed-rate (1000 Hz) SNR series, fixed seeds
  - `SyntheticNoiseParameters.mat` — per-cohort noise-model parameters
    (AR coefficients, noise SD, filtered-noise RMS, OP amplitude, epoch
    definition). Both generators accept this file in place of the
    reference recordings, so the full synthetic dataset can be
    regenerated without access to any recorded data:
    `GenerateSyntheticValidation('SyntheticNoiseParameters.mat', out)`
- `docs/` — pipeline overview and usage
 
## Requirements
MATLAB R2026a (Signal Processing Toolbox, Wavelet Toolbox). The package is
MATLAB only, including the synthetic-signal generators.
 
## Quick start
1. After cloning, add the package to the MATLAB path:
   `addpath(genpath('erg-wavelet-op'))` (or the folder you cloned into).
2. Place per-subject recordings as tab-delimited `[time_ms, value_nV]` text
   files in the expected folder structure (see `docs/PIPELINE.txt`).
3. Run the batch driver on a cohort folder; per-recording spectral results
   (`.xls`) and figures are written alongside the data.
4. `BuildMasterTable` aggregates cohorts; `PoolMasterTable` produces analysis
   vectors.
5. To reproduce the validation: run `GenerateSyntheticValidation`, then
   process the generated folders with the same batch driver.
 
## Data availability
No patient or animal recordings are distributed with this repository.
The synthetic validation dataset can be regenerated exactly from the
included generators and `SyntheticNoiseParameters.mat` (fixed seeds); the
parameter file contains only aggregate noise-model parameters and no
recorded data.
