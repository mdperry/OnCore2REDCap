package Demographics;

use base 'Exporter';
our @EXPORT_OK = 'extract_demographics';
our @EXPORT    = 'extract_demographics';

sub extract_demographics {
    my $patient_id = shift @_ ;
    my %hash = %{shift @_};
    my $redcap = shift @_;
    my @fields_to_print = @{ shift @_ }; 

    # initialize all of the REDCap field names for this patient for
    # the first row of the output table
    
    foreach my $field ( @fields_to_print ) {
        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{$field} = undef;
        $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{$field} = undef;
    } # close foreach loop

    # If the patient visited the hospital or clinic, then by definition this patient was alive on that date
    if ( $hash{LAST_VISIT_DATE} ) {
        my $last_visit_date = iso_date( $hash{LAST_VISIT_DATE} );
        $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{last_known_alive} = $last_visit_date;
    }
   
    # If there is a value in the CURRENT_STATUS field, and if it says EXPIRED
    # then the patient is no longer alive, so the script enters a '0' which
    # REDCap interprets as a 'No'	
    if ( $hash{CURRENT_STATUS} eq 'EXPIRED' ) {
        $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{track_alive} = '0';
	# I don't think I need to enter this twice so I am commenting it out for now
        # $redcap{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{track_reason} = '4';
    }
    # only enter this next block if the patient has expired
    # and therefore $redcap{track_alive} contains '0'
    # And this test will evaluate the value as 'FALSE'
    unless ( $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{track_alive} ) {
        if ( $hash{EXPIRED_DATE} ) {
            my $expired_date = iso_date( $hash{EXPIRED_DATE} );
            $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{track_death} = $expired_date;
        }
    } # close unless test

    if ( $hash{OFF_STUDY_DATE} ) {
        $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{pt_off_study} = '1';

        my $off_study = iso_date( $hash{OFF_STUDY_DATE} );
        $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{off_study_date} = $off_study;

        if ( $hash{CURRENT_STATUS} eq 'EXPIRED' ) {
            $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{track_reason} = '4';		
        }
        else {
            $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{track_reason} = '8';		
            $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{reason_off_study} = 'This information was not captured in OnCore';
        } # close inner if/else test
    }
    else {
        $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{pt_off_study} = '0';
    } # close outer if/else test
    $redcap->{$patient_id}{'patient_dispositio_arm_2-patient_disposition'}{'1'}{patient_disposition_complete} = '2';

    if ( $hash{INITIALS} ) {
        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{last_name} = $hash{INITIALS};
    }

    if ( $hash{BIRTH_DATE} ) {
       my $birth_date = iso_date( $hash{BIRTH_DATE} );
       $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{birth_date} = $birth_date;
    }

    if ( $hash{ON_STUDY_DATE} ) {
        my $on_study_date = iso_date( $hash{ON_STUDY_DATE} );
        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{on_study_date} = $on_study_date;
    }
	
    $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{study___1} = '1';
    $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{study___2} = '0';
    $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{study___3} = '0';

    my %site = ( "BC Cancer Agency" => "6", # UBC
                 "Knight Cancer Institute" => "2", # OHSU
                 "Mt. Zion" => "1", # UCSF
                 "University of California Davis" => "5", # UCD
                 "University of California Los Angeles" => "3", # UCLA
              );

    $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{institution} = $site{$hash{STUDY_SITE}};
    # NONE of the WCDT patients in OnCore had blood drawn and the data dictionary
    # said to enter this value which should translate to a 'No' in the REDCap form
    $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{opt_blood_draw} = '0';

        # This hash has the text entries from the OnCore demographics
        # tables for the different choices for RACE:
        my %race = ( "American Indian or Alaska Native" => '5',
                     "Asian" => '4',
                     "Black or African American" => '2',
                     "Unknown" => '6',
                     "White" => '1',
                   );
	
        # This hash has the text entries from the OnCore demographics
        # tables for the different choices for ETHNICITY, and 
        # the values are the codes from the REDCap Data Dictionary that
        # I inserted
        my %ethnicity = ( "Hispanic or Latino" => '1',
                          "Non-Hispanic" => '2',
                          "Unknown" => '3',
                        );
	
        if ( $race{$hash{RACE}} ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{race} = $race{$hash{RACE}};
        }
        else {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{race} = '6';
        } # close if/else test

        if ( $ethnicity{$hash{ETHNICITY}} ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{ethnicity} = $ethnicity{$hash{ETHNICITY}};
        }
        else {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{ethnicity} = '3';
        } # close if/else test

        $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{patient_enrollment_demographics_complete} = '2';
} # close sub
  

sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for patient $patient_id in Package Demographics\n";
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
