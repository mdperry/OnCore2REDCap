package Ecogps;

use base 'Exporter';
our @EXPORT_OK = 'extract_ecogps';
our @EXPORT    = 'extract_ecogps';
    
sub extract_ecogps {
    my $patient_id = shift @_;
    my %hash = %{shift @_};
    my $redcap = shift @_;
    my @fields_to_print = @{shift @_};
    my %exams = ();

=pod


=cut    

    my $screening = q{};
    my $progression = q{};
    my $event = q{};

    if ( $hash{SEGMENT} =~ m/Screening */ ) {
        $screening = '1';
        $event = 'pre_study_screen_arm_2-BLANK';
    }	
    elsif ( $hash{SEGMENT} =~ m/Progression/ ) {
        $progression = '1';
	$event = 'progression_arm_2-BLANK';
        # The screening data structure is already filled in but the progression
        # data structure needs to be initialized
        foreach my $field ( @fields_to_print ) {
            $redcap->{$patient_id}{$event}{$field} = undef;
	}
    }
    else {
        die "Found a SEGMENT in the ECOGPS OnCore Table that contains an error";
    }
    
    if ( $hash{ECOGPS} ) {
        my $prev_ecogps = $hash{ECOGPS};
        my ( $new_ecogps ) = $prev_ecogps =~ m/(\d) - \w+/;
        $redcap->{$patient_id}{$event}{ecog_value} = $new_ecogps; 
    }
	
    if ( $hash{VISIT_DATE} ) {
        my $ecog_date = iso_date( $hash{VISIT_DATE} );
        $redcap->{$patient_id}{$event}{date_ecog} = $ecog_date;
    }

    if ( $hash{WEIGHT} ) {
        $redcap->{$patient_id}{$event}{ecog_wt} = $hash{WEIGHT};
    }

    if ( $hash{BMI} ) {
        $redcap->{$patient_id}{$event}{ecog_bmi} = $hash{BMI};
    }

    $redcap->{$patient_id}{$event}{physical_exam_complete} = '2';
} # close sub

sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for patient $patient_id in Package Ecogps\n";
    }
    return $good_date;
} # close sub iso_date

1;

