package Ecogps;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = 'extract_ecogps';
our @EXPORT    = 'extract_ecogps';
    
sub extract_ecogps {
    my $patient_id = shift @_;
    my %hash = %{shift @_};
    my $redcap = shift @_;
    my @fields_to_print = @{shift @_};
    my $ecog_dates = shift @_;

=pod


=cut    

    my $event = q{};
    my $element = q{};
    
    if ( $hash{SEGMENT} =~ m/Screening */ ) {
        # $screening = '1';
        $event = 'pre_study_screen_arm_2-physical_exam';
    }	
    elsif ( $hash{SEGMENT} =~ m/Progression/ ) {
        # Previous version, was dropping things
        # if ( scalar( @{$ecog_dates->{$patient_id}{Progression}} ) > 1 ) {
        if ( scalar( @{$ecog_dates->{$patient_id}{Progression}} ) > 0 ) {	    
            if ( exists $ecog_dates->{$patient_id}{count} ) {
                $element = $ecog_dates->{$patient_id}{count};
                $ecog_dates->{$patient_id}{count}++;
	    }
	    else {
                $element = 0;
                $ecog_dates->{$patient_id}{count}++;
	    }
	    if ( $element == 0 ) {
	        $event = 'progression_arm_2-physical_exam';
            }		
            elsif ( $element == 1 ) {
	        $event = 'progression_2_arm_2-physical_exam';           
	    }
	    elsif( $element == 2 ) {
 	        $event = 'progression_3_arm_2-physical_exam';           
	    }
        }
        # FYI: The previous version was dropping some progression ecogps test
	# Apparently that scalar array test never evaluates to 0
    }		


    # The screening data structure is already filled in but the progression
    # data structure needs to be initialized
    foreach my $field ( @fields_to_print ) {
        $redcap->{$patient_id}{$event}{1}{$field} = undef;
    }

    if ( $hash{ECOGPS} ) {
        my $prev_ecogps = $hash{ECOGPS};
        my ( $new_ecogps ) = $prev_ecogps =~ m/(\d) - \w+/;
        $redcap->{$patient_id}{$event}{1}{ecog_value} = $new_ecogps; 
    }
	
    if ( $hash{VISIT_DATE} ) {
        my $ecog_date = iso_date( $hash{VISIT_DATE} );
        $redcap->{$patient_id}{$event}{1}{date_ecog} = $ecog_date;
    }

    if ( $hash{WEIGHT} ) {
        $redcap->{$patient_id}{$event}{1}{ecog_wt} = $hash{WEIGHT};
    }

    if ( $hash{BMI} ) {
        $redcap->{$patient_id}{$event}{1}{ecog_bmi} = $hash{BMI};
    }

    $redcap->{$patient_id}{$event}{1}{physical_exam_complete} = '2';
} # close sub

sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for patient in Package Ecogps\n";
    }
    return $good_date;
} # close sub iso_date

1;

