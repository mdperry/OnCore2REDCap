package Primary;

use base 'Exporter';
our @EXPORT_OK = 'extract_primary_tx';
our @EXPORT    = 'extract_primary_tx';
    

sub extract_primary_tx {
    my $patient_id = shift @_;
    my %hash = %{shift @_};
    my $redcap = shift @_;


    if ( $hash{RADICAL_PROSTATECTOMY} eq 'Yes' ) {
        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{prior_rp} = '1';
        if ( $hash{SURGERY_DATE} ) {
            my $surgery_date = iso_date( $hash{SURGERY_DATE} );
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{prior_rp_date} = $surgery_date;
        }
    }
    else {
        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{prior_rp} = '2';
    } # close outer if/else test

    if ( $hash{RADIATION_THERAPY} ) {
        if ( $hash{RADIATION_THERAPY} eq 'Yes' ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{prior_rad} = '1';
            if ( $hash{START_DATE4} ) {
	        my $start_date = iso_date( $hash{START_DATE4} );
                $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{prior_rad_start} = $start_date;
            }
            if ( $hash{STOP_DATE1} ) {
 	        my $stop_date = iso_date( $hash{STOP_DATE1} );
                $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{prior_rad_stop} = $stop_date;
            }
        }
        else {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{prior_rad} = '0';
        } # close outer if/else test
    }

    $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{primary_therapy_complete} = '2';
} # close sub

sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for patient $patient_id in Package Primary\n";
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


