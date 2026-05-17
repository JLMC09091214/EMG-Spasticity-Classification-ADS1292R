# EMG Signal Acquisition and Classification for Lower Limb Spasticity Analysis using ADS1292R and ESP32

## Overview

This repository contains the complete development framework used for the acquisition, processing, visualization, feature extraction, and classification of surface electromyographic (\textbf{sEMG}) signals acquired from lower limb muscles using an \textbf{ADS1292R} analog front-end and an \textbf{ESP32} microcontroller.

The project was developed as part of a Master's degree research focused on the analysis and discrimination between healthy subjects and patients with spasticity through machine learning techniques and electromyographic signal processing.

The repository includes:

ESP32 acquisition firmware developed in Arduino IDE
MATLAB scripts for:
Real-time acquisition
Signal processing
FFT and Wavelet analysis
Feature extraction
Cross-validation analysis
LOSO (Leave-One-Subject-Out) validation
Automatic generation of figures and performance metrics
Hardware Description

## Hardware Description

The acquisition system was developed using:

ESP32 microcontroller
ADS1292R biopotential analog front-end
Surface EMG electrodes
Lower limb muscle acquisition setup

The signals analyzed correspond to:

Vastus Medialis
Rectus Femoris
Vastus Lateralis
Software Requirements
Arduino IDE

## Software Requirements

The acquisition firmware was developed using:

### Arduino IDE

ESP32 Board Package

Before compiling the firmware, install the ESP32 package from:

Tools → Board → Boards Manager → Search for "ESP32"

## MATLAB Requirements

The MATLAB codes were developed and tested using:

MATLAB
Signal Processing Toolbox
Statistics and Machine Learning Toolbox
Wavelet Toolbox

## Dataset Description

The database includes recordings from:

30 healthy subjects
10 sedentary
10 moderately active
10 highly active
7 subjects with different levels of spasticity

The acquisition conditions analyzed were:

REPOSO (Rest)
CISP (Isometric Contraction Without Weight)

The CICP condition was only evaluated in healthy subjects due to clinical safety considerations for patients with spasticity.

## Additional Dataset Information

This repository also includes a compressed file named:

`datads.rar`

The file contains example EMG recordings acquired from healthy subjects and patients with spasticity using the ADS1292R and ESP32 acquisition system.

Due to repository size limitations and research considerations, only a reduced subset of the original database is included. However, the provided folder structure and acquisition format allow researchers, students, and developers to continue expanding the dataset with their own EMG recordings and experimental sessions.

The purpose of sharing this structure is to encourage future research in:

* Lower limb electromyography
* Spasticity analysis
* Biomedical signal processing
* Machine learning for rehabilitation engineering
* Human movement analysis
* Neuroengineering applications

Researchers interested in this topic may continue collecting additional measurements and contribute toward the development of improved diagnostic and rehabilitation tools for patients with spasticity and other neuromuscular disorders.

All data included in this repository were anonymized for academic and research purposes.


## Code Description
### 1. read_EMG.m

This script performs the real-time acquisition and storage of EMG signals from the ESP32 through the serial COM port.

#### Important Configuration

Before running the script:

Configure the COM port according to the port detected by the computer.

Example:

COM = "COM5";
#### User Inputs

The script sequentially requests:

#### Subject Number

Example:

Enter subject number:

#### Muscle Selection

1 = Vastus Medialis
2 = Rectus Femoris
3 = Vastus Lateralis

#### Contraction Level

0 = REPOSO
1 = CISP
2 = CICP

#### Leg Selection

1 = Left Leg
2 = Right Leg

The acquired signals are automatically stored as .xlsx files.

### 2. EMG_ADS.m

This script processes the EMG recordings stored inside the datasets folder.

The code automatically:

Loads EMG recordings
Filters signals
Computes FFT
Computes Wavelet Transform
Generates EMG plots
Generates spectral analysis figures

Additionally, the script launches an interactive MATLAB interface that allows visualization of:

Filtered signal
Rectified signal
Signal envelope
Approximation coefficient Level 3
Detail coefficient Level 1
Detail coefficient Level 2
Detail coefficient Level 3
Discrete Wavelet Transform (DWT)

The extracted features are also consolidated into a combined table.

### 3. EMG_BASELINE_ADS1292R.m

This script performs machine learning analysis using:

Stratified 5-Fold Cross Validation

The code loads the database:

MATLAB_TABLA_COMBINADA_EMG_ADS1292R.xlsx

and generates:

Accuracy boxplots
ROC curves
Confusion matrices
Performance metrics

for:

Healthy subjects vs Spasticity
REPOSO condition
CISP condition

The evaluated classifiers include:

Logistic Regression
SVM
Random Forest
MLP
### 4. EMG_LOSO_ADS1292R.m

This script performs machine learning analysis using:

Leave-One-Subject-Out (LOSO) validation

The code automatically generates:

Accuracy boxplots
ROC curves
Confusion matrices
Statistical performance summaries

for:

Healthy subjects vs Spasticity
REPOSO condition
CISP condition

The evaluated classifiers include:

Logistic Regression
SVM
Random Forest
MLP

This validation methodology was selected because it provides a more realistic estimation of model generalization across unseen subjects.

## Research Objective

The primary objective of this work is to evaluate whether surface electromyographic signals acquired from lower limb muscles can discriminate between healthy individuals and patients with spasticity using signal processing and machine learning techniques.

The study specifically investigates:

Temporal EMG characteristics
Spectral behavior
Wavelet decomposition
Classification robustness
Subject-independent validation using LOSO

## Important Notes

The database included in this repository was anonymized for research purposes.
The CICP condition was not applied to spasticity patients due to safety considerations.
Some MATLAB scripts automatically generate folders and figures on the Desktop.

Author

José Luis Morales Colorado

Instituto Tecnologico de Morelia (ITM)

Mexico
