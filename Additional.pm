package Additional;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = 'extract_additional';
our @EXPORT    = 'extract_additional';
use Date::Calc qw ( Delta_Days );    

sub extract_additional {
    my $patient_id = shift @_;
    my %hash = %{shift @_};
    my $redcap = shift @_;
    my $timespans = shift @_;
    my $updated = shift @_;
    my $seen = shift @_;
    
    my $addnl_dx_mets_date = q{};
    my $addnl_dx_crpc_date = q{};
    my $addnl_date_of_mcrpc = q{};
    my $current_path_call = q{};
    my $final_path_call = q{};
    # neuroendocrine_marker = CHROMOGRANIN
    my $serum_chga = q{};
    # neuroendocrine_marker = ENOLASE
    my $serum_nse = q{};
    my $addnl_sites = q{};
    my $timepoint = q{};
    my $instance = q{};
    my $serum_instance = q{};
    my $event = q{};
    my $serum_event = q{};
    
    # This hash is supposed to convert the variety of different FINAL_PATH_CALLS in Rahul's additional table
    # into one of the seven (nope, make that eight) acceptable CLIA calls that REDCap allows
    # 1, Adenocarcinoma | 2, IAC | 3, Small cell | 4, IAC-small cell | 5, IAC-adeno | 7, Insufficient tumor | 6, Other 8, Adeno-small cell
    my %path_calls = ( 'Adenocarcinoma' => '1',
                       'IAC' => '2',
                       'Adeno/IAC' => '5',
                       'IAC/adeno' => '5',
                       'IAC/Adeno' => '5',
                       'IAC/Small cell' => '4',
                       'No biopsy performed' => '7',
                       'Missing' => '7',
                       'Unavailable' => '7',
                       'Adeno/small cell' => '8',
                       'Adenocarcinoma with Paneth' => '6',
                       'Colorectal Adenocarcinoma' => '6',
                       'Small cell/adeno' => '8',
                       'qNS' => '6',
                       'Non-prostate pathology' => '6',
                       'Indeterminate' => '6',
                       'Adeno/Small cell' => '8',
                       'Cytology mixed' => '6',
                       'QNS' => '6',
                       'Small cell' => '3',
                       'Small Cell' => '3',
                     );

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
So that means that I don't really need to process any of the Progression Dates at this point in time, right?

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

pre_study_screen_arm_2-serum_neuroendocrine_markers
every_3_months_arm_2-serum_neuroendocrine_markers
biopsy_2_arm_2-serum_neuroendocrine_markers
biopsy_3_arm_2-serum_neuroendocrine_markers
progression_3_arm_2-serum_neuroendocrine_markers

Very interesting.  I can collect serum_neurendocrine values at all of these following times:
1. During the Pre-Study, or Screening phase

2. As part of the Every 3 months phase

3. As part of the Biopsy 2 phase (but not at the Biopsy 1 phase or the Progression 1 phase)

NOT as part of Every 3 months at the Post-bx 2 phase (see how that does not make sense to me? Why collect
it in the Every 3 months phase, earlier, after the Biopsy 1 phase, but not after biopsy 2? (Biopsy 2
only occurs after a patient has undergone progression, right?).

4. As part of the Biopsy 3 phase

NOT as part of Every 3 months at the Post-bx 3 phase

5. As part of the Progression 3 phase

Okay, after looking at this, I need to print out a picture of this grid, I know
that I have done this before, but I want to make sure that I understand
all the different stages here, or whatever they are called.

One Patient has 2 (Two) Baseline specimen/sample/aliquots: DTB-095-BL
One Patient has no Baseline specimen/sample/aliquots, but does have
1 Progression specimen/sample/aliquot: DTB-123-Pro

How does my script handle those, as well? I am going to check on that.


=cut
    
    $timepoint = $hash{'TIMEPOINT'};

    
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

    # STEP 2. Start filling in the values just extracted, into the %redcap hash
    # Check to see if the three dates in Rahul's table have already been processed
    # Q1: Have we processed any rows from this patient previously? (because for almost
    # every patient the information in these three fields is identical and we can just extract
    # it once from the Baseline sample
    unless ( exists $updated->{$patient_id} ) {
        # This must be the first record we have encountered for this patient
	# So add a key to the hashref
        $updated->{$patient_id} = undef;
    }

    # Skip this block if we have already processed a row for this patient id
    unless ( defined $updated->{$patient_id} ) {
        # Otherwise, modify the flag
        $updated->{$patient_id} = '1';
	# And test to see if we were able to extract a date from Rahul's table
	# If so, then update the record in the %redcap hash
        if ( $addnl_dx_mets_date ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_mets_date} = $addnl_dx_mets_date;
	}

	if ( $addnl_dx_crpc_date ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{dx_crpc_date} = $addnl_dx_crpc_date;
	}

	if ( $addnl_date_of_mcrpc ) {
            $redcap->{$patient_id}{'pre_study_screen_arm_2-BLANK'}{date_of_mcrpc} = $addnl_date_of_mcrpc;
	}
    }
    # This testing was because there is one patient without a Baseline sample, just a Progression sample

    $instance = '1';
    $serum_instance ='1';
    
    if ( $timepoint eq 'Baseline' ) {
        $event = 'biopsy_arm_2-biopsy_collection';
	$serum_event = 'biopsy_arm_2-serum_neuroendocrine_markers';
    }
    elsif ( $timepoint eq 'Progression' ) {
        $event = 'biopsy_2_arm_2-biopsy_collection';
        $serum_event = 'biopsy_2_arm_2-serum_neuroendocrine_markers';
    }
    elsif ( $timepoint eq 'Progression2' ) {
        $event = 'biopsy_3_arm_2-biopsy_collection';
        $serum_event = 'biopsy_3_arm_2-serum_neuroendocrine_markers';
    }
    elsif ( $timepoint eq 'Progression3' ) {
        $event = 'biopsy_3_arm_2-biopsy_collection';
        $serum_event = 'progression_3_arm_2-serum_neuroendocrine_markers';	
    }


    if ( exists $seen->{$patient_id}{$event}{$instance} ) {
        # if you pass this test then that means we have already processed a record for this
	# patient with the same event and instance, and we need to autoincrement the
	# instance so that we don't clobber and overwrite the previously captured value
	# These are admittedly relatively rare edge-cases
        $instance++;
    }
    else {
        # if you reach here then that means we did not process a record like this event
	# for this patient earlier, so set the flag
	$seen->{$patient_id}{$event}{$instance} = '1';
    }

    # Same thing for the serum_events because those are intimately linked to their
    # respective biopsy dates
    if ( exists $seen->{$patient_id}{$serum_event}{$serum_instance} ) {
        $serum_instance++;
    }
    else {
        $seen->{$patient_id}{$serum_event}{$serum_instance} = '1';
    }

    
    if ( $final_path_call ) {
        $current_path_call = $path_calls{$final_path_call};
    }
    else {
        $current_path_call = '7';
    }
    $redcap->{$patient_id}{$event}{$instance}{'clia'} = $current_path_call;
    
    if ( $current_path_call eq '6' ) {
        $redcap->{$patient_id}{$event}{$instance}{'other_clia'} = $final_path_call;
    }


    if ( $serum_chga ) {
        $redcap->{$patient_id}{$serum_event}{$serum_instance}{'serum_value'} = $serum_chga;
    }

    if ( $serum_nse ) {
        $redcap->{$patient_id}{$serum_event}{$serum_instance}{'enolase_value'} = $serum_nse;
    }

    if ( $serum_chga | $serum_nse ) {
	# This should work. Note that I am using the $event, not the $serum_event
	# to see if this timpoint biopsy has biopsy date.  If it does, Rahul said that is
	# what I should enter into the instrument
	if ( $redcap->{$patient_id}{$event}{$instance}{'bx_date'} ) {
           $redcap->{$patient_id}{$serum_event}{$serum_instance}{'date_blood_draw'} = $redcap->{$patient_id}{$event}{$instance}{'bx_date'}; 
	}
        $redcap->{$patient_id}{$serum_event}{$serum_instance}{'serum_neuroendocrine_markers_complete'} = '2';
    }
} # close sub


=pod

dx_mets_date
dx_crpc_date
date_of_mcrpc

Here are the 7 additional data points that Rahul's table contained:
Original Field	My Modified Field	Insertion point in REDCap
Final Path Call	FINAL_PATH_CALL	???
Sites of Metastases at time of biopsy	SITES_OF_METS_AT_TIME_OF_BIOPSY	???
Serum CHGA at biopsy	BIOPSY_SERUM_CHGA	NONE
Serum NSE at Biopsy	BIOPSY_SERUM_NSE	
Date of Castration Resistance	DateOfCR	
First Date of Metastases	DateOfFirstMetastases	
Date of mCRPC	DateofmCRPC	


=cut


sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for a patient in Package Additional\n";
    }
    return $good_date;
} # close sub iso_date

1;

