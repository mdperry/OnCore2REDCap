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

WCDT clinical database version 4-6-2018 - additional data points for Marc Perry.xlsx 

which was transformed into: 
wcdt_clinical_additional_data.tsv
### Pre-processing: Data Cleaning Issues for the OnCore Tables
My basic workflow (based on my previous bioinformatic Data Wrangling experience) was to:
1. Open each Excel file using the OpenOffice/LibreOffice Calc Spreadsheet program (this is personal preference, you could probably use any similar program)
2. Export (or Save As . . . ) the main table as a TSV file
3. Create a master list of patient_ids, (based on the Demographics table) in the OnCore tables this is always column 1, and is named 'SEQUENCE_NO_'
4. For each table I would remove all records (or rows, or tuples) that lacked a valid identifier in the first column (because there is no way to link that data to a patient record)
5. I Did a rigourous QA/QC check to make sure that
   * There were no "extra" patient_ids in the other tables (i.e. patient_ids that were _missing_ from the Demographics table), if I found any then I would query the data providers for clarification/correction
   * I compiled a list of patient_ids that were **LACKING** records in the other tables (mainly for planning the logic of the parsing and processing code).
 6. In general, the first ~ 13 columns in each of the OnCore tables are named and ordered in the same pattern, and contain what might be called high-level metadata for the project.  One of these columns is named 'Not Applicable or Missing'.  In general, my Perl code logic skips processing any records with an entry in this field, but in the second iteration of coding, I typically flagged any such patient_ids at this pre-processing step and either reviewed that record manually, or queried the data providers to confirm my understanding
 7. After converting each table into a TSV I would use CLI tools to count the number of records and number of columns in that table, to confirm that all of the rows were the same length.  This is important because some of the fields in some of the tables can contain free-text entries, and in some cases the CRAs have cut blocks of text from some other spreadsheet program and pasted them verbatim into OnCore.  After being exported from OnCore these offending fields may have all manner of extra carriage returns, linefeeds, newlines, etc. etc.  Most of the tables were "clean" and behaved as expected.  A couple had a small number of lines with fields I cleaned up manually, but one table, named GU Disease Assessment, had dozens, if not scores, of records where one specific column had been mangled by saving as a TSV.  Initially I attempted to manually clean up the offending fields in this table, but eventually grew so frustrated that I derived a search and replace step in Calc that cleaned all of these up.  Typically, I would replace the unwanted characters with a single blank space, or in some cases a vertical pipe symbol like this ```|```.
   
   
   
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
