package Postbiopsy;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw(extract_postbx_tx add_progression_dates);
our @EXPORT    = qw(extract_postbx_tx add_progression_dates);
use Date::Calc qw ( Delta_Days );

sub add_progression_dates {
    my $patient_id = shift @_;
    my %records = %{shift @_};
    my $timespan = shift @_;
    
    if ( $records{ProgressionDate} ) {
        my $date = iso_date( $records{ProgressionDate} );
        push @{$timespan->{$patient_id}{txprogdates}}, $date;
    }
    
} # close sub


sub extract_postbx_tx {
    my $patient_id = shift @_;
    my %hash = %{shift @_};
    my $redcap = shift @_;
    my @fields_to_print = @{shift @_};
    my %red_drug_names = %{shift @_};
    my $timespans = shift @_;
    my $event = q{};
    my $clinical_trial = q{};

    if ( $hash{TreatmentCategory} ) {
        if ( $hash{TreatmentCategory} eq 'Clinical Trial' ) {
            $clinical_trial = '1';
	}
    }

    my $tx_start = q{};
    if ( $hash{START_DATE} ) {
        $tx_start = iso_date( $hash{START_DATE} );
    }

    if ( exists $timespans->{$patient_id} ) {
        if ( $timespans->{$patient_id}{max} eq 'baseline' ) {
            $event = 'initiation_of_post_arm_2-postbiopsy_therapy';
	}
	else {
	    # max must be either progression_1, progression_2, or progression_3
	    # There may, or may not, be a progression biopsy. In other words, patients can
	    # progress, but my never have had a progression biopsy
	    # so the first test is to see if there are any other biopsy dates in
	    # the %timespans hash
	    if ( exists $timespans->{$patient_id}{biopsy_dates} ) {
                my @biopsy_dates = sort @{$timespans->{$patient_id}{biopsy_dates}};
                if ( scalar( @biopsy_dates < 1 ) ) {
                    # max is not baseline, but there are no elements in the biopsy_dates array
		    # so there was one or more progression events, but zero progression biopsies
		    # Therefore ALL post-bx-tx have to be post-baseline biopsy dates
                    $event = 'initiation_of_post_arm_2-postbiopsy_therapy';
		}
                if ( scalar( @biopsy_dates ) == 1 ) {
                    # there is one progression biopsy date
                    my ( $year1, $month1, $day1 ) = split /-/, $tx_start;
                    my ( $year2, $month2, $day2 ) = split /-/, $biopsy_dates[0];
                    # print STDERR "\$tx_start contains $tx_start\n\$biopsy_dates[0] contains $biopsy_dates[0]\n";
             	    my $days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2);
                    # If this post-biopsy treatment record occurred BEFORE the date of
		    # The progression biopsy, then this has to be a post-baseline biopsy tx
		    if ( $days > -1 ) {
                        $event = 'initiation_of_post_arm_2-postbiopsy_therapy';
		    }
		    else {
			# otherwise this treatment occurred AFTER the progression biopsy
			# and therefore has to be a post-biopsy_2 tx
                        $event = 'initiation_of_post_arm_2b-postbiopsy_therapy';
		    }
		}
                elsif ( scalar( @biopsy_dates ) > 1 ) {
                    # there are two, or more, progression biopsy dates
                    my ( $year1, $month1, $day1 ) = split /-/, $tx_start;
                    my ( $year2, $month2, $day2 ) = split /-/, $biopsy_dates[0];
             	    my $days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2);
                    # If this post-biopsy treatment record occurred BEFORE the date of
		    # The first progression biopsy, then this has to be a post-baseline biopsy tx
		    if ( $days > -1 ) {
                        $event = 'initiation_of_post_arm_2-postbiopsy_therapy';
 		    }
		    else {
                        my ( $year1, $month1, $day1 ) = split /-/, $tx_start;
                        my ( $year2, $month2, $day2 ) = split /-/, $biopsy_dates[1];
             	        my $days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2);
                        # If this post-biopsy treatment record occurred BEFORE the date of
		        # The second progression biopsy, then this has to be a post-biopsy_2 tx
		        if ( $days > -1 ) {
                            $event = 'initiation_of_post_arm_2b-postbiopsy_therapy';
		        }
		        else {
			    # otherwise this treatment occurred AFTER the second progression biopsy
			    # and therefore has to be a post-progression 2 biopsy tx
                            $event = 'initiation_of_post_arm_2c-postbiopsy_therapy';
		        }
		    }
		} # close inner if/else test
	    } # close if biopsy dates array
	} # close outer if/else test
    } # close if test to see if this record's patient_id is in the %timespans hash

    
    # Q: For this patient_id, how many rows from the subsequent treatment (a.k.a. post-biopsy therapy)
    # table have we already processed?
    my $instance = q{};
    # A: Count the number of defined elements in this array
    if ( $redcap->{$patient_id}{$event} ) {
        my $value = scalar( keys %{$redcap->{$patient_id}{$event}} );
        # if the array has any elements then add '1' to that number, and that will
        # become the number of the current instance we are processing
        $instance = $value + 1;
    }
    else {
        # otherwise, this MUST be the very first instance, so number it thusly:
        $instance = 1;
    } # close if/else test
    # initialize all of the hash keys for this record in the data structure
    foreach my $field ( @fields_to_print ) {
        $redcap->{$patient_id}{$event}{$instance}{$field} = undef;
    } # close foreach loop

    my %treatments = ( pre_tx_cat_v2___1 => "0",
                       pre_tx_cat_v2___2 => "0",
                       pre_tx_cat_v2___3 => "0",
                       pre_tx_cat_v2___4 => "0",
                       pre_tx_cat_v2___5 => "0",
                       pre_tx_cat_v2___6 => "0",
                       uncategorized     => "1",
                      );

    my %drug_category = (
        # Bicalutamide, or Casodex:
        "CHEBI:3090" => "pre_tx_cat_v2___1",
        # Carboplatin
        "CHEBI:31355" => "pre_tx_cat_v2___3",
        # Cyclophosphamide
        "CHEBI:4027" => "pre_tx_cat_v2___3",
        # A Special name for Cyclophosphamide
        "Cytoxan" => "pre_tx_cat_v2___3",
        # Tamoxifen
        "CHEBI:41774" => "pre_tx_cat_v2___4",
        # Taxol
        "CHEBI:45863" => "pre_tx_cat_v2___3",
        # Ketoconazole
	"CHEBI:48339" => "pre_tx_cat_v2___1",
	# Etoposide
	"CHEBI:4911" => "pre_tx_cat_v2___3",
	# Vandetanib
	"CHEBI:49960" => "pre_tx_cat_v2___4",
	# Estrogen
	"CHEBI:50114" => "pre_tx_cat_v2___1",
	# Rosiglitazone
	"CHEBI:50122" => "pre_tx_cat_v2___1",
	# Proscar
	"CHEBI:5062" => "pre_tx_cat_v2___1",
	# Mitoxantrone
	"CHEBI:50729" => "pre_tx_cat_v2___3",
	# Flutamide
	"CHEBI:5132" => "pre_tx_cat_v2___1",
	# Avodart, or Dutasteride
	"CHEBI:521003" => "pre_tx_cat_v2___1",
	# Docetaxel
	"CHEBI:59809" => "pre_tx_cat_v2___3",
	# Itraconazole
	# "CHEBI:6076" => "BLANK",
	# Leuprolide
	"CHEBI:6427" => "pre_tx_cat_v2___1",
	"Gleevec" => "pre_tx_cat_v2___4",
	"RADIUM CHLORIDE RA-223 Injectable Solution" => "pre_tx_cat_v2___6",
	"Triptorelin" => "pre_tx_cat_v2___1",
	"abiraterone" => "pre_tx_cat_v2___2",
	"cabazitaxel" => "pre_tx_cat_v2___3",
	"cabozantinib" => "pre_tx_cat_v2___4",
	"dasatinib" => "pre_tx_cat_v2___4",
	"degarelix" => "pre_tx_cat_v2___1",
	"enzalutamide" => "pre_tx_cat_v2___2",
	"everolimus" => "pre_tx_cat_v2___4",
	"goserelin" => "pre_tx_cat_v2___1",
	"ibrutinib" => "pre_tx_cat_v2___4",
	"ipilimumab" => "pre_tx_cat_v2___5",
	"nilutamide" => "pre_tx_cat_v2___1",
	"olaparib" => "pre_tx_cat_v2___4",
	"panobinostat" => "pre_tx_cat_v2___4",
	"pazopanib" => "pre_tx_cat_v2___4",
	"sipuleucel-T" => "pre_tx_cat_v2___5",
	"ARN-509" => "pre_tx_cat_v2___1",
	"ARN509" => "pre_tx_cat_v2___1",
	"BKM120" => "pre_tx_cat_v2___4",
	"GM-CSF" => "pre_tx_cat_v2___5",
	"PX-866" => "pre_tx_cat_v2___4",
	"TAK-700" => "pre_tx_cat_2___1", 
	"Cixutumumab" => "pre_tx_cat_v2___5",
	"PROSTVAC-VF" => "pre_tx_cat_v2___5",
	"Ribociclib" => "pre_tx_cat_v2___4",
	"LEE011" => "pre_tx_cat_v2___4",
	"BMN-673" => "pre_tx_cat_v2___4",
	"CC-115" => "pre_tx_cat_v2___4",
	"MEK-162" => "pre_tx_cat_v2___4",
	"MLN8237" => "pre_tx_cat_v2___4",
	"Selinexor" => "pre_tx_cat_v2___4",
	"Trametinib" => "pre_tx_cat_v2___4",
	"ZEN-3694" => "pre_tx_cat_v2___4",
	"CHEBI:28876"	=> "pre_tx_cat_v2___3",
	"Diethylstilbestrol" => "pre_tx_cat_v2___1",
        "BEZ235" => "pre_tx_cat_v2___4",
        "Estradiol" => "pre_tx_cat_v2___1",
        "Estraidol" => "pre_tx_cat_v2___1",
        "Buserelin" => "pre_tx_cat_v2___1",
        "CP-751871" => "pre_tx_cat_v2___5",
        "Cyproterone" => "pre_tx_cat_v2___1",
        "ES414" => "pre_tx_cat_v2___5",
        # Cisplatin
        "CHEBI:27899" => "pre_tx_cat_v2___3",
    );

    my $pre_drug_name_v2 = q{};
    my $pre_drug_id_v2 = q{};
    my $drug_name_available_2 = q{};
    my $prednisone = q{};
    my $drug_name_specific_2 = q{};
    my %parsed_drugs = (     dron => undef,
                         specific => undef,
                          details => undef,
                       );
    my $tx_details_drug_name = q{};
    my $tx_details_drug_id = q{};

    my $has_treatment_details = '0';
    my $treatment_details = q{};

    if ( $hash{TREATMENT_DETAILS} ) {
        $has_treatment_details = '1';
        $treatment_details = $hash{TREATMENT_DETAILS};
        $parsed_drugs{details} = $treatment_details;
    }

    if ( !$hash{DRUG_NAME} ) {
        next if $treatment_details =~ m/none/i;

        if ( $treatment_details =~ m/adiation|Gy|Brachy|roton|RT/ ) {
     	    # There is a non-DRUG Radiation treatment described in the TREATMENT_DETAILS field
	    # in OnCore.  
            $treatments{pre_tx_cat_v2___6} = "1";
            $treatments{uncategorized} = "0";
        } 
        elsif ( $red_drug_names{$treatment_details} ) {
            # There is a real live DRON Drug name sitting by itself
 	    # in the TREATMENT_DETAILS column, and nobody entered it in the
    	    # correct location in OnCore So this should be a dron, right?
            $tx_details_drug_id = $red_drug_names{$treatment_details};
            push @{$parsed_drugs{dron}}, { name => $treatment_details, id => $tx_details_drug_id, };
        }           
        elsif ( $treatment_details =~ m/ADT/ ) {
            $treatments{pre_tx_cat_v2____1} = "1";
            $treatments{uncategorized} = "0";
        }
        elsif ( $treatment_details =~ m/chemo/i ) {
            $treatments{pre_tx_cat_v3____3} = "1";
            $treatments{uncategorized} = "0";
        }
        elsif ( $treatment_details =~ m/PSMA/ ) {
            $tx_details_drug_name = 'ES414';
   	    # So the free text in TREATMENT_DETAILS says something regarding
   	    # PSMA, but the drug name that has a treatment category is
  	    # named ES414, so that is how we find the category
 	    # N.B. ES414 is NOT in the DRON, right?
            if ( $drug_category{$tx_details_drug_name} ) {
                $treatments{$drug_category{$tx_details_drug_name}} = '1';
                $treatments{uncategorized} = '0';
            }
        }
        elsif ( $treatment_details =~ m/3694/ ) {
            $tx_details_drug_name = 'ZEN-3694';
            if ( $drug_category{$tx_details_drug_name} ) {
                $treatments{$drug_category{$tx_details_drug_name}} = '1';
                $treatments{uncategorized} = '0';
            }
        } 
        elsif ( $red_drug_names{(split /\s/, $treatment_details)[0]} ) {
            $tx_details_drug_name = (split /\s/, $treatment_details)[0];
            $tx_details_drug_id = $red_drug_names{$tx_details_drug_name};
            push @{$parsed_drugs{dron}}, { name => $tx_details_drug_name, id => $tx_details_drug_id, };
        }
        elsif ( $red_drug_names{ (split /\s/, $treatment_details)[-1]} ) {
            $tx_details_drug_name = (split /\s/, $hash{TREATMENT_DETAILS})[-1];
            $tx_details_drug_id = $red_drug_names{$tx_details_drug_name};
            push @{$parsed_drugs{dron}}, { name => $tx_details_drug_name, id => $tx_details_drug_id, };
        }
    } # close if (!$hash{DRUG_NAME})
    else {
        my @pre_drugs = split(/; |\//, $hash{DRUG_NAME});
        my $number_of_drugs = scalar( @pre_drugs );

        if ( $clinical_trial ) {
            if ( $number_of_drugs > 1 ) {
                if ( grep { /prednisone/i } @pre_drugs ) {
                    # remove Prednisone from the list of drug names
                    ( @pre_drugs ) = grep { !/prednisone/i } @pre_drugs;
                    # and reduce the number_of_drugs by 1
                    $number_of_drugs--; 
                }
            } # close if test
        }
        else {
            if ( $number_of_drugs > 1 ) {
                if ( grep { /prednisone|dexamethasone|hydrocortisone/i } @pre_drugs ) {
                    # remove Prednisone from the list of drug names
                    ( @pre_drugs ) = grep { !/prednisone|dexamethasone|hydrocortisone/i } @pre_drugs;
                    # and reduce the number_of_drugs by 1
                    $number_of_drugs--; 
                }
            } # close if test
        }

        if ( $number_of_drugs > 1 ) {
            $redcap->{$patient_id}{'initiation_of_post_arm_2-postbiopsy_therapy'}{$instance}{combo_drug_v2} = 1;
        }

        foreach my $name ( @pre_drugs ) {
           if ( $red_drug_names{$name} ) {
               push @{ $parsed_drugs{dron} }, { name => $name, id => $red_drug_names{$name}, };
           }
           else {
               push @{ $parsed_drugs{specific} }, $name;
           }
       }
    } # close else block test of if ( !$hash{DRUG_NAME} ) Moved up here from down below

    my $number_of_dron = '0';
    my $number_of_specific = '0';

    if ( $parsed_drugs{dron} ) {
        $number_of_dron = scalar( @{ $parsed_drugs{dron} } );
    }

    if ( $parsed_drugs{specific} ) {
        $number_of_specific = scalar(@{$parsed_drugs{specific}});
    }
    
    if ( $number_of_dron ) {
        foreach my $drug ( @{ $parsed_drugs{dron} } ) {
            $pre_drug_name_v2 = $drug->{name};
	    $pre_drug_id_v2 = $drug->{id};
	    $drug_name_specific_2 = $pre_drug_name_v2 . ' = ' . $pre_drug_id_v2 . '; ';
            if ( $drug_category{$pre_drug_id_v2} ) {
                $treatments{$drug_category{$pre_drug_id_v2}} = '1';
                $treatments{uncategorized} = '0';
            }
        } # close foreach loop
    } # close if test

    if ( $number_of_specific ) {
        foreach my $specific ( @{ $parsed_drugs{specific} } ) {
            if ( $drug_category{$specific} ) {
                $treatments{$drug_category{$specific}} = '1';
                $treatments{uncategorized} = '0';
            }
        } # close foreach loop
        $drug_name_specific_2 .= join( '; ', @{$parsed_drugs{specific}} );
    } # close if test

    $redcap->{$patient_id}{$event}{$instance}{drug_name_available_2___1} = 0;

    if ( $has_treatment_details ) {
        $drug_name_specific_2 .= " $treatment_details" unless $drug_name_specific_2 =~ m/$treatment_details/;
    }
	
    if ( $drug_name_specific_2 ) {
        $redcap->{$patient_id}{$event}{$instance}{drug_name_available_2___1} = 1;    
        $redcap->{$patient_id}{$event}{$instance}{drug_name_specific_2} = $drug_name_specific_2;
    }

    foreach my $cat ( sort keys %treatments ) {
        next if $cat eq 'uncategorized';
        $redcap->{$patient_id}{$event}{$instance}{$cat} = $treatments{$cat};
    } # close foreach loop

    if ( $redcap->{$patient_id}{$event}{$instance}{pre_tx_cat_v2___1} ) {
        if ( $hash{START_DATE} ) {
 	    my $start_date = iso_date( $hash{START_DATE} );
            $redcap->{$patient_id}{$event}{$instance}{adt_start_v2} = $start_date;
        } 

        if ( $hash{STOP_DATE} ) {
            my $stop_date = iso_date( $hash{STOP_DATE} );
            $redcap->{$patient_id}{$event}{$instance}{adt_stop_v2} = $stop_date;
            $redcap->{$patient_id}{$event}{$instance}{adt_ongoing_v2} = '0';
        }
        else {
            $redcap->{$patient_id}{$event}{$instance}{adt_ongoing_v2} = '1';
        } # close if/else test

        if ( $hash{PSAnadir} ) {
            $redcap->{$patient_id}{$event}{$instance}{post_nadir_psa_adt} = $hash{PSAnadir};
        }
        else {
            $redcap->{$patient_id}{$event}{$instance}{post_nadir_psa_adt} = 'UNK';
        } # close inner if/else test
    } # close if ADT tx categories

    if ( $redcap->{$patient_id}{$event}{$instance}{pre_tx_cat_v2___2}
	     ||
         $redcap->{$patient_id}{$event}{$instance}{pre_tx_cat_v2___3}
	     ||
         $redcap->{$patient_id}{$event}{$instance}{pre_tx_cat_v2___4}
	     ||
         $redcap->{$patient_id}{$event}{$instance}{pre_tx_cat_v2___5}
	     ||
         $redcap->{$patient_id}{$event}{$instance}{pre_tx_cat_v2___6} ) {

        if ( $hash{START_DATE} ) {
	    my $start_date = iso_date( $hash{START_DATE} );		
            $redcap->{$patient_id}{$event}{$instance}{pre_tx_start_v2} = $start_date;
        }

        if ( $hash{STOP_DATE} ) {
            my $stop_date = iso_date( $hash{STOP_DATE} );
            $redcap->{$patient_id}{$event}{$instance}{pre_tx_stop_v2} = $stop_date;
            $redcap->{$patient_id}{$event}{$instance}{pre_tx_ongoing_v2} = '0';

            my %tx_stop_reasons = ( "Adverse Event" => '1',
                                    "Completed Treatment" => '2',
                                    "Progressive Disease" =>'3',
                                    "Physician Discretion" => '4',
                                    "Patient Demise" => '5',
                                    "Patient Choice" => '6',
                                    "Other" => '7',
                                   );

            if ( $hash{REASON_FOR_STOPPING_TREATMENT} ) {
                $redcap->{$patient_id}{$event}{$instance}{pre_tx_reason_v2} = $tx_stop_reasons{$hash{REASON_FOR_STOPPING_TREATMENT}};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{pre_tx_reason_v2} = '7';
            } # close if/else test

            if ( $hash{REASON_FOR_STOPPING_TREATMENT_} && $redcap->{$patient_id}{$event}{$instance}{pre_tx_reason_v2} == '7' ) { 
                $redcap->{$patient_id}{$event}{$instance}{other_stop_tx_v2} = $hash{REASON_FOR_STOPPING_TREATMENT_};
            } 
	    
            if ( $hash{BLPSA} ) {
                $redcap->{$patient_id}{$event}{$instance}{bl_psa_yn_v2} = '1';
                $redcap->{$patient_id}{$event}{$instance}{pre_tx_psa_bl_v2} = $hash{BLPSA};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{bl_psa_yn_v2} = '0';
            } # close if/else loop

            if ( $hash{PSAnadir} ) {
                $redcap->{$patient_id}{$event}{$instance}{nadir_psa_yn_v2} = '1';
                $redcap->{$patient_id}{$event}{$instance}{pre_tx_psa_nadir_v2} = $hash{PSAnadir};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{nadir_psa_yn_v2} = '0';
            } # close if/else test

            if ( $hash{PSAResponse} ) {
                $redcap->{$patient_id}{$event}{$instance}{psa_response_v2} = '1';

=pod
	    
                    my %red_psa_responses = ( "0-30%" => '1',
                                              "31-50%" => '2',
                                              "51-90%" => '3',
                                              ">91%" => '4',
                                            );

                    my %on_psa_responses = ( "No Decline" => '0',
                                             "0%-30%" => '1',
                                             "30%-50%" => '2',
                                             "50%-90%" => '3',
                                             ">90%"    => '4',
                                           );

=cut

                my %psa_responses = ( "No Decline" => '1',
                                          "0%-30%" => '1',
                                         "30%-50%" => '2',
                                         "50%-90%" => '3',
                                         ">90%"    => '4',
                                     );

                $redcap->{$patient_id}{$event}{$instance}{pre_tx_psa_response_v2} = $psa_responses{$hash{PSAResponse}};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{psa_response_v2} = '0';
            } # close if/else test
        } # close if ( $hash{STOP_DATE} )
        else {
            $redcap->{$patient_id}{$event}{$instance}{pre_tx_ongoing_v2} = '1';
        } # close if ( $hash{STOP_DATE} ) if/else test

        my %responses = ( 'CR' => '1',
                          'PR' => '2',
                          'PD' => '3',
                          'SD' => '4',
                          'N/A' => '5',
                         );
        if ( $hash{RECISTResponse} )  {
            $redcap->{$patient_id}{$event}{$instance}{pre_tx_resp_recist_v2} = $responses{$hash{RECISTResponse}};
        }

        if ( $hash{BoneResponse} ) {
            $redcap->{$patient_id}{$event}{$instance}{pre_tx_resp_bone_v2} = $responses{$hash{BoneResponse}};
        }
 
        my %prog_types = ( "Clinical" => 'pre_tx_pro_type_v2___1', 
                          "PSA" => 'pre_tx_pro_type_v2___3',
                          "Bone" => 'pre_tx_pro_type_v2___4',
                          "Soft Tissue" => 'pre_tx_pro_type_v2___5',
                          "Symptomatic" => 'pre_tx_pro_type_v2___6',
                          "Other" => 'pre_tx_pro_type_v2___7',
                          "Radiographic" => 'pre_tx_pro_type_v2___7',
                         );

        my %red_prog_types = ( "pre_tx_pro_type_v2___1" => '0',
                               "pre_tx_pro_type_v2___3" => '0',
                               "pre_tx_pro_type_v2___4" => '0',
                               "pre_tx_pro_type_v2___5" => '0',
                               "pre_tx_pro_type_v2___6" => '0',
                               "pre_tx_pro_type_v2___7" => '0',
                             );

        if ( $hash{IF_PROGRESSIVE_DISEASE_SPECIFY} ) {   
            my ( @on_prog ) = split( /; /, $hash{IF_PROGRESSIVE_DISEASE_SPECIFY} );
            foreach my $type ( @on_prog ) {
                $red_prog_types{$prog_types{$type}} = '1';
                if ( $type eq 'Radiographic' ) {
                    $redcap->{$patient_id}{$event}{$instance}{other_prog_disease_v2} = $type;
                }
            } # close foreach loop
        
            if ( $red_prog_types{pre_tx_pro_type_v2___7} ) {
                $redcap->{$patient_id}{$event}{$instance}{other_prog_disease_v2} = $hash{IF_OTHER_SPECIFY} unless $redcap->{$patient_id}{'initiation_of_post_arm_1-postbiopsy_therapy'}[$instance]{other_prog_disease_v2};
            } # close if test
            # N.B. There are records in OnCore where the
            # 'IF_PROGRESSIVE_DISEASE_SPECIFY' field is blank, yet the
            # 'IF_OTHER_SPECIFY' field contains a text description So, I
            # need to capture those as well
            if ( $hash{IF_OTHER_SPECIFY} && $red_prog_types{pre_tx_pro_type_v2___7} == 0 ) {
                $red_prog_types{pre_tx_pro_type_v2___7} = '1';
                $redcap->{$patient_id}{$event}{$instance}{other_prog_disease_v2} = $hash{IF_OTHER_SPECIFY};
            } # close if test

            foreach my $type ( sort keys %red_prog_types ) {
                $redcap->{$patient_id}{$event}{$instance}{$type} = $red_prog_types{$type};
            } # close foreach loop
        } # if ( $hash{IF_PROGRESSIVE_DISEASE_SPECIFY} ) test

        if ( $hash{ProgressionDate} ) {
 	    my $date = iso_date( $hash{ProgressionDate} );
            $redcap->{$patient_id}{$event}{$instance}{pre_tx_pro_date_v2} = $date;
        }

    } # close if/else test for if ( $redcap{pre_tx_cate___2 || 3 || 4 || 5 || 6 } )

    $redcap->{$patient_id}{$event}{$instance}{postbiopsy_therapy_complete} = 2;
} # close sub

sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for a patient in Package Postbiopsy\n";
    }
    return $good_date;
} # close sub iso_date

1;

