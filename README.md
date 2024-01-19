# InVivoKinetics

**Disclaimer:** This repository is currently private and for development purposes only. Please do not distribute.

## Overview

InVivoKinetics is a data analysis tool designed for Single Molecule Localisation Microscopy (SMLM) data collected *in vivo*. The system applies modern machine learning techniques, diffusion analysis, and classical statistics to rapidly and accurately extract detailed insights into diffusion, transport, and fundamental biological processes at the single molecule level. The system is flexible and agnostic to the problem studied, instead relying on the end user having biological insight into the problem, requiring them to identify features in the data which are predictive of the molecular processes being investigated. As a consequence the tool can be applied to a wide range of fundamental problems in biology involving single molecule tracking data *in vivo*. The tool also provides publication-ready visualisations of data and statistics to gain insight into the underlying process.

## Features

- **Manual trajectory labelling:** The tool enables the user to rapidly apply manual labels to source data for model training; these labels are arbitrary in nature and designated by the user at runtime. The models learn their behaviour together with their spatial and temporal context without making assumptions about the problem under study. To aid labelling, the user is provided with visual representations of the spatial information of the trajectory, its key features, the segmented cell boundary, and an automatically constructed video illustration of the molecule synchronised with the steps being viewed; the user simply provides labels of the behaviour they observe using the GUI.
- **Feature extraction and engineering:** The tool automatically constructs a wide range of features mined from localisation, tracking, and segmentation data, while further predictive features are constructed through feature engineering and extraction of metadata.
- **Machine Learning models:** InVivoKinetics offers a wide range of machine learning models for sequence-to-sequence classification and automated trajectory segmentation, allowing for rapid labelling approximately four orders of magnitude faster than manual curation.
- **Data Insights:** Users can gain detailed insights into their data, including diffusion analysis, on/off rates, performance statistics, and residence times, among others.
- **Transition Analysis:** The tool provides functionalities for identifying, aggregating, and aligning transition events, constructing transition matrices, generating publication-quality transition diagrams, and extracting statistics of transitions between different states.
- **Visualisation:** InVivoKinetics offers automatic video extraction and curation at the press of a button; cropping molecule examples with brightfield overlays, and generation of graphical global state transition statistics.
- **Interaction with other systems:** Data can be exported in standardised formats for use with external software, enabling labelled datasets to be analysed using alternative software and ML frameworks such as TensorFlow and PyTorch, and also enables data to be collated and visualised using popular software packages such as Origin.

## Development History

InVivoKinetics was developed in 2020 during the COVID-19 pandemic by Oliver Pambos. Since then, it has received updates and improvements to enhance its functionality and usability.

## Prerequisites

Minimum recommended specifications for the current version are as follows,
- MATLAB (R2023b or later recommended)
- macOS Monterey (12.6) or later; Windows 10 (version 21H2 or later); Ubuntu 20.04 / 22.04 LTS or later

## Source data

The following source data is required for use of this tool; generalisation of the input format to popular standards will be performed prior to public release.
- Video data (temporarily restricted to the FITS format possessing metadata from Andor Solis during development)
- SMLM tracking data assigned to segmented microbeTracker meshes (temporarily restricted to the internal LoColi format during development)

## Installation

1. **Download the Codebase**: Obtain the InVivoKinetics codebase either by cloning this repository or acquiring it from the source.

2. **Add Code Directory to MATLAB Path**: To ensure that MATLAB can locate and execute the necessary files, add the directory containing the InVivoKinetics code to your MATLAB path. You can do this either by selecting `Set Path` from the MATLAB `Home` tab, then select the directory containing the code; or alternatively by running the following command within MATLAB, replacing `[path_to_code]` with the actual path to the directory:

```matlab
addpath('[path_to_code]')
```

## License and Usage Restrictions

**Important:** This repository, InVivoKinetics, is currently private and intended for development purposes only. It may not be distributed or used without consent from the author until an official public release is made. Usage is subject to the license agreement presented when launching the GUI.

When using InVivoKinetics, users are required to agree to the Terms of Service (ToS) provided within the application window upon launch. Please review and accept the ToS before using the software. Until the public release, access to this repository and its contents is granted only to those with special permissions from the author, Oliver Pambos, for specific projects.

For inquiries or permissions, please contact oliver.pambos@physics.ox.ac.uk

## Contact

Dr Oliver Pambos
Department of Physics
University of Oxford
OX1 3PU
oliver.pambos@physics.ox.ac.uk
https://github.com/opambos

Stay tuned for updates and the official public release.