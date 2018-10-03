# OnCore2REDCap
Perl code from a project for the UCSF HDFCCC
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
