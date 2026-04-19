# DeepTRACE
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18869232.svg)](https://doi.org/10.5281/zenodo.18869232)

DeepTRACE is the software accompanying Pambos, O.J., Wright, J.A.R. & Kapanidis, A.N., **"DeepTRACE brings flexible machine learning to single-molecule track analysis"**. Commun Biol (2026). [https://doi.org/10.1038/s42003-026-09899-y](https://doi.org/10.1038/s42003-026-09899-y)

This repository hosts the actively maintained DeepTRACE codebase.

DeepTRACE is a tool for analysing long single-molecule tracking data in living cells using machine learning. It is designed for experiments that capture multi-stage biological processes by learning patterns of molecular behaviour from motion, subcellular location, and photometric readouts. Users can annotate tracks, construct bespoke models, segment molecular behaviours, and perform quantitative analysis to assist biological interpretation of single-molecule tracking data. Models can be trained on datasets containing a few hundred tracks without specialised hardware. DeepTRACE accepts arbitrary numerical readouts as input, enabling native handling of emerging single-molecule photometric techniques (e.g. smFRET, anisotropy).

---

## Installation
### Requirements
- MATLAB R2024a or later (tested on R2025a), with the following toolboxes:
	- Optimisation Toolbox
	- Signal Processing Toolbox
	- Deep Learning Toolbox
	- Image Processing Toolbox
	- Statistics and Machine Learning Toolbox
	- Bioinformatics Toolbox
- macOS, Windows, or Linux.
- For optimal performance during manual annotation, datasets should be stored on a fast internal SSD.

---

### Setup Method 1: Manual Download
If you do not use Git, the following steps will set up DeepTRACE on your system:

1. Download the code as a zip file from the `[<> Code]` button at the top of the repo's GitHub web page, and unzip on your local machine.
2. At the MATLAB Command Window enter:
```matlab
addpath(genpath('path_to_unzipped_DeepTRACE'))
savepath
```
3. Launch DeepTRACE by typing `DeepTRACE` in the Command Window.

On some systems the `savepath` command requires administrator access. If so, an alternative to step 2 above is to add the `addpath(genpath('path_to_unzipped_DeepTRACE'))` command to the `startup.m` file so that the DeepTRACE path is configured automatically each time MATLAB starts.

---

### Setup Method 2: Using Git
If you already use Git:

1. Clone this repository:
```bash
git clone https://github.com/opambos/DeepTRACE.git
```
2. In the MATLAB Command Window enter the following to add the repository folder to your MATLAB path:
```matlab
addpath(genpath('path_to_DeepTRACE'))
savepath
```
3. Launch DeepTRACE by typing `DeepTRACE` in the MATLAB Command Window.

On some systems the `savepath` command requires administrator access. If so, an alternative to step 2 above is to add the `addpath(genpath('path_to_DeepTRACE'))` command to the `startup.m` file so that the DeepTRACE path is configured automatically each time MATLAB starts.

---

## Input Formats
DeepTRACE requires the following input files:
- Tracking data (TrackMate or LoColi formats) or Localisation data (Picasso format)
- Cell segmentations (MicrobeTracker format)
- Fluorescence video recordings (.tif or .fits)
- Reference image (.tif or .fits)
- Optional: ground truth data for training on simulated data (.csv)

Support for additional localisation and tracking pipelines is under active development. If you use a different pipeline, please contact us via the email address provided below.
DeepTRACE is under continuous development, with additional analytical modules and input formats added periodically.

---

## Core Workflow
1. Data input.
2. Feature engineering to describe molecular behaviour (e.g. *step size*, *distance to cell membrane*).
3. Annotation of single-molecule tracks using natural language labels (with either human annotation or simulated ground truth).
4. Users select features guided by their knowledge of the biological process being studied.
5. A bespoke model is trained for the task at hand.
6. Automated segmentation of unseen tracks.
7. Downstream quantitative analysis of segmented states.
8. Discovery of additional feature-class relationships present in the dataset beyond those used for training.

A more detailed description of the DeepTRACE workflow is provided in the publication.

---

## Analysis Tools
DeepTRACE contains a comprehensive suite of quantitative and visual analysis tools directly within the platform to support feature selection and biological interpretation of results.
  
Core capabilities include:
- Quantitative summaries and visualisation
- Feature interpretability and selection tools
- Diffusion modelling and MSD analysis
- Temporal event alignment and transition dynamics
- Spatial mapping onto cellular geometries
- Interactive track-level inspection and visual exploration

Specific tools available directly within the GUI:
### Dataset overview
- Descriptive statistics
- Track gallery overview, with reference overlays, coloured by feature, time, or class
- Track length and molecule arrival time histograms
- Global feature distributions

### Guiding feature selection
DeepTRACE provides visual and quantitative tools to guide feature selection:
- Class-dependent feature distribution visualisations
- Permutation importance
- Feature-class mutual information ranking
- Pairwise feature correlation and mutual information analysis
- Class separability metrics (e.g. Kolmogorov-Smirnov statistic, 1st order Wasserstein distance)

### Diffusion analysis
DeepTRACE computes diffusion analysis on complete tracks, or subtracks segmented by class:
- Diffusion coefficient estimation
- Diffusion histograms with functional model fitting
- MSD-lag time analysis

### Temporal analysis
- Event Aligner: temporal evolution of features through changepoints
- State residence time distributions
- Transition matrix visualisation

### Spatial mapping onto cellular geometries
- 2D heatmaps and rendered reconstructions
- Class-specific projections onto major and minor cell axes

### Track inspection
- Track Viewer (feature-time series inspection)
- Feature-, class-, or time-coloured track visualisation
- Automated track video illustration
- Step angle analysis

---

## Export Formats
DeepTRACE supports export of analytical results and visualisations in multiple formats:
- Histogram data (.csv)
- Figures (.fig; vectorised graphics via clipboard)
- Single track feature time series (.csv)
- Analysis notes written by user within the app (.tex, .pdf, .rtf, .txt, .md, .html)
- Models (.mat)
- Descriptive statistics, model outputs, and status updates (plain text via clipboard)
- Videos of track illustrations (.gif)

---

## How to Cite
To cite DeepTRACE, the following preprint should be used

Pambos, O.J., Wright, J.A.R. & Kapanidis, A.N., **DeepTRACE brings flexible machine learning to single-molecule track analysis.** (2026). [https://doi.org/10.1038/s42003-026-09899-y](https://doi.org/10.1038/s42003-026-09899-y)

---

## Contact and Support
For questions, bug reports, or input format requests, please contact: oliver.pambos@physics.ox.ac.uk

DeepTRACE is actively used across multiple laboratories. Feedback, bug reports, and requests for additional input formats are welcome.

---

## Origin
DeepTRACE was conceived and developed by Oliver Pambos (Department of Physics, University of Oxford).
