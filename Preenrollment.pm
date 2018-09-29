package Preenrollment;

use base 'Exporter';
our @EXPORT_OK = 'extract_preenrollment_tx';
our @EXPORT    = 'extract_preenrollment_tx';
    
sub extract_preenrollment_tx {
    my $patient_id = shift @_;
    my %hash = %{shift @_};
    my $redcap = shift @_;
    my @fields_to_print = @{shift @_};
    my %red_drug_names = %{shift @_};

    # N.B.: This code DOES NOT aggregate preenrollment treatments that occurred on the
    # same date.  Each row in OnCore is treated as a completely separate event in REDCap
    # This is in contrast to how records with identical dates are handled in some of the
    # other ingested OnCore tables

    my $clinical_trial = q{};
    # corticosteroid treatments get dealt with differently in this OnCore table depending on
    # whether the patient was in a Clinical Trial
    if ( $hash{TreatmentCategory} ) {
        if ( $hash{TreatmentCategory} eq 'Clinical Trial' ) {
            $clinical_trial = '1';
        }
    }
	
    # Q: For this patient_id, how many rows (records) from the OnCore preenrollment therapy 
    # table have we already processed (if any)?
    my $instance = q{};
    if ( $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'} ) {
        # A: Count the number of hash keys at this level in the master data structure I am building:
        my $value = scalar( keys %{$redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}} );
        # if there are any keys then add '1' to that number, and that will
        # become the number of the current OnCore/REDCap instance being processed
        $instance = $value + 1;
    }
    else {
        # otherwise, the current record we are processing MUST be the very first instance, 
        # so number it thusly:
        $instance = 1;
    } # close if/else test

    # initialize all of the variables for the current preenrollment instrument
    foreach my $field ( @fields_to_print ) {
        $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{$field} = undef;
    } # close foreach loop

    # initialize this storage bucket for the different treatment categories in REDCap
    # Since there can be up to three different types of drugs administered in a single
    # preenrolment treatment in OnCore, I DO want to keep a running aggregate of ALL
    # the different treatment categories used in the current record.
    my %treatments = ( pre_tx_cat___1 => "0",
                       pre_tx_cat___2 => "0",
                       pre_tx_cat___3 => "0",
                       pre_tx_cat___4 => "0",
                       pre_tx_cat___5 => "0",
                       pre_tx_cat___6 => "0",
                       uncategorized  => "1",
                     );

    my %drug_category = (
        # Bicalutamide, or Casodex:
        "CHEBI:3090" => "pre_tx_cat___1",
        # Carboplatin
        "CHEBI:31355" => "pre_tx_cat___3",
        # Cyclophosphamide
        "CHEBI:4027" => "pre_tx_cat___3",
        # A Special name for Cyclophosphamide
        "Cytoxan" => "pre_tx_cat___3",
        # Tamoxifen
        "CHEBI:41774" => "pre_tx_cat___4",
        # Taxol
        "CHEBI:45863" => "pre_tx_cat___3",
        # Ketoconazole
        "CHEBI:48339" => "pre_tx_cat___1",
        # Etoposide
        "CHEBI:4911" => "pre_tx_cat___3",
        # Vandetanib
        "CHEBI:49960" => "pre_tx_cat___4",
        # Estrogen
        "CHEBI:50114" => "pre_tx_cat___1",
        # Rosiglitazone
        "CHEBI:50122" => "pre_tx_cat___1",
        # Proscar
        "CHEBI:5062" => "pre_tx_cat___1",
        # Mitoxantrone
        "CHEBI:50729" => "pre_tx_cat___3",
        # Flutamide
        "CHEBI:5132" => "pre_tx_cat___1",
        # Avodart, or Dutasteride
	"CHEBI:521003" => "pre_tx_cat___1",
	# Docetaxel
	"CHEBI:59809" => "pre_tx_cat___3",
	# Itraconazole
	# "CHEBI:6076" => "NOT SURE",
	# Leuprolide
	"CHEBI:6427" => "pre_tx_cat___1",
	# Prednisone
	# "CHEBI:8382" => "BLANK",
	"Gleevec" => "pre_tx_cat___4",
	"RADIUM CHLORIDE RA-223 Injectable Solution" => "pre_tx_cat___6",
	"Triptorelin" => "pre_tx_cat___1",
	"abiraterone" => "pre_tx_cat___2",
	"cabazitaxel" => "pre_tx_cat___3",
	"cabozantinib" => "pre_tx_cat___4",
	"dasatinib" => "pre_tx_cat___4",
	"degarelix" => "pre_tx_cat___1",
	# "denosumab" => "BLANK",
	"enzalutamide" => "pre_tx_cat___2",
	"everolimus" => "pre_tx_cat___4",
	"goserelin" => "pre_tx_cat___1",
	"ibrutinib" => "pre_tx_cat___4",
	"ipilimumab" => "pre_tx_cat___5",
	"nilutamide" => "pre_tx_cat___1",
	"olaparib" => "pre_tx_cat___4",
	"panobinostat" => "pre_tx_cat___4",
	"pazopanib" => "pre_tx_cat___4",
	# "placebo" => "BLANK",
	"sipuleucel-T" => "pre_tx_cat___5",
	# "zoldronic acid" => "BLANK",
	"ARN-509" => "pre_tx_cat___1",
	"ARN509" => "pre_tx_cat___1",
	"BKM120" => "pre_tx_cat___4",
	"GM-CSF" => "pre_tx_cat___5",
	"PX-866" => "pre_tx_cat___4",
	"TAK-700" => "pre_tx_cat___1", 
	# "GTx-758" => "BLANK",
	# "NRX 194204" => "BLANK",
	"Cixutumumab" => "pre_tx_cat___5",
	# "Custirsen" => "BLANK",
	# "OGX-427" => "BLANK",
	# "pTVG-HP" => "BLANK",
	"PROSTVAC-VF" => "pre_tx_cat___5",
	# "Reolysin" => "BLANK",
	"Ribociclib" => "pre_tx_cat___4",
	"LEE011" => "pre_tx_cat___4",
	"BMN-673" => "pre_tx_cat___4",
        "CC-115" => "pre_tx_cat___4",
        "MEK-162" => "pre_tx_cat___4",
        "MLN8237" => "pre_tx_cat___4",
        "Selinexor" => "pre_tx_cat___4",
        "Trametinib" => "pre_tx_cat___4",
        "ZEN-3694" => "pre_tx_cat___4",
        # Alkeran | Melphalan
        "CHEBI:28876" => "pre_tx_cat___3",
        # "Phenelzine" => "BLANK",
        "Diethylstilbestrol" => "pre_tx_cat___1",
        # "ATN-224" => "BLANK",
        "BEZ235" => "pre_tx_cat___4",
        "Estradiol" => "pre_tx_cat___1",
        "Estraidol" => "pre_tx_cat___1",
        "Buserelin" => "pre_tx_cat___1",
        "CP-751871" => "pre_tx_cat___5",
        # Vitamin D
        # "CHEBI:17823" => "BLANK",
        "Cyproterone" => "pre_tx_cat___1",
        "ES414" => "pre_tx_cat___5",
        # "Galeterone" => "BLANK",
        # "PTK-787" => "BLANK",
        # "NDGA" => "BLANK",
        # "SB939" => "BLANK",
        # "VT-464" => "BLANK",
        # Cisplatin
        "CHEBI:27899" => "pre_tx_cat___3",
    );
	
    my $pre_drug_name = q{};
    my $pre_drug_id = q{};
    my $drug_name_available = q{};
    my $prednisone = q{};
    my $drug_name_specific = q{};
    my %parsed_drugs = ( dron => undef,
                         specific => undef,
                         details => undef,
                       );
    my $has_treatment_details = '0';
    my $treatment_details = q{};

    # sometimes when the DRUG_NAMES field in an OnCore record is empty, an
    # actual drug name has been entered in the TREATMENT_DETAILS field for that 
    # record instead so I am probably going to need a variable to hold this information
    my $tx_details_drug_name = q{};
    my $tx_details_drug_id = q{};

    # I know this is a little bloated but I want to remind myself later
    if ( $hash{TREATMENT_DETAILS} ) {
        $has_treatment_details = '1';
	$treatment_details = $hash{TREATMENT_DETAILS};
        $parsed_drugs{details} = $treatment_details;
    }
	
    # There are some rows in the incoming OnCore table that lack an 
    # entry in the DRUG_NAME field, and I need to deal properly with them
    if ( !$hash{DRUG_NAME} ) {
        next if $treatment_details =~ m/none/i;
        # To get to this point they are missing a DRUG_NAME, and have
        # some kind of possibly relevant text string in the
        # TREATMENT_DETAILS field, and we need to see if we can
        # categorize them.  There are essentially three options,
        # first, it could be a radiation treatment.  Second it could
        # be a kind or type of drug treatment that for some reason
        # they decided not to enter in the DRUG_NAME field (don't ask
        # me why, I am just telling you what I found). Third, it could
        # be some other kind of treatment that is not easily
        # classified.

        # N.B.: All of these sequential tests are mutually exclusive. I based that on
        # my visual inspection of all the different categories of TREATMENT_DETAILS strings
        # in this field of the OnCore table.  I grouped and categorized the free text possibilities
        # And then after determining that they were exclusive I created regex patterns
        # that would crudely let me determine the correct category

        if ( $treatment_details =~ m/adiation|Gy|Brachy|roton|RT/ ) {
            # This record contains some kind of radiation treatment (instead of a drug)
            # Even if DRUG_NAME is empty, which it is, then we can
            # (A.) capture these TREATMENT_DETAILS in the field as if
            # it WAS a drug name--just one that is NOT in the DRON,
            # and (B.) we can assign it to the correct treatment category
            # Since we know which treatment category this is we don't
            # need to look it up later, I am setting the flags now:
            $treatments{pre_tx_cat___6} = "1";
            $treatments{uncategorized} = "0";
        } 
        elsif ( $red_drug_names{$treatment_details} ) {
            # Simplest case is if it is a regular DRON drug name that just
            # happened to be entered into the Wrong column
            $tx_details_drug_id = $red_drug_names{$treatment_details};
            push @{$parsed_drugs{dron}}, { name => $treatment_details, id => $tx_details_drug_id, };
        }           
        elsif ( $treatment_details =~ m/ADT/ ) {
                $treatments{pre_tx_cat____1} = "1";
                $treatments{uncategorized} = "0";
        }
        elsif ( $treatment_details =~ m/chemo/i ) {
            $treatments{pre_tx_cat____3} = "1";
            $treatments{uncategorized} = "0";
        }
        elsif ( $treatment_details =~ m/PSMA/ ) {
            $tx_details_drug_name = 'ES414';
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
        elsif ( $red_drug_names{(split /\s/, $treatment_details )[0]} ) {
            # Sometimes they put real drug names in this Other
            # category but the terms to check were either at the
            # beginning or end of the text strings
            $tx_details_drug_name = (split /\s/, $treatment_details )[0];
            $tx_details_drug_id = $red_drug_names{$tx_details_drug_name};
            push @{$parsed_drugs{dron}}, { name => $tx_details_drug_name, id => $tx_details_drug_id, };
        } # using '-1' to specify the very last element in a Perl array
        elsif ( $red_drug_names{(split /\s/, $treatment_details )[-1]} ) {
            $tx_details_drug_name = (split /\s/, $treatment_details )[-1];
            $tx_details_drug_id = $red_drug_names{$tx_details_drug_name};
            push @{$parsed_drugs{dron}}, { name => $tx_details_drug_name, id => $tx_details_drug_id, };
        } # close if/elsif/else many, many alternatives

=pod

Stop to think about this.  Thus far in the block I am processing records from the
OnCore prior_treatment table, and these are the subset of records where there is
no entry in the DRUG_NAME column.  If I have successfully extracted either a 
drug name, or at the very least a treatment category above, I am still proposing to 
concatentate values, right? But wait, how do I know there is even a value in the specific
branch of the %parsed_drugs hash?

            # Q: If we made it here, we were lacking a 'DRUG_NAME' but we had
	    # something in the 'TREATMENT_DETAILS'  That information in the
	    # 'TREATMENT_DETAILS' may have been a bona fide DRON drug name
	    # in which case there is nothing in the $parsed_drugs{specific} array
	    # or it may have been some other drug, either with or without a recognized
	    # drug category.  Okay, I think what I wanted to do here was add
	    # the TREATMENT_DETAILS, right?
            # previous version, possibly incorrect:
            # $drug_name_specific = $parsed_drugs{specific}[0];

	    # unless ( $parsed_drugs{specific} ) {
            #    $drug_name_specific = $hash{TREATMENT_DETAILS};
	    # }

	    # I "think" that is what I wanted to do.  If I had not stored the value in the
	    # TREATMENT_DETAILS anywhere then I want to make sure I capture it here (I think)

            # NEWEST VERSION:
#            if ( $tx_details_drug_name ) {
#                $drug_name_specific = $tx_details_drug_name;
#	    }

=cut

    } # close if ( !$hash{DRUG_NAME} )
    else {
        # This block is for the other of the two exclusive possiblities, where the current
        # OnCore record has an actual DRUG_NAME(s), 
        # N.B. Splitting on two possible patterns '; ' or '/'
        my @pre_drugs = split(/; |\//, $hash{DRUG_NAME});
        # How many drugs are named in this field for this treatment?
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
                    # remove (A.) Prednisone, (B.) Dexamethasone, or (C.) Hydrocortisone,
                    # from the list of drug names
                    ( @pre_drugs ) = grep { !/prednisone|dexamethasone|hydrocortisone/i } @pre_drugs;
                    # and reduce the number_of_drugs by 1
                    $number_of_drugs--; 
                }
            } # close if test
        }

        # At this point if Prednisone was one of the drugs listed in the OnCore table, it
        # has been stripped out.  The other two corticosteroid drug names have been removed
        # from regular records, but have been retained in records that comprise a Clinical Trial

        if ( $number_of_drugs > 1 ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{combo_drug} = 1;
        }

        foreach my $name ( @pre_drugs ) {
            # test each of the DRUG_NAMES coming in from OnCore to see
            # if they are in our list of DRON drug names
            if ( $red_drug_names{$name} ) {
                push @{ $parsed_drugs{dron} }, { name => $name, id => $red_drug_names{$name}, };
            }
            else {
   	        # Drugs missing from the %red_drug_names hash ARE NOT
		# in the DRON Ontology
                push @{ $parsed_drugs{specific} }, $name;
            } # close if/else test
        } # close foreach loop

    } # close else block from test of if ( !$hash{DRUG_NAME} )

=pod

This is the nexus, or junction where the two mutually exclusive streams up above come back together
And the data structure gets filled in for both types of records, both those with, as well as those
without a value in the DRUG_NAME field

=cut	
	    
    my $number_of_dron = '0';
    my $number_of_specific = '0';
	
    if ( $parsed_drugs{dron} ) {
        $number_of_dron = scalar( @{ $parsed_drugs{dron} } );
    }

    if ( $parsed_drugs{specific} ) {
        $number_of_specific = scalar( @{ $parsed_drugs{specific} } );
    }

    # for these next two blocks, I have ONLY included Drugs (both
    # drugs that are in DRON, as well as drugs that are NOT in DRON) 
    # that have defined drug treatment categories in the
    # %drug_category hash.  So, if, for example, Jaselle told me that
    # for a specific drug we were not going to categorize it, then I
    # made sure that drug name was not in the category hash.  This
    # should have the effect of leaving all of the '0's that I used
    # to preset the variable values in the %drug_category hash still set to '0'
    
    if ( $number_of_dron ) {
        foreach my $drug ( @{ $parsed_drugs{dron} } ) {
            $pre_drug_name = $drug->{name};
            $pre_drug_id = $drug->{id};
   	    $drug_name_specific .= $pre_drug_name . ' = ' . $pre_drug_id . '; ';
            if ( $drug_category{$pre_drug_id} ) {
                $treatments{$drug_category{$pre_drug_id}} = '1';
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
	$drug_name_specific .= join( '; ', @{$parsed_drugs{specific}} );
    } # close if test

    # Watch out, beware, the logic of this test is reversed, based on the variable name.  IF the DRUG is NOT in
    # the DRON, then you would check off this box, which means to give it the value '1', so by putting a
    # zero here you are saying 'Yes' I found this drug name in the DRON table/list
    $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{drug_name_available___1} = 0;   

    if ( $has_treatment_details ) {
        $drug_name_specific .= " $treatment_details";
    }
	    
    if ( $drug_name_specific ) {
        $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{drug_name_available___1} = 1;    
        $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{drug_name_specific} = $drug_name_specific;
    }

    # Now, iterate over the hopefully filled in treatments hash and
    # transfer the variables to the redcap hash values for this patient
    foreach my $cat ( sort keys %treatments ) {
        # make sure we skip the 'uncategorized' treatment since
        # that does not exist in REDCap
        next if $cat eq 'uncategorized';
        $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{$cat} = $treatments{$cat};
    } # close foreach loop

    # now, check to see if we need to fill in any of the 'extra'
    # fields in this REDCap instrument, based on the drug treatment 
    # categories for these drugs
    # This first block is if the drug(s) were part of an ADT:    
    if ( $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_cat___1} ) {
        if ( $hash{START_DATE} ) {
            my $start_date = iso_date( $hash{START_DATE} );
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{adt_start} = $start_date;
        } 

        if ( $hash{STOP_DATE} ) {
            my $stop_date = iso_date( $hash{STOP_DATE} );
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{adt_stop} = $stop_date;
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{adt_ongoing} = '0';
        }
        else {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{adt_ongoing} = '1';
        }

        if ( $hash{PSAnadir} ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{nadir_psa_adt} = $hash{PSAnadir};
        }
        else {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{nadir_psa_adt} = 'UNK';
        } # close inner if/else test
    } # close if any of the drugs were ADT drugs
	
    if ( $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_cat___2} 
	     ||
         $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_cat___3}
	     ||
         $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_cat___4}
	     ||
         $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_cat___5}
	     ||
         $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_cat___6} ) {
        
        if ( $hash{START_DATE} ) {
	    my $start_date = iso_date( $hash{START_DATE} );
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_start} = $start_date;
        }
	    
        if ( $hash{STOP_DATE} ) {
            my $stop_date = iso_date( $hash{STOP_DATE} );
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_stop} = $stop_date;
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_ongoing} = '0';
            # When you select '0' which is interpreted as 'No' in this
            # context, then additional fields can be filled in:
            my %tx_stop_reasons = ( "Adverse Event" => '1',
                                    "Completed Treatment" => '2',
                                    "Progressive Disease" =>'3',
                                    "Physician Discretion" => '4',
                                    "Patient Demise" => '5',
                                    "Patient Choice" => '6',
                                    "Other" => '7',
                                  );

            if ( $hash{REASON_FOR_STOPPING_TREATMENT} ) {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_reason} = $tx_stop_reasons{$hash{REASON_FOR_STOPPING_TREATMENT}};
            }
            else {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_reason} = '7';
            } # close if/else test

            if ( $hash{REASON_FOR_STOPPING_TREATMENT_} && $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_reason} == '7' ) {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{other_stop_tx} = $hash{REASON_FOR_STOPPING_TREATMENT_};
            } 
            
            if ( $hash{BLPSA} ) {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{bl_psa_yn} = '1';
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_psa_bl} = $hash{BLPSA};
            }
            else {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{bl_psa_yn} = '0';
            } # close if/else test

            if ( $hash{PSAnadir} ) {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{nadir_psa_yn} = '1';
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_psa_nadir} = $hash{PSAnadir};
            }
            else {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{nadir_psa_yn} = '0';
            } # close if/else test

            if ( $hash{PSAResponse} ) {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{psa_response} = '1';

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

                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_psa_resp} = $psa_responses{$hash{PSAResponse}};
            }
            else {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{psa_response} = '0';
            } # close innermost if/else test
        }
        else {
            # Get that? If there is no STOP_DATE in OnCore THEN we are assuming that the treatment
  	    # is by definition, OnGoing.  Therefore we will not enter a '01' to indicate a missing date
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_ongoing} = '1';
        } # close inner if/else test

        my %responses = ( 'CR' => '1',
                          'PR' => '2',
                          'PD' => '3',
                          'SD' => '4',
                          'N/A' => '5',
                         );
	    
        if ( $hash{RECISTResponse} )  {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_resp_recist} = $responses{$hash{RECISTResponse}};
        }

        if ( $hash{BoneResponse} ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_resp_bone} = $responses{$hash{BoneResponse}};
        }
 
        my %prog_types = ( "Clinical" => 'pre_tx_pro_type___1', 
                           "PSA" => 'pre_tx_pro_type___3',
                           "Bone" => 'pre_tx_pro_type___4',
                           "Soft Tissue" => 'pre_tx_pro_type___5',
                           "Symptomatic" => 'pre_tx_pro_type___6',
                           "Other" => 'pre_tx_pro_type___7',
                           "Radiographic" => 'pre_tx_pro_type___7',
                         );

        my %red_prog_types = ( "pre_tx_pro_type___1" => '0',
                               "pre_tx_pro_type___3" => '0',
                               "pre_tx_pro_type___4" => '0',
                               "pre_tx_pro_type___5" => '0',
                               "pre_tx_pro_type___6" => '0',
                               "pre_tx_pro_type___7" => '0',
                             );

        if ( $hash{IF_PROGRESSIVE_DISEASE_SPECIFY} ) {   
            # If there is, then capture the different terms into an array
            # (there may only be one term in many cases, but there can be
            # up to 3 terms
            my ( @on_prog ) = split( /; /, $hash{IF_PROGRESSIVE_DISEASE_SPECIFY} );
            # iterate over the array and use the OnCore text string to
            # select the correct REDCap variable name from the %prog_types
            # hash
            foreach my $type ( @on_prog ) {
                # update the value for this REDCap variable in the 
                # %red_prog_types hash
                $red_prog_types{$prog_types{$type}} = '1';
                if ( $type eq 'Radiographic' ) {
                    $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{other_prog_disease} = $type;
                }
            } # close foreach loop
        
            if ( $red_prog_types{pre_tx_pro_type___7} ) {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{other_prog_disease} = $hash{IF_OTHER_SPECIFY} unless $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{other_prog_disease};
            } # close if test
            # N.B. There are records in OnCore where the
            # 'IF_PROGRESSIVE_DISEASE_SPECIFY' field is blank, yet the
            # 'IF_OTHER_SPECIFY' field contains a text description So, I
            # need to capture those as well
            if ( $hash{IF_OTHER_SPECIFY} && $red_prog_types{pre_tx_pro_type___7} == 0 ) {
                $red_prog_types{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_pro_type___7} = '1';
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{other_prog_disease} = $hash{IF_OTHER_SPECIFY};
            } # close if test

            foreach my $type ( sort keys %red_prog_types ) {
                $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{$type} = $red_prog_types{$type};
            } # close foreach loop
        } # close if ( $hash{IF_PROGRESSIVE_DISEASE_SPECIFY} )

        # finally there is a progression date in some cases in OnCore
        # and there is a corresponding variable in REDCap
        if ( $hash{ProgressionDate} ) {
            my $pre_tx_pro_date = iso_date( $hash{ProgressionDate} );
            $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{pre_tx_pro_date} = $pre_tx_pro_date;
        }
    } # close if/else test for if ( $redcap{pre_tx_cat___2 || 3 || 4 || 5 || 6} )     

    $redcap->{$patient_id}{'pre_study_screen_arm_2-preenrollment_therapy'}{$instance}{preenrollment_therapy_complete} = 2;
} # close sub

sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for patient $patient_id in Package Preenrollment\n";
# 	{
#            no strict 'refs';
#            for my $var (keys %{'main::'}) {
#                if ( defined ${'main::'}{$var} ) {
#                    print STDERR "$var\t${'main::'}{$var}\n";
#                }
#		else {
#                    print STDERR "$var\tundefined\n";
#		}
#            }
#        }
    }
    return $good_date;
} # close sub iso_date

1;

