package Diagnosis;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = 'extract_diagnosis';
our @EXPORT    = 'extract_diagnosis';
    

sub extract_diagnosis {
    my $patient_id = shift @_;
    my %hash = %{shift @_};
    my $redcap = shift @_;
    
    # Before we ever process a diagnostic table row, we should have already
    # processed all of the demographics rows, which means that all of these
    # hash keys I want to fill in in this code block were already created 
    # in the %redcap data structure
    
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
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for a patient in Package Diagnosis\n";
    }
    return $good_date;
} # close sub iso_date

1;

