package Additional;

use base 'Exporter';
our @EXPORT_OK = 'extract_additional';
our @EXPORT    = 'extract_additional';
    

sub extract_additional {
    my $patient_id = shift @_;
    my %hash = %{shift @_};
    my $redcap = shift @_;

    my $addnl_dx_mets_date = q{};
    my $addnl_dx_crpc_date = q{};
    my $addnl_date_of_mcrpc = q{};
    my $final_path_call = q{};
    my $serum_chga = q{};
    my $serum_nse = q{};
    my $addnl_site = q{};


=pod

Keep in Mind that almost all patients have at least a baseline sample, all except one
Therefore the code needs to be able to handle a singleton that is a Progression sample
in addition to all of the singleton Baselines.

If there is a Baseline and one or more Progression samples, and there are
Patients with up to 3 discrete, different Progression samples in the additional
Data Points table that I am processing, then certain values in the current record 
have to be entered into the appropriate, and relevant, repeating REDCap Instrument

I am referring mainly to these three:
my $final_path_call = q{};
my $serum_chga = q{};
my $serum_nse = q{};

2018-09-21 Rahul answered my most recent Email and explained that the dates in his spreadsheet should take precedence
Over the Data in OnCore (and four the four instances where I had a query, he said that he would get to those later). 
I am correct that the Progression and the Baseline samples should INDEED have the same three dates for both timepoint samples
So that means that don't really need to process any of the Progression Dates at this point in time, right?

So, working on the logic loop here, the first section of this module simply creates some new variables
And then fills these variables in with the corresponding incoming data (if that field has any data).

For those Serum Values there will not be anything entered, and at the moment there is no place to capture the 
SERUM_CHGA.
First question: Is the neuroendocrine collection instrument a repeating instrument?
These are the three fields that I need to fill in.
date_blood_draw
serum_value
serum_neuroendocrine_markers_complete

So I bopped over to REDCap and logged in to see the current DEMO that I created back in . . . August, 2018 (I think),
does that sound about right?
Very interesting.  I can collect serum_neurendocrine values at all of these following times:
During the Pre-Study, or Screening phase
As part of the Every 3 months phase
As part of the Biopsy 2 phase (but not at the Biopsy 1 phase or the Progression 1 phase)
NOT as part of Every 3 months at the Post-bx 2 phase (see how that does not make sense to me? Why collect
it in the Every 3 months phase, earlier, after the Biopsy 1 phase, but not after biopsy 2? (Biopsy 2
only occurs after a patient has undergone progression, right?).
As part of the Biopsy 3 phase
NOT as part of Every 3 months at the Post-bx 3 phase
As part of the Progression 3 phase

Okay, after looking at this, I need to print out a picture of this grid, I know
that I have done this before, but I want to make sure that I understand
all the different stages here, or whatever they are called.

One Patient has 2 (Two) Baseline specimen/sample/aliquots: DTB-095-BL
One Patient has no Baseline specimen/sample/aliquots, but does have
1 Progression specimen/sample/aliquot: DTB-123-Pro

How does my script handle those, as well? I am going to check on that.


=cut

    
    
    if ( $hash{'DateOfCR'} ) {
        $addnl_dx_crpc_date = $hash{'DateOfCR'};
    }

    if ( $hash{'DateOfFirstMetastases'} ) {
        $addnl_dx_mets_date = $hash{'DateOfFirstMetastases'};
    }

    if ( $hash{'DateofmCRPC'} ) {
        $addnl_date_of_mcrpc = $hash{'DateofmCRPC'};
    }

    if ( $hash{'FINAL_PATH_CALL'} ) {
        $final_path_call = $hash{'FINAL_PATH_CALL'};
    }

    if ( $hash{'SITES_OF_METS_AT_TIME_OF_BIOPSY'} ) {
        $addnl_sites = $hash{'SITES_OF_METS_AT_TIME_OF_BIOPSY'};
    }
 
    if ( $hash{'BIOPSY_SERUM_CHGA'} ) {
        $serum_chga = $hash{'BIOPSY_SERUM_CHGA'};
    }

    if ( $hash{'BIOPSY_SERUM_NSE'} ) {
        $serum_nse = $hash{'BIOPSY_SERUM_NSE'};
    }


=pod
    
    | SEQUENCE_NO_ | FORM_DESC_      | ALIQUOT_ID | SAMPLE_ID   | CASE_ID | SAMPLE_TYPE           | LEGACY_TYPE | PROGRESSION_NUMBER | BIOPSY_SITE | TIMEPOINT   | FINAL_PATH_CALL | SITES_OF_METS_AT_TIME_OF_BIOPSY | BIOPSY_SERUM_CHGA | BIOPSY_SERUM_NSE |   DateOfCR | DateOfFirstMetastases | DateofmCRPC |
|--------------+-----------------+------------+-------------+---------+-----------------------+-------------+--------------------+-------------+-------------+-----------------+---------------------------------+-------------------+------------------+------------+-----------------------+-------------|
|          021 | WCDT_Additional | DTB-021    | DTB-021-BL  | DTB-021 | Metastatic            | Baseline    |                  0 | Bone        | Baseline    | Small Cell      | Bone                            | 8                 |             10.6 | 2013-03-28 |            2013-05-31 |  2013-05-31 |
|          021 | WCDT_Additional | DTB-021Pro | DTB-021-Pro | DTB-021 | Additional Metastatic | Progression |                  1 | Bone        | Progression | Adenocarcinoma  | Bone                            | < 5               |             24.2 | 2013-03-28 |            2013-05-31 |  2013-05-31 |

dx_mets_date
dx_crpc_date
date_of_mcrpc




=cut
    


    my %disease_at_dx = ( "Localized" => "1",
                          "Metastatic" => "2",
                          "Unknown" => "3",
                        );
 
    if ( $hash{DISEASE_STATE_AT_DIAGNOSIS} ) {
        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_state} = $disease_at_dx{$hash{DISEASE_STATE_AT_DIAGNOSIS}};
    }
    else {
        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_state} = '3';
    } # close if/else test
    
    if ( $hash{PRIMARY_GLEASON_SCORE} ) {
        # 2018-07-16 Sometime between last December, and last Week, REDCap seems to have been updated
	# Such that it now throws an exception if you try it import a record where the values in one field fall
	# outside the range of accepted values (in this case it is a couple of radiobox selections)
	# Three patients in the OnCore diagnosis table have a Gleason of 9, which is probably a total
	# but which the form does not allow.  The only acceptable values for these next two fields are:
	# 2, 3, 4, or 5.  So my short-term solution is to throw away the value, but I will flag it for
	# the CRA's
        if ( $hash{PRIMARY_GLEASON_SCORE} > 1 and $hash{PRIMARY_GLEASON_SCORE} < 6 ) {
	    $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_primary} = $hash{PRIMARY_GLEASON_SCORE};
	}
    }

    if ( $hash{SECONDARY_GLEASON_SCORE} ) {
        if ( $hash{SECONDARY_GLEASON_SCORE} > 1 and $hash{SECONDARY_GLEASON_SCORE} < 6 ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_secondary} = $hash{SECONDARY_GLEASON_SCORE};
        }
    }
        if ( $hash{PSA_VALUE} ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_psa} = $hash{PSA_VALUE};
        }
        else {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_psa} = 'UNK';
        } # close if/else test

        if ( $hash{VISIT_DATE} ) {
            my $visit_date = iso_date( $hash{VISIT_DATE} );
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_date} = $visit_date;
        }

        my $mets_date = q{};
	my $crpc_date = q{};

        if ( $hash{DateofFirstMetastases} ) {
            $mets_date = iso_date( $hash{DateofFirstMetastases} );
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_mets_date} = $mets_date;
        }

        if ( $hash{DateofCRPC} ) {
	    $crpc_date = iso_date( $hash{DateofCRPC} );
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_crpc_date} = $crpc_date;
        }

=pod

There are four different types of entries in the next two fields in the incoming
OnCore table for Prostate Cancer Diagnosis:
1. Both blank which by this point means they are both '01', and you cannot say which one 
is "Most Recent" so I guess we will leave that blank for now?

2. There is a date of first metastases and the other column is blank
3. There is a date of CRPC and the other column is blank
4. Both have a date like this: MM-DD-YYYY

=cut

    if ( $mets_date && $crpc_date ) {
        my @dates = sort( $mets_date, $crpc_date, );
        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{date_of_mcrpc} = $dates[1];
    }
    elsif ( $hash{DateofFirstMetastases} ) {
        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{date_of_mcrpc} = $mets_date;
    }
    elsif ( $hash{DateofCRPC} ) {
        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{date_of_mcrpc} = $crpc_date;
    }
	
    $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{prostate_cancer_initial_diagnosis_complete} = '2';
} # close sub

sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for patient $patient_id in Package Diagnosis\n";
#	{
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

