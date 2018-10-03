# OnCore2REDCap
## Summary Description
Perl code from a project for the UCSF HDFCCC
## Overview

## Background
## List of Dumped OnCore Tables provided as MS-Excel Spreadsheets
Archive:  125519-StudyData-04-10-2018.zip

|OnCore Name | Cleaned, Filtered, Formatted for Input to Perl Script Name|
|-------------|--------------|
|Demographics.xlsx | demographics_filtered.tsv|
|Blood Labs V2.xlsx | blood_labs_v2_new_filtered.tsv|
|ECOG-Weight V3.xlsx | patient_ECOG_scale_performance_status_and_weight_new_filtered.tsv|
|Followup.xlsx | Not used|
|GU-Disease Assessment V3.xlsx | gu_disease_assessment_new_v3_filtered.tsv|
|Past Tissue V1.xlsx | Not used|
|Prostate Diagnosis V4.xlsx | prostate_diagnosis_v4_new_filtered.tsv|
|SU2C Biopsy V3.xlsx | su2c_biopsy_v3_new_filtered.tsv|
|SU2C Pr Ca Tx Sumry V2.xlsx | su2c_pr_ca_tx_sumry_v2_new_filtered.tsv|
|SU2C Prior TX V3.xlsx | su2c_prior_tx_v3_new_filtered.tsv|
|SU2C Specimen V1.xlsx | Not used|
|SU2C Subsequent Treatment V1.xlsx | su2c_subsequent_treatment_v1_new_filtered.tsv|
|SU2C Tissue Report V1.xlsx | Not used |

This additional Input File was being manually curated and maintained separately from any Project Databases and was provided manually after the code for parsing and processing the files above was at the Beta Testing stage:
WCDT clinical database version 4-6-2018 - additional data points for Marc Perry.xlsx which was transformed into: 
wcdt_clinical_additional_data.tsv
### Data Cleaning Issues for the OnCore Tables

## Major Concepts



### The OnCore Demographics Table contains the master list of Patient IDs

### Most (but not all) Patients have at least one (1) Biopsy (i.e. a Baseline Biopsy)

### Some Patients have a Progression Event
#### A minority of patients have gt 1 Progression Event

#### Select Patients had a second Biopsy Procedure from one (or more) metastatic sites; by definition, this is a "Progression Biopsy"

#### Virtually every patient with a Baseline Biopsy sample/specimen received subsequent treatment, post-bx-tx, and each treatment *could* have a ProgressionDate; these **ALSO** define Progression Events
This is a Perl script and several associated modules that parses a specific collection of TSV files and then
generates a monolithic TSV table that is almost ready to uploaded/imported into a REDCap project (if the REDCap project
has the correct matching Data Dictionary).

Since REDCap *ONLY* accepts CSV files you will need to convert this TSV into a CSV prior to importing it into your REDCap
project.  However, some of the data fields that you migrated from OnCore may contain commas, therefore the first step
that I execute after saving the STDOUT from the clean_and_parse_oncore.pl is this:

```perl -pe 's/,/\|/g' monolithic_table.tsv > monolithic_table_WITH_NO_COMMAS.tsv```

Followed by:

```perl -pe 's/\t/,/g' monolithic_table_WITH_NO_COMMAS.tsv > monolithic_table_WITH_NO_COMMAS.csv```

You will not be able to run this script without the matching OnCore TSV input files (which are not available in this 
GitHub repository).  For reasons of convenience, the names of the input files are hard-coded in the body of the script
itself, and the script expects to be in a directory one level beneath where the tables are stored.  If you use a
a different directory structure, or a different set of files, then you will need to edit this section of the script.

The OnCore tables were obtained as a data dump into MS-Excel
