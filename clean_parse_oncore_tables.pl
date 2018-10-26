#!/usr/bin/perl
#
# File: clean_parse_oncore_tables.pl by Marc Perry
# 
#
# 
# 
# 
# Last Updated: 2018-10-23, Status: in development

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
binmode STDOUT, ":utf8";
use utf8;
use JSON;
use Demographics;
use Biopsy qw(add_biopsy_dates extract_biopsies);
use Diagnosis;
use Primary;
use Ecogps;
use Preenrollment;
use Bloodlabs;
use Postbiopsy qw(add_progression_dates extract_postbx_tx);
use Assessment;
use Additional;
use List::MoreUtils qw(uniq);
use Date::Calc qw ( Delta_Days );

# Testing Version:
# my @table_names = qw( DTB-013_demographics.tsv DTB-013_prostate_diagnosis.tsv DTB-013_su2c_pr_ca_tx_sumry.tsv DTB-013_ecog_weight.tsv DTB-013_su2c_prior_tx.tsv DTB-013_Blood_Labs.csv DTB-013_su2c_subsequent_treatment.tsv DTB-013_gu_disease_assessment.tsv DTB-013_su2c_biopsy.tsv );

=pod

2018-06-21
I need to change the file names of these oncore files to match their new names:

demographics_filtered.tsv
prostate_diagnosis_v4_new_filtered.tsv
su2c_pr_ca_tx_sumry_v2_new_filtered.tsv
patient_ECOG_scale_performance_status_and_weight_new_filtered.tsv
su2c_prior_tx_v3_new_filtered.tsv
blood_labs_v2_new_filtered.tsv
su2c_subsequent_treatment_v1_new_filtered.tsv
gu_disease_assessment_new_v3_filtered.tsv
su2c_biopsy_v3_new_filtered.tsv


=cut


# Production Version:
my @table_names = ( 'demographics_filtered.tsv', 'prostate_diagnosis_v4_new_filtered.tsv', 'su2c_pr_ca_tx_sumry_v2_new_filtered.tsv', 'patient_ECOG_scale_performance_status_and_weight_new_filtered.tsv', 'su2c_prior_tx_v3_new_filtered.tsv', 'blood_labs_v2_new_filtered.tsv', 'su2c_subsequent_treatment_v1_new_filtered.tsv', 'gu_disease_assessment_new_v3_filtered.tsv', 'su2c_biopsy_v3_new_filtered.tsv', 'su2c_specimen_v1_extra_progression_records.tsv', 'wcdt_clinical_additional_data.tsv', );

=pod

=HEAD2 Previous (incorrect) version for Arm_1 was:
screening_arm_1-BLANK
baseline_tumor_bio_arm_1-BLANK
patient_dispositio_arm_1-patient_disposition
screening_arm_1-preenrollment_therapy
initiation_of_post_arm_1-postbiopsy_therapy
monthly_arm_1-psa_lab_test
every_3_months_arm_1-radiographic_disease_assessment

=HEAD2 Current (corrected) version for Arm_2 is:
pre_study_screen_arm_2-BLANK
pre_study_screen_arm_2-patient_enrollment_demographics
biopsy_arm_2-BLANK
patient_dispositio_arm_2-patient_disposition
pre_study_screen_arm_2-prostate_cancer_initial_diagnosis
pre_study_screen_arm_2-primary_therapy
pre_study_screen_arm_2-physical_exam
pre_study_screen_arm_2-preenrollment_therapy
pre_study_screen_arm_2-psa_lab_test
pre_study_screen_arm_2-labs
pre_study_screen_arm_2-radiographic_disease_assessment
pre_study_screen_arm_2-archival_tissue
pre_study_screen_arm_2-serum_neuroendocrine_markers
biopsy_arm_2-biopsy_collection
biopsy_arm_2-postbiopsy_therapy 
every_3_months_arm_2-psa_lab_test
every_3_months_arm_2-radiographic_disease_assessment
every_3_months_arm_2-serum_neuroendocrine_markers
progression_study_arm_2-psa_lab_test
progression_study_arm_2-radiographic_disease_assessment
progression_study_arm_2-biopsy_collection
progression_study_arm_2-serum_neuroendocrine_markers

=HEAD2 Even more current (even newer) version for Arm_2 (after the CRC team updated the data model for Arm_2) is:
Hold on a second, I think I need a data dump of the DTB-227 data that Alex entered to see about the order of these
events and instruments.

patient_dispositio_arm_2-patient_disposition
pre_study_screen_arm_2-BLANK
pre_study_screen_arm_2-patient_enrollment_demographics
pre_study_screen_arm_2-prostate_cancer_initial_diagnosis
pre_study_screen_arm_2-primary_therapy
pre_study_screen_arm_2-physical_exam
pre_study_screen_arm_2-preenrollment_therapy
pre_study_screen_arm_2-psa_lab_test
pre_study_screen_arm_2-labs
pre_study_screen_arm_2-radiographic_disease_assessment
pre_study_screen_arm_2-archival_tissue
pre_study_screen_arm_2-serum_neuroendocrine_markers
biopsy_arm_2-biopsy_collection
initiation_of_post_arm_2-postbiopsy_therapy
every_3_months_arm_2-psa_lab_test
every_3_months_arm_2-radiographic_disease_assessment
every_3_months_arm_2-serum_neuroendocrine_markers
progression_arm_2-physical_exam
progression_arm_2-psa_lab_test
progression_arm_2-labs
progression_arm_2-radiographic_disease_assessment
biopsy_2_arm_2-biopsy_collection
biopsy_2_arm_2-serum_neuroendocrine_markers
initiation_of_post_arm_2b-postbiopsy_therapy
every_3_months_pos_arm_2-psa_lab_test
every_3_months_pos_arm_2-radiographic_disease_assessment
followup_postbx_2_arm_2-radiographic_disease_assessment
progression_2_arm_2-physical_exam
progression_2_arm_2-psa_lab_test
progression_2_arm_2-labs
progression_2_arm_2-radiographic_disease_assessment
biopsy_3_arm_2-biopsy_collection
biopsy_3_arm_2-serum_neuroendocrine_markers
initiation_of_post_arm_2c-postbiopsy_therapy
every_3_months_pos_arm_2b-psa_lab_test
every_3_months_pos_arm_2b-radiographic_disease_assessment
followup_postbx_3_arm_2-radiographic_disease_assessment
progression_3_arm_2-physical_exam
progression_3_arm_2-psa_lab_test
progression_3_arm_2-labs
progression_3_arm_2-radiographic_disease_assessment
progression_3_arm_2-serum_neuroendocrine_markers


=cut



# for each table getting parsed, figure out which table it is, and
# give it a unique name, to store in this variable
my $current_table = q{}; 

my %types_of_tables = ( 'Prostate Diagnosis' => 'dx',
                        'SU2C Prostate Cancer Tx Summary' => 'prior_tx',
                        'ECOG-Weight' => 'ecogps',
                        'SU2C Prior Treatment' => 'pre_tx',
                        'Standard Blood Lab Form' => 'BL',
                        'SU2C Subsequent Treatment' => 'postbx_tx',
                        'GU Disease Assessment' => 'radiographic_assessment',
			'SU2C GU Biopsy' => 'biopsy',
                        'SU2C Specimen Collection' => 'spec',
			'WCDT_Additional' => 'wcdt_add',
                      );

my @gu = qw( assess_date assess_exam___1 assess_exam___2 assess_exam___3 assess_exam___4 assess_exam___5 assess_exam___6 other_exam assess_sites___1 assess_sites___2 assess_sites___3 assess_sites___4 assess_sites___5 assess_sites___6 other_sites_mets pre_tx_resp_bone_2 pre_tx_resp_recist_2 radiographic_disease_assessment_complete );	

my %ass = ();

# this is a global variable that I am going to use to track whether or not
# I have already updated the dates in Rahul's additional data table
my %updated = ();
my %seen = ();

my %red_drug_names = (
    "Abiraterone Acetate" => "abiraterone",
    "Abiraterone/Prednisone" => "abiraterone",
    "Avodart" => "CHEBI:521003",
    "Bicalutamide" => "CHEBI:3090",
    "Cabazitaxel" => "cabazitaxel",
    "Cabazitaxel/Predneisone" => "cabazitaxel",
    "Carboplatin" => "CHEBI:31355",
    "Cazodex" => "CHEBI:3090",
    "Degarelix" => "degarelix",
    "Docetaxel" => "CHEBI:59809",
    "Dutasteride" => "CHEBI:521003",
    "Enzalutamide" => "enzalutamide",
    "Finasteride" => "CHEBI:5062",
    "Firmagon" => "degarelix",
    "Flutamide" => "CHEBI:5132",
    "Goserelin Acetate" => "goserelin",
    "Ibrutinib" => "ibrutinib",
    "Imbruvica" => "ibrutinib",
    "Itraconazole" => "CHEBI:6076",
    "Jevtana" => "cabazitaxel",
    "Ketoconazole" => "CHEBI:48339",
    "Leuprolide Acetate" => "CHEBI:6427",
    "Lupron" => "CHEBI:6427",
    "Lupron Depot or Depot-Ped" => "CHEBI:6427",
    "Mitoxantrone Hydrochloride" => "CHEBI:50729",
    "Nilandron" => "nilutamide",
    "Nilutamide" => "nilutamide",
    "Propecia" => "CHEBI:5062",
    "Proscar" => "CHEBI:5062",
    "Provenge" => "sipuleucel-T",
    "Radium-223 Dichloride" => "RADIUM CHLORIDE RA-223 Injectable Solution",
    "Sipuleucel-T" => "sipuleucel-T",
    "Taxotere" => "CHEBI:59809",
    "Viadur" => "CHEBI:6427",
    "Alpharadin" => "RADIUM CHLORIDE RA-223 Injectable Solution",
    "Xofigo" => "RADIUM CHLORIDE RA-223 Injectable Solution",
    "Xtandi" => "enzalutamide",
    "Zoladex" => "goserelin",
    "zolodex" => "goserelin",
    "Zytiga" => "abiraterone",
    "Cabozantinib" => "cabozantinib",
    "Etoposide" => "CHEBI:4911",
    "Taxol" => "CHEBI:45863",
    "Cyclophosphamide" => "CHEBI:4027",
    "Dasatinib" => "dasatinib",
    "Denosumab" => "denosumab",
    "Dexamethasone" => "CHEBI:41879",
    "Estrogen" => "CHEBI:50114",
    "Everolimus" => "everolimus",
    "Gleevec" => "Gleevec",
    "Hydrocortisone Sodium Succinate" => "CHEBI:17650",
    "Ipilimumab" => "ipilimumab",
    "LBH589" => "panobinostat",
    "Pazopanib" => "pazopanib",
    "Placebo" => "placebo",
    "Prednisone" => "CHEBI:8382",
    "RAD001" => "everolimus",
    "Rosiglitazone" => "CHEBI:50122",
    "Tamoxifen" => "CHEBI:41774",
    "Testosterone" => "CHEBI:17347",
    "Trelstar" => "Triptorelin",
    "Triptorelin" => "Triptorelin",
    "Vandetanib" => "CHEBI:49960",
    "XGEVA" => "denosumab",
    "Zoledronic acid" => "zoldronic acid",
    "Abiraterone" => "abiraterone",
    "Casodex" => "CHEBI:3090",
    "Goserelin" => "goserelin",
    "Leuprolide" => "CHEBI:6427",
    "Lupron Depot" => "CHEBI:6427",
    "MDV 3100" => "enzalutamide",
    "MDV-3100" => "enzalutamide",
    "MDV3100" => "enzalutamide",
    "Mitoxantrone" => "CHEBI:50729",
    "Radium-223 chloride" => "RADIUM CHLORIDE RA-223 Injectable Solution",
    "olaparib" => "olaparib",
    "Cytoxan" => "Cytoxan",
    "Decadron"  => "CHEBI:41879",
    "VP-16" => "CHEBI:4911",
    "Melphalan" => "CHEBI:28876",
    "Phenelzine" => "Phenelzine",	
    "Diethylstilbestrol" => "Diethylstilbestrol",
    "Buserelin" => "Buserelin",
    "Calcitriol" => "CHEBI:17823",
    "Cyproterone" => "Cyproterone",
    "Cisplatin" => "CHEBI:27899",
    # MDPQ: Why didn't I add these?
    # "Selinexor" => "Selinexor",
    # "BKM120" => "BKM120",
    # "MLN8237" => "MLN8237",
  );


# This is the hash that will hold the data structure we eventually print out
my %redcap = ();

# 2018-10-23 I updated both of these arrays so that the field names would precisely match the latest version in REDCap
my @fields = qw( patient_id redcap_event_name redcap_repeat_instrument redcap_repeat_instance track_alive last_known_alive track_death pt_off_study off_study_date track_reason reason_off_study patient_disposition_complete first_name last_name mrn birth_date on_study_date study___1 study___3 next aggressive_phenotype criteria_aggressive___1 criteria_aggressive___2 criteria_aggressive___3 criteria_aggressive___4 institution opt_blood_draw provider_choice_therapy___1 provider_choice_therapy___2 provider_choice_therapy___3 provider_choice_therapy___4 provider_choice_therapy___5 provider_choice_therapy___6 provider_choice_therapy___7 planned_subseq_tx other_planned_sub_tx race ethnicity patient_enrollment_demographics_complete dx_state dx_primary dx_secondary dx_psa dx_date dx_mets_date dx_crpc_date date_of_mcrpc prostate_cancer_initial_diagnosis_complete prior_rp prior_rp_date prior_rad prior_rad_start prior_rad_stop primary_therapy_complete date_ecog ecog_value ecog_wt height physical_exam_complete pre_drug_name combo_drug pre_drug_name_2 drug_name_available___1 drug_name_specific pre_tx_cat___1 pre_tx_cat___2 pre_tx_cat___3 pre_tx_cat___4 pre_tx_cat___5 pre_tx_cat___6 adt_start adt_ongoing adt_stop nadir_psa_adt pre_tx_start pre_tx_ongoing pre_tx_stop pre_tx_reason other_stop_tx bl_psa_yn pre_tx_psa_bl baseline_psa_date nadir_psa_yn pre_tx_psa_nadir psa_response pre_tx_psa_resp pre_tx_resp_bone pre_tx_resp_recist pre_tx_pro_type___1 pre_tx_pro_type___3 pre_tx_pro_type___4 pre_tx_pro_type___5 pre_tx_pro_type___6 pre_tx_pro_type___7 other_prog_disease pre_tx_pro_date preenrollment_therapy_complete psa_date psa_value psa_lab_test_complete lab_date albumin_value alp_value ldh_value tst_value hgb_value plt_value wbc_value wbc_n_value labs_complete pre_drug_name_v2 combo_drug_v2 pre_drug_name_2_v2 drug_name_available_2___1 drug_name_specific_2 pre_tx_cat_v2___1 pre_tx_cat_v2___2 pre_tx_cat_v2___3 pre_tx_cat_v2___4 pre_tx_cat_v2___5 pre_tx_cat_v2___6 adt_start_v2 adt_ongoing_v2 adt_stop_v2 post_nadir_psa_adt pre_tx_start_v2 pre_tx_ongoing_v2 pre_tx_stop_v2 pre_tx_reason_v2 other_stop_tx_v2 bl_psa_yn_v2 pre_tx_psa_bl_v2 baseline_psa_date_v2 nadir_psa_yn_v2 pre_tx_psa_nadir_v2 psa_response_v2 pre_tx_psa_resp_v2 pre_tx_resp_bone_v2 pre_tx_resp_recist_v2 pre_tx_pro_type_v2___1 pre_tx_pro_type_v2___3 pre_tx_pro_type_v2___4 pre_tx_pro_type_v2___5 pre_tx_pro_type_v2___6 pre_tx_pro_type_v2___7 other_prog_disease_v2 pre_tx_pro_date_v2 postbiopsy_therapy_complete assess_date assess_exam___1 assess_exam___2 assess_exam___3 assess_exam___4 assess_exam___5 assess_exam___6 other_exam assess_sites___1 assess_sites___2 assess_sites___3 assess_sites___4 assess_sites___5 assess_sites___6 other_sites_mets pre_tx_resp_bone_2 pre_tx_resp_recist_2 radiographic_disease_assessment_complete bx_timepoint organ_site same_lesion specimen_id bx_date steroids specify_steroids opioids specify_opioids site_biopsy bone_bx_location other_site_bx clia other_clia germline_mutations mutations biopsy_collection_complete archival_tissue_yn dos sample_type other_sample_type facility accession_number archival_tissue_complete date_blood_draw serum_value enolase_value serum_neuroendocrine_markers_complete );

my @fields_to_print = qw( track_alive last_known_alive track_death pt_off_study off_study_date track_reason reason_off_study patient_disposition_complete first_name last_name mrn birth_date on_study_date study___1 study___3 next aggressive_phenotype criteria_aggressive___1 criteria_aggressive___2 criteria_aggressive___3 criteria_aggressive___4 institution opt_blood_draw provider_choice_therapy___1 provider_choice_therapy___2 provider_choice_therapy___3 provider_choice_therapy___4 provider_choice_therapy___5 provider_choice_therapy___6 provider_choice_therapy___7 planned_subseq_tx other_planned_sub_tx race ethnicity patient_enrollment_demographics_complete dx_state dx_primary dx_secondary dx_psa dx_date dx_mets_date dx_crpc_date date_of_mcrpc prostate_cancer_initial_diagnosis_complete prior_rp prior_rp_date prior_rad prior_rad_start prior_rad_stop primary_therapy_complete date_ecog ecog_value ecog_wt height physical_exam_complete pre_drug_name combo_drug pre_drug_name_2 drug_name_available___1 drug_name_specific pre_tx_cat___1 pre_tx_cat___2 pre_tx_cat___3 pre_tx_cat___4 pre_tx_cat___5 pre_tx_cat___6 adt_start adt_ongoing adt_stop nadir_psa_adt pre_tx_start pre_tx_ongoing pre_tx_stop pre_tx_reason other_stop_tx bl_psa_yn pre_tx_psa_bl baseline_psa_date nadir_psa_yn pre_tx_psa_nadir psa_response pre_tx_psa_resp pre_tx_resp_bone pre_tx_resp_recist pre_tx_pro_type___1 pre_tx_pro_type___3 pre_tx_pro_type___4 pre_tx_pro_type___5 pre_tx_pro_type___6 pre_tx_pro_type___7 other_prog_disease pre_tx_pro_date preenrollment_therapy_complete psa_date psa_value psa_lab_test_complete lab_date albumin_value alp_value ldh_value tst_value hgb_value plt_value wbc_value wbc_n_value labs_complete pre_drug_name_v2 combo_drug_v2 pre_drug_name_2_v2 drug_name_available_2___1 drug_name_specific_2 pre_tx_cat_v2___1 pre_tx_cat_v2___2 pre_tx_cat_v2___3 pre_tx_cat_v2___4 pre_tx_cat_v2___5 pre_tx_cat_v2___6 adt_start_v2 adt_ongoing_v2 adt_stop_v2 post_nadir_psa_adt pre_tx_start_v2 pre_tx_ongoing_v2 pre_tx_stop_v2 pre_tx_reason_v2 other_stop_tx_v2 bl_psa_yn_v2 pre_tx_psa_bl_v2 baseline_psa_date_v2 nadir_psa_yn_v2 pre_tx_psa_nadir_v2 psa_response_v2 pre_tx_psa_resp_v2 pre_tx_resp_bone_v2 pre_tx_resp_recist_v2 pre_tx_pro_type_v2___1 pre_tx_pro_type_v2___3 pre_tx_pro_type_v2___4 pre_tx_pro_type_v2___5 pre_tx_pro_type_v2___6 pre_tx_pro_type_v2___7 other_prog_disease_v2 pre_tx_pro_date_v2 postbiopsy_therapy_complete assess_date assess_exam___1 assess_exam___2 assess_exam___3 assess_exam___4 assess_exam___5 assess_exam___6 other_exam assess_sites___1 assess_sites___2 assess_sites___3 assess_sites___4 assess_sites___5 assess_sites___6 other_sites_mets pre_tx_resp_bone_2 pre_tx_resp_recist_2 radiographic_disease_assessment_complete bx_timepoint organ_site same_lesion specimen_id bx_date steroids specify_steroids opioids specify_opioids site_biopsy bone_bx_location other_site_bx clia other_clia germline_mutations mutations biopsy_collection_complete archival_tissue_yn dos sample_type other_sample_type facility accession_number archival_tissue_complete date_blood_draw serum_value enolase_value serum_neuroendocrine_markers_complete );


my @metadata; # an array to hold all the hashes from each line

# A global variable to fill with biopsy time points
my %timespans = ();
# A global variable to fill with ecog time points
my %ecog_dates = ();

# STEP 1: Read in all the OnCore TSV files in a specific order, and convert
# them into a single array of hashrefs

foreach my $file ( @table_names ) {
    open my ($FH1), '<', "../$file" or die "Could not open $file for reading";
    
    my $header = <$FH1>;  
    chomp $header;

    my @column_headers = split(/\t/, $header); # parse the fields into an array

    while ( <$FH1> ) {
        chomp;
        # a hash to hold each line of metadata
        my %input_records; 
        @input_records{@column_headers} = split(/\t/, $_); # a hash slice 
        push @metadata, \%input_records; # an array of hashes

        # if this record is from the OnCore Biopsy table then extract some values into
	# the %timespans hash
        if ( $input_records{FORM_DESC_} ) {
            my $id = 'DTB-' . $input_records{SEQUENCE_NO_};
	    if ( $input_records{FORM_DESC_} eq 'SU2C GU Biopsy' ) {
		add_biopsy_dates( $id, \%input_records, \%timespans, );
	    }
	    if ( $input_records{FORM_DESC_} eq 'SU2C Subsequent Treatment' ) {
		add_progression_dates( $id, \%input_records, \%timespans, );
	    }

            if ( $input_records{FORM_DESC_} eq 'ECOG-Weight' ) {
                # I _think_ this was a placeholder to remind me to make a parallel subroutine
		# like above, but I have run out of time
                # add_ecog_dates( $id, \%input_records, \%timespans, );
                if ( $input_records{VISIT_DATE} ) {
                    my $date = iso_date ( $input_records{VISIT_DATE} );
	     	    if ( $input_records{SEGMENT} =~ m/Progression/ ) {
                        push @{$ecog_dates{$id}{Progression}}, $date;
	            }
	        }
	    }
            if ( $input_records{FORM_DESC_} eq 'SU2C Specimen Collection' ) {
                if ( $input_records{VISIT_DATE} ) {
                    my $date = iso_date ( $input_records{VISIT_DATE} );
                    # Originally, I thought that I would create an additional
		    # hashref key for these extra specimen timepoints
		    # but given that each of the 20 should have a single
		    # baseline biopsy, I think it will be simplest to
		    # add these dates to the array of biopsy_dates
                    push @{$timespans{$id}{biopsy_dates}}, $date;
		}
	    }
	}
    } # close while loop

    close $FH1;
} # close foreach loop 

# print "\n", Data::Dumper->new([\%timespans],[qw(timespans)])->Indent(1)->Quotekeys(0)->Dump, "\n";
# exit;

# STEP 1.5 (NEW) sort the dates in the %timespans hash

foreach my $id ( keys( %timespans ) ) {
    if ( $timespans{$id}{biopsy_dates} ) {
        @{$timespans{$id}{biopsy_dates}} = sort { $a cmp $b } @{$timespans{$id}{biopsy_dates}};    
    }
    if ( $timespans{$id}{txprogdates} ) {
        @{$timespans{$id}{txprogdates}} = sort { $a cmp $b } @{$timespans{$id}{txprogdates}};    
        # collapse multiple treatment progression dates with the same time stamp into a single
	# patient event by removing any duplicate dates from these arrayrefs:
        @{$timespans{$id}{txprogdates}} = uniq @{$timespans{$id}{txprogdates}};    
    }

    # Now pay attention, because this is going to get somewhat convoluted, and you are very likely
    # going to come back to this section and scratch your head later trying to understand
    # what was going on

    # STEP 1 (inside this foreach loop) Determine if for this specific patient_id
    # if there is just a hashref for biopsy_dates, or just a hashref for txprogdates
    # or hashrefs for both biopsy_dates and txprogdates.  Because depending on
    # which it is the script is going to do different things
    if ( $timespans{$id}{biopsy_dates} ) {
        if ( $timespans{$id}{txprogdates} ) {
            # This patient_id has both a biopsy_dates, AND a txprogdates hashref
	    if ( scalar( @{$timespans{$id}{biopsy_dates}} ) == 1 ) {
                $timespans{$id}{max} = 'baseline';
                $timespans{$id}{baseline} = shift @{$timespans{$id}{biopsy_dates}};
	    }
	    elsif ( scalar( @{$timespans{$id}{biopsy_dates}} ) == 2 ) {
                $timespans{$id}{max} = 'progression_1';
                $timespans{$id}{baseline} = shift @{$timespans{$id}{biopsy_dates}};
                foreach my $bx ( 0..$#{$timespans{$id}{biopsy_dates}} ) {
                    my $bx_prog_num = $bx + 1;
		    $timespans{$id}{'progression_' . $bx_prog_num} = $timespans{$id}{biopsy_dates}[$bx];
		    push @{$timespans{$id}{merged}}, $timespans{$id}{biopsy_dates}[$bx];
		}
	    }
	    elsif ( scalar( @{$timespans{$id}{biopsy_dates}} ) == 3 ) {
                $timespans{$id}{max} = 'progression_2';
                $timespans{$id}{baseline} = shift @{$timespans{$id}{biopsy_dates}};
                foreach my $bx ( 0..$#{$timespans{$id}{biopsy_dates}} ) {
                    my $bx_prog_num = $bx + 1;
		    $timespans{$id}{'progression_' . $bx_prog_num} = $timespans{$id}{biopsy_dates}[$bx];
		    push @{$timespans{$id}{merged}}, $timespans{$id}{biopsy_dates}[$bx];
		}
	    }
	    elsif ( scalar( @{$timespans{$id}{biopsy_dates}} ) == 4 ) {
                $timespans{$id}{max} = 'progression_3';
                $timespans{$id}{baseline} = shift @{$timespans{$id}{biopsy_dates}};
                foreach my $bx ( 0..$#{$timespans{$id}{biopsy_dates}} ) {
                    my $bx_prog_num = $bx + 1;
		    $timespans{$id}{'progression_' . $bx_prog_num} = $timespans{$id}{biopsy_dates}[$bx];
		    push @{$timespans{$id}{merged}}, $timespans{$id}{biopsy_dates}[$bx] ;
		}
	    }

	    for my $tx ( 0..$#{$timespans{$id}{txprogdates}} ) {
#                my $tx_prog_num = $tx + 1;
                push @{$timespans{$id}{merged}}, $timespans{$id}{txprogdates}[$tx];
            } # close second for loop
            # Oh, Okay, I don't need a test now, because only the records that enter this inner code block
            # will have the merged hash key

            @{$timespans{$id}{sorted}} = sort { $a cmp $b } @{$timespans{$id}{merged}};
	    # Make a copy of the sorted event array
            my @event_array = @{$timespans{$id}{sorted}};
            # Always use the first date in the @event_array as progression_1
            
            $timespans{$id}{progression_1} = $event_array[0];
            # overwrite/reset the value of max for this sample
            $timespans{$id}{max} = 'progression_1';
            my %tracking = ();

            shift @event_array;
	    # now iterate over all the events in the @event_array, there has to be at
	    # least one more event because otherwise there would not have been a merge
	    foreach my $event ( @event_array ) {
                my ( $year1, $month1, $day1 ) = split /-/, $timespans{$id}{progression_1};
                my $date = $event;
                my ( $year2, $month2, $day2 ) = split /-/, $date;
		my $days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2);
                # if ( $days > 31 ) {
                if ( $days > 37 ) {		    
                    # if any of the other ordered events are more than 31 days after progression_1
		    # then by definition the first one must be progression_2
		    $timespans{$id}{progression_2} = $date;
		    # now get out.  No need to keep testing, you found the earliest timepoint
		    # for the progression_2 event
		    $tracking{progression_2} = '1';
                    $timespans{$id}{max} = 'progression_2';
                    last;
		}
	    } # close foreach my $event

            # either that last foreach loop set a date for progression_2, OR there is no
	    # progression_2, so test.
            if ( exists $tracking{progression_2} ) {
                foreach my $event ( @event_array ) {
                    my ( $year1, $month1, $day1 ) = split /-/, $timespans{$id}{progression_2};		    
                    my $date = $event;
                    my ( $year2, $month2, $day2 ) = split /-/, $date;
		    my $days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2);
		    # if ( $days > 31 ) {
		    if ( $days > 37 ) {
                        $timespans{$id}{progression_3} = $date;
			$timespans{$id}{max} = 'progression_3';
			last;
		    }
		} # close foreach my $event
            }		
            # There is no progression level higher than progression_3 in the REDCap data model, so there
	    # is no point in checking or testing any of the other values.
        }    
        else {
            # This patient_id only has a biopsy_dates hashref
            if ( scalar( @{$timespans{$id}{biopsy_dates}} ) == 1 ) {
                $timespans{$id}{max} = 'baseline';
                $timespans{$id}{baseline} = $timespans{$id}{biopsy_dates}[0];
            }
            elsif ( scalar( @{$timespans{$id}{biopsy_dates}} ) == 2 ) {
                $timespans{$id}{max} = 'progression_1';
                $timespans{$id}{baseline} = $timespans{$id}{biopsy_dates}[0];
                $timespans{$id}{progression_1} = $timespans{$id}{biopsy_dates}[1];
            }
            elsif ( scalar( @{$timespans{$id}{biopsy_dates}} ) == 3 ) {
                $timespans{$id}{max} = 'progression_2';
                $timespans{$id}{baseline} = $timespans{$id}{biopsy_dates}[0];
                $timespans{$id}{progression_1} = $timespans{$id}{biopsy_dates}[1];
                $timespans{$id}{progression_2} = $timespans{$id}{biopsy_dates}[2];
            }
            elsif ( scalar( @{$timespans{$id}{biopsy_dates}} ) == 4 ) {    
                $timespans{$id}{max} = 'progression_3';
                $timespans{$id}{baseline} = $timespans{$id}{biopsy_dates}[0];
                $timespans{$id}{progression_1} = $timespans{$id}{biopsy_dates}[1];
                $timespans{$id}{progression_2} = $timespans{$id}{biopsy_dates}[2];
                $timespans{$id}{progression_3} = $timespans{$id}{biopsy_dates}[3];
            }
	}
    }
    else {
        # This patient HAS to have a txprogdates hashref (to get into the hash in the first place)
	# There is exactly one patient in this category: DTB-100
        $timespans{$id}{max} = 'progression_1';
        $timespans{$id}{baseline} = undef;
        $timespans{$id}{progression_1} = $timespans{$id}{txprogdates}[0];
    }
} # close foreach my $id

# this next block exists solely to print out a table showing the contents of the %timespans hash:

=pod

print "patient_id\tbaseline\tmax\tprogression_1\tprogression_2\tprogression_3\tbx_count\ttx_count\tmerge_count\n";
foreach my $id ( sort keys %timespans ) {
    print "$id";
    print "\t$timespans{$id}{baseline}";
    print "\t$timespans{$id}{max}";
    if ( $timespans{$id}{progression_1} ) {
        print "\t$timespans{$id}{progression_1}";
    }
    else {
        print "\t";
    }
    if ( $timespans{$id}{progression_2} ) {
        print "\t$timespans{$id}{progression_2}";
    }
    else {
        print "\t";
    }
    if ( $timespans{$id}{progression_3} ) {
        print "\t$timespans{$id}{progression_3}";
    }
    else {
        print "\t";
    }
    if ( $timespans{$id}{biopsy_dates} ) {
        print "\t" . scalar( @{$timespans{$id}{biopsy_dates}} ) if (defined scalar( @{$timespans{$id}{biopsy_dates}} ) );
    }
    else {
        print "\t";
    }
    if (  $timespans{$id}{txprogdates} ) {
        print "\t" . scalar( @{$timespans{$id}{txprogdates}} ) if (defined scalar( @{$timespans{$id}{txprogdates}} ) );
    }
    else {
        print "\t";
    }
    if ( $timespans{$id}{merged} ) {
        print "\t" . scalar( @{$timespans{$id}{merged}} ) . "\n" if ( defined scalar( @{$timespans{$id}{merged}} ) );
    }
    else {
        print "\t\n";
    }
    

}
exit;

=cut


# Sort the dates of the ecog_dates for each ID for each segment
foreach my $id ( keys( %ecog_dates ) ) {
    foreach my $segment ( keys( $ecog_dates{$id} ) ) {
        @{$ecog_dates{$id}{$segment}} = sort { $a cmp $b } @{$ecog_dates{$id}{$segment}};
    } # close foreach my $segment loop
} # close foreach my $ id loop


# print "\n", Data::Dumper->new([\%timespans],[qw(timespans)])->Indent(1)->Quotekeys(0)->Dump, "\n";
# print "\n", Data::Dumper->new([\%ecog_dates],[qw(ecog_dates)])->Indent(1)->Quotekeys(0)->Dump, "\n";
# exit;    

# STEP 2. Process each row, one at a time
foreach my $row ( @metadata ) {
    my %hash = %{$row};
    # every OnCore table has the same first column, which contains
    # a three-digit numeral which serves at the unique identifier for
    # each patient in the WCDT study, and that is the link that lets
    # me build the final data structure named %redcap
    my $patient_id =q{};
    
    # if ( $hash{SEQUENCE_NO_} =~ m/DTB|227/ ) {
    if ( $hash{SEQUENCE_NO_} =~ m/DTB/ ) {	
        $patient_id = $hash{SEQUENCE_NO_};
    }
    else {
        $patient_id = 'DTB-' . $hash{SEQUENCE_NO_};
    }
	
    if ( $row->{FORM_DESC_} ) {
        my $field = $row->{FORM_DESC_};
        if ( $types_of_tables{$field} ) {
            $current_table = $types_of_tables{$field};
	}
	else {
            die "Couldn't find a table type for $field";
	}
    }
    else {
        $current_table = 'demographics';
    }
    

=pod 

=head1 Demographics

Corresponds approximately to the REDCap form named:
patient_enrollment_demographics

This will be the first table stored in the @metadata array, and therefore
the first table processed.  Each WCDT Patient in OnCore has a single record
in the incoming demographics table
N.B. Also includes patient disposition events and instruments

=cut

    if ( $current_table eq 'demographics' ) {
        extract_demographics ( $patient_id, \%hash, \%redcap, \@fields_to_print, );
    } # close if $current_table = demographics

=pod

GU Biopsy Collection

=cut
    
    if ( $current_table eq 'biopsy' ) {
        next if $hash{NOT_APPLICABLE_OR_MISSING};
        extract_biopsies( $patient_id, \%hash, \%redcap, \@fields_to_print, \%timespans, );    
    } # close if $current_table eq biopsy block


    
=pod

=head1 Prostate Diagnosis

Corresponds approximately to the REDCap form named:
prostate_cancer_initial_diagnosis

=cut

    
    if ( $current_table eq 'dx' ) {
        extract_diagnosis ( $patient_id, \%hash, \%redcap, );
    } # close if current form is diagnosis
    

=pod

=head1 Prior Cancer Therapy Summary

Corresponds approximately to REDCap form
primary_therapy

=cut

    if ( $current_table eq 'prior_tx' ) {
        extract_primary_tx ( $patient_id, \%hash, \%redcap, );
    } # close if $current_table eq prior_tx

=pod 

=head1 ECOG Scale Performance Status & Weight

Corresponds approximately to REDCap form named
physical_exam

=cut

    if ( $current_table eq 'ecogps' ) {
        extract_ecogps ( $patient_id, \%hash, \%redcap, \@fields_to_print, \%ecog_dates, );
    }

    
=pod

=head1 Prior Treatment, also known as, Pre-enrollment Therapy

The rows in this OnCore table will become part of a repeating instrument
in REDCap, and therefore in the %redcap data structure the information in 
each row will be stored under here:

=cut

    if ( $current_table eq 'pre_tx' ) {
        next if $hash{NOT_APPLICABLE_OR_MISSING};
	next unless ( $hash{DRUG_NAME} || $hash{TREATMENT_DETAILS} );
        extract_preenrollment_tx ( $patient_id, \%hash, \%redcap, \@fields_to_print, \%red_drug_names, );
    } # close if ( $current_table eq 'pre_tx' )

 
=pod
   
PSA Lab Test, 

Standard Blood Labs or just simply, Labs

=cut

    if ( $current_table eq 'BL' ) {
        next if $hash{NOT_APPLICABLE_OR_MISSING};
        next if $hash{INTERNATIONAL_NORMALIZED_RATIO__};
        next if $hash{PARTIAL_THROMBOPLASTIN_TIME____P};
        next if $hash{PROTHROMBIN_TIME__PT_};
        extract_labs ( $patient_id, \%hash, \%redcap, \@fields_to_print, \%timespans, );
    } # close if ( $current_table eq 'BL' )

=pod
    
Subsequent Patient Treatment, or, Postbiopsy Therapy

=cut

    if ( $current_table eq 'postbx_tx' ) {
        next if $hash{NOT_APPLICABLE_OR_MISSING};
	next unless ( $hash{DRUG_NAME} || $hash{TREATMENT_DETAILS} );
	next unless ( $hash{START_DATE} );
        extract_postbx_tx ( $patient_id, \%hash, \%redcap, \@fields_to_print, \%red_drug_names, \%timespans, );
    } # close if ( $current_table eq 'postbx_tx' )

=pod

Radiographic Disease Assessment

pre_study_screen_arm_2-BLANK
pre_study_screen_arm_2-radiographic_disease_assessment
every_3_months_arm_2-radiographic_disease_assessment

This is an example of a REDCap repeating instrument

=cut

    if ( $current_table eq 'radiographic_assessment' ) {
        # This is the penultimate Perl module that gets called in the foreach loop that is processing
	# the elements in the @metadata array.
	# The call to the extract_assessments sub-routine in the Assessment.pm module
	# is passed the $patient_id for this record, and then references to the %hash for this
	# record, the global %redcap hash, the global @fields_to_print array, the sort of
	# global %ass hash, and the reference array @gu. 2018-10-16: Also, the %timespans hash
	#
	# 2018-07-12 Comment
	# Whilst troubleshooting & debugging most recently, I noticed that there was at least one record
	# That had an entry in the NOT_APPLICABLE_OR_MISSING column so I am going
	# To add this test here as well (previously my script did not test this)
        next if $hash{NOT_APPLICABLE_OR_MISSING} =~ /applicable/i;
        extract_assessments ( $patient_id, \%hash, \%redcap, \@fields_to_print, \%ass, \@gu, \%timespans, );
    } # close if ( $current_table eq 'radiographic_assessment' ) 

=pod    

WCDT Additional Clinical Data

This is the MS-Excel Spreadsheet that Rahul gave me when 
he learned I was about to leave the project, and he still had a pantload
of feature requests to request.


=cut

    if ( $current_table eq 'wcdt_add' ) {
        # This is the final Perl module that gets called in the foreach loop that is processing
	# the elements in the @metadata array.
	# The call to the extract_additional sub-routine in the Additional.pm module
	# is passed the $patient_id for this record, and then references to the %hash for this
	# record, the global %redcap hash

	# There were a couple of rows in Rahul's table where the patient was not in the OnCore
	# Data dump, so the first test is to make sure the current record is for a bona fide
	# OnCore patient id.
        next unless ( exists $redcap{$patient_id} );
        extract_additional ( $patient_id, \%hash, \%redcap, \%timespans, \%updated, \%seen, );
    } # close if ( $current_table eq 'wcdt_add' )
} # close foreach my $row ( @metadata )

=pod

Copy the contents of the %ass hash over into the %redcap hash prior to printing

=cut

# STEP 1. Iterate over the keys of the %ass hash, these are patient_ids
foreach my $id ( sort keys %ass ) {
    # STEP 2. Iterate over the events for the repeating instruments
    foreach my $event ( sort keys %{$ass{$id}} ) {
        foreach my $date ( sort keys %{$ass{$id}{$event}} ) {
            my $instance = $ass{$id}{$event}{$date}{'instance'};
            foreach my $field ( @gu ) {
 	        if ( $field eq 'other_sites_mets' ) {
                    # is there something that evaluates to 'TRUE' stored in this hashref key?
                    if ( $ass{$id}{$event}{$date}{'other_sites_mets'} ) {
		        # Then store all those hashref keys in an array
                        my @sites = keys %{$ass{$id}{$event}{$date}{'other_sites_mets'}};
                        # join the text strings together
		        my $concatenated = join( '; ', @sites );
                        # and insert this into the larger data structure
                        $redcap{$id}{$event}{$instance}{$field} = $concatenated;
	            }
	            else {
                        $redcap{$id}{$event}{$instance}{$field} = $ass{$id}{$event}{$date}{$field};
		    }
       	        }
	        else {
                    $redcap{$id}{$event}{$instance}{$field} = $ass{$id}{$event}{$date}{$field};
	        }
            } # close foreach my $field loop
        } # close foreach my $date loop
    } # close foreach my $event loop
} # close foreach my $id loop

# print_jsonl( \@metadata );
# print_jsonl( \%redcap );
print "\n", Data::Dumper->new([\%redcap],[qw(redcap)])->Indent(1)->Quotekeys(0)->Dump, "\n";    
exit;
print_redcap();
exit;

    
=pod

    
Hmmm, hit a challenge right away, with those darn instruments and
forms and crap.

For PR-007 there is what I am working on:
pre_study_screen_arm_2		
biopsy_arm_2		
patient_dispositio_arm_2	patient_disposition	1
pre_study_screen_arm_2	preenrollment_therapy	1
pre_study_screen_arm_2	preenrollment_therapy	2
pre_study_screen_arm_2	preenrollment_therapy	3
pre_study_screen_arm_2	preenrollment_therapy	4
biopsy_arm_2	postbiopsy_therapy	1
every_3_months_arm_2	psa_lab_test	1
every_3_months_arm_2	psa_lab_test	2
every_3_months_arm_2	psa_lab_test	3
every_3_months_arm_2	psa_lab_test	4
every_3_months_arm_2	psa_lab_test	5
every_3_months_arm_2	psa_lab_test	6
every_3_months_arm_2	radiographic_disease_assessment	1

What if I transform that into:
pre_study_screen_arm_2_BLANK_BLANK
biopsy_arm_2_BLANK_BLANK
patient_dispositio_arm_2_patient_disposition_1
pre_study_screen_arm_2_preenrollment_therapy_1
pre_study_screen_arm_2_preenrollment_therapy_2
pre_study_screen_arm_2_preenrollment_therapy_3
pre_study_screen_arm_2_preenrollment_therapy_4
biopsy_arm_2_postbiopsy_therapy_1
every_3_months_arm_2_psa_lab_test_1
every_3_months_arm_2_psa_lab_test_2
every_3_months_arm_2_psa_lab_test_3
every_3_months_arm_2_psa_lab_test_4
every_3_months_arm_2_psa_lab_test_5
every_3_months_arm_2_psa_lab_test_6
every_3_months_arm_2_radiographic_disease_assessment_1

Okay, may be an improvement, but I want to have a minimal list that I
can hardcode in my script, so lets modify that one a bit
pre_study_screen_arm_2-BLANK
biopsy_arm_2-BLANK
patient_dispositio_arm_2-patient_disposition
pre_study_screen_arm_2-preenrollment_therapy
biopsy_arm_2-postbiopsy_therapy
every_3_months_arm_2-psa_lab_test
every_3_months_arm_2-radiographic_disease_assessment

I realized that if I wanted to split the two terms then I could not
use underscore because the field names from REDCap already contain
underscores.  Now, is this a complete possible list, or is there
another field that could be a repeating instrument? Nope, based on my
analysis of the exisiting REDCap data dump that should do it.  So
those hyphenated values become REDCap 

=cut


sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, "\n";
    }
    return $good_date;
} # close sub iso_date

=pod

This now actually the former version of this redcap event array, I swapped in the new one below

    my @events = qw( pre_study_screen_arm_2-BLANK pre_study_screen_arm_2-patient_enrollment_demographics biopsy_arm_2-BLANK patient_dispositio_arm_2-patient_disposition pre_study_screen_arm_2-prostate_cancer_initial_diagnosis pre_study_screen_arm_2-primary_therapy pre_study_screen_arm_2-physical_exam pre_study_screen_arm_2-preenrollment_therapy biopsy_arm_2-postbiopsy_therapy pre_study_screen_arm_2-psa_lab_test pre_study_screen_arm_2-labs pre_study_screen_arm_2-radiographic_disease_assessment pre_study_screen_arm_2-archival_tissue pre_study_screen_arm_2-serum_neuroendocrine_markers biopsy_arm_2-biopsy_collection every_3_months_arm_2-psa_lab_test every_3_months_arm_2-radiographic_disease_assessment every_3_months_arm_2-serum_neuroendocrine_markers progression_study_arm_2-psa_lab_test progression_study_arm_2-radiographic_disease_assessment progression_study_arm_2-biopsy_collection  progression_study_arm_2-serum_neuroendocrine_markers );

=cut


# print tsv table for REDCap
sub print_redcap {
    # print the header for the TSV file you want to eventually import into REDCap
    print join( "\t", @fields ), "\n";
    # # # #
    # N.B. _EVERY_ Time you change this REDCap Projects "Instruments and Events" Grid, to generate a new combination of an Event
    # and and Instrument, then you absolutely need to update the contents of this array accordingly.  Otherwise, the new
    # Information may be captured in your data structure, but they will never get printed out. Which is rather mysterious.
    # WHOOPS! I almost missed this factoid.  In addition to all of these official event-instrument pairings you also absolutely
    # need to insert these two extra items on the list: pre_study_screen_arm_2-BLANK AND, progression_arm_2-BLANK
    # # # #
    
    my @events = qw( patient_dispositio_arm_2-patient_disposition pre_study_screen_arm_2-BLANK pre_study_screen_arm_2-patient_enrollment_demographics pre_study_screen_arm_2-prostate_cancer_initial_diagnosis pre_study_screen_arm_2-primary_therapy pre_study_screen_arm_2-physical_exam pre_study_screen_arm_2-preenrollment_therapy pre_study_screen_arm_2-psa_lab_test pre_study_screen_arm_2-labs pre_study_screen_arm_2-radiographic_disease_assessment pre_study_screen_arm_2-archival_tissue pre_study_screen_arm_2-serum_neuroendocrine_markers biopsy_arm_2-biopsy_collection biopsy_arm_2-serum_neuroendocrine_markers initiation_of_post_arm_2-postbiopsy_therapy every_3_months_arm_2-psa_lab_test every_3_months_arm_2-radiographic_disease_assessment every_3_months_arm_2-serum_neuroendocrine_markers progression_arm_2-BLANK progression_arm_2-physical_exam progression_arm_2-psa_lab_test progression_arm_2-labs progression_arm_2-radiographic_disease_assessment biopsy_2_arm_2-biopsy_collection biopsy_2_arm_2-serum_neuroendocrine_markers initiation_of_post_arm_2b-postbiopsy_therapy every_3_months_pos_arm_2-psa_lab_test every_3_months_pos_arm_2-radiographic_disease_assessment followup_postbx_2_arm_2-radiographic_disease_assessment progression_2_arm_2-physical_exam progression_2_arm_2-psa_lab_test progression_2_arm_2-labs progression_2_arm_2-radiographic_disease_assessment biopsy_3_arm_2-biopsy_collection biopsy_3_arm_2-serum_neuroendocrine_markers initiation_of_post_arm_2c-postbiopsy_therapy every_3_months_pos_arm_2b-psa_lab_test every_3_months_pos_arm_2b-radiographic_disease_assessment followup_postbx_3_arm_2-radiographic_disease_assessment progression_3_arm_2-physical_exam progression_3_arm_2-psa_lab_test progression_3_arm_2-labs progression_3_arm_2-radiographic_disease_assessment progression_3_arm_2-serum_neuroendocrine_markers );
    
    # The keys in this global hash are the patient_ids
    foreach my $id ( sort keys %redcap ) {
        # Production version:
        foreach my $event_instr ( @events ) {
            # don't print out truncated empty rows if this patient_id does not use the current 
            # REDCap instrument (i.e., they are not in the  data structure for this patient_id:
            next unless ( $redcap{$id}{$event_instr} );
            # I used a hyphen or dash to create a compound key
            my ( $event, $instr ) = split(/-/, $event_instr);
            if ( $instr eq 'BLANK' ) {
                print "$id\t$event\t\t";
                foreach my $field ( @fields_to_print ) {
		    # So remember, I pre-populated all of the values in the data structure with undef
		    # everything is defined including '', '0', and '1' so the only thing that won't
		    # pass this test is undef:
                    if ( defined $redcap{$id}{$event_instr}{$field} ) {
                        my $value = $redcap{$id}{$event_instr}{$field};
                        print "\t$value";
                    }
                    else {
                        print "\t";
                    }
                } # close foreach my $field
                print "\n";
            }
            else {
                # The code block above prints out instruments that don't repeat, and this
		# code block prints out instruments that are repeating
                foreach my $instance ( sort { $a <=> $b } keys %{ $redcap{$id}{$event_instr} } ) {
                    print "$id\t$event\t$instr\t$instance";
                    foreach my $field ( @fields_to_print ) {
                        if ( defined $redcap{$id}{$event_instr}{$instance}{$field} ) {
                            print "\t$redcap{$id}{$event_instr}{$instance}{$field}";
                        }
                        else {
                            print "\t";
                        }
                    } # close foreach my $field
                    print "\n";
                } # close foreach my $instance
            } # close if/else test
        } # close foreach my $event_instr
    } # close foreach my $id
} # close sub print_redcap

sub print_hash {
    my $data = shift @_;
    my %hash = %{ $data };
    foreach my $key ( sort keys %hash ) {
        print "$key\t$hash{$key}\n";
    }
} # close sub print_hash

sub print_jsonl {
    my $redcap = shift @_;
#    my %redcap = %{$redcap};
    my @redcap = @{$redcap};    
#    open my ($FH), '>>', 'dumped_redcap_hash.jsonl' or die "Could not open output file for writing"; 
    open my ($FH), '>>', 'dumped_metadata_array.jsonl' or die "Could not open output file for writing"; 
    foreach my $row ( @metadata ) {
        my $json = encode_json($row);
        print $FH $json, "\n";
    }
    close $FH;
} # close sub print_jsonl


__END__

# Customized Data::Dumper commands to print out:
# an array to a file
# print Data::Dumper->new([\@wiki_terms],[qw(wiki_terms)])->Indent(1)->Quotekeys(0)->Dump, "\n";
# a hash to STDERR:
# print STDERR "\n", Data::Dumper->new([\%soap_hash],[qw(soap_hash)])->Indent(1)->Quotekeys(0)->Dump, "\n";
# or an object:
# print STDERR "\n", Data::Dumper->new([\$schema],[qw(schema)])->Indent(1)->Quotekeys(0)->Dump, "\n";

    
    

