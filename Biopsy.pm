package Biopsy;

use base 'Exporter';
our @EXPORT_OK = qw(extract_biopsies add_biopsy_dates);
our @EXPORT    = qw(extract_biopsies add_biopsy_dates);
use Date::Calc qw ( Delta_Days );

sub add_biopsy_dates {
    my $patient_id = shift @_;
    my %records = %{shift @_};
    my $timespan = shift @_;

    if ( $records{DATE_OF_PROCEDURE} ) {
        my $date = iso_date( $records{DATE_OF_PROCEDURE} );
        push @{$timespan->{$patient_id}{biopsy_dates}}, $date;
    }
} # close sub


sub extract_biopsies {
    my $patient_id = shift @_;
    my %hash = %{ shift @_ };
    my $redcap = shift @_;
    my @fields_to_print = @{shift @_};
    my $timespans = shift @_;

    
    
    # The first question to ask when processing the current record is if it is
    # a Screening biopsy record, OR a Progression Biopsy record.
    # If it is a Screening biopsy then this will be the event and instrument:
    # biopsy_arm_2-biopsy_collection
    # Whereas if it is a Progression biopsy then the event and instrument will be one
    # of these:
    # biopsy_2_arm_2-biopsy_collection
    # biopsy_3_arm_2-biopsy_collection

=pod

Because there are three patients with multiple Screening level biopsies, and it is the 
anatomical site that they vary, we will always be tracking the instance in biopsies, 
AND we will always need to create a new row in the data structure for every biopsy record.

=cut

    my $event = q{};
    my $screening = q{};
    my $progression = q{};
    my $segment = $hash{SEGMENT};
    my $this_biopsy_record = q{};
    my $progression_1 = q{};
    my $progression_2 = q{};
    my $progression_3 = q{};
    my $biopsy_date = q{};

    if ( $hash{DATE_OF_PROCEDURE} ) {
        $biopsy_date = iso_date( $hash{DATE_OF_PROCEDURE} );
    }

    
 # STEP 1. Figure out where this record lies in the event timeline
    if ( $segment =~ m/Screening/ ) {
        $screening = '1';
        $event = 'biopsy_arm_2-biopsy_collection';
    }
    elsif ( $segment =~ m/Progression/ ) {
        $progression = '1';
        if ( exists $timespans->{$patient_id} ) {
            if ( $timespans->{$patient_id}{max} eq 'progression_1' ) {
                $progression_1 = '1';
	    }
	    elsif ( $timespans->{$patient_id}{max} eq 'progression_2' ) {
                # Q: is this biopsy record progression_1 or progression_2 (given that
		# this patient is know to have two progression events)?
                my ( $year1, $month1, $day1 ) = split /-/, $timespans->{$patient_id}{progression_2};
                my ( $year2, $month2, $day2 ) = split /-/, $biopsy_date;
		my $days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2);
                # IF the number of days between the progression_2 date and this biopsy date is
		# zero, or larger, then this biopsy is a progression_2 biopsy
                if ( $days > -1 ) {
                    $progression_2 = '1';
		}
		else {
                    # otherwise this biopsy date occured BEFORE the annoated progression_2 event
		    # date and must therefore be a progression_1 biopsy, by definition
                    $progression_1 = '1';
		}
	    }
	    elsif ( $timespans->{$patient_id}{max} eq 'progression_3' ) {
                # Q: is this biopsy record progression_1, progression_2, or progression_3 (given that
		# this patient is know to have to progression events)?
                my ( $year1, $month1, $day1 ) = split /-/, $timespans->{$patient_id}{progression_3};
                my ( $year2, $month2, $day2 ) = split /-/, $biopsy_date;
		my $days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2);
                # IF the number of days between the progression_3 date and this biopsy date is
		# zero, or larger, then this biopsy is a progression_3 biopsy
                if ( $days > -1 ) {
                    $progression_3 = '1';
		}
                else {
                    # Using the same logic applied above, and having established that this biopsy
		    # record occurred before the progression_3 event timepoint, test to see
		    # if this biopsy record occurred on or after the progression_2 event timepoint:
                    my ( $year1, $month1, $day1 ) = split /-/, $timespans->{$patient_id}{progression_2};
                    my ( $year2, $month2, $day2 ) = split /-/, $biopsy_date;
		    my $days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2);
                    if ( $days > -1 ) {
		        $progression_2 = '1';
		    }
		    else {
                        # otherwise this biopsy date occured BEFORE the annoated progression_2 event
		        # date and must therefore be a progression_1 biopsy, by definition
                        $progression_1 = '1';
		    }          
		}
	    }
	} # close if $segment/elsif
	else {
            print STDERR "WARNING: There is no entry in the \%timespans hash for this patient_id: $patient_id\n";
	}

	# Based on calculations above, set the event for this biopsy record
        if ( $progression_1 ) {
            $event = 'biopsy_2_arm_2-biopsy_collection';	    
	}
	elsif ( $progression_2 ) {
            $event = 'biopsy_3_arm_2-biopsy_collection';	    
	}
	elsif ( $progression_3 ) {
	    # N.B. There is no 3rd Progression Biopsy Collection
	    # for the WCDT in the REDCap Data Model (for some unknown reason)
            $event = 'biopsy_3_arm_2-biopsy_collection';	    
	}
    } # close if/else $segment
    
    # Q: For this patient_id, how many rows (records) from the OnCore biopsy_collection
    # table have we already processed (if any)?
    # N.B. I am seeing if I can work the progression and the screening in at the same time here
    my $instance = q{};
    if ( $redcap->{$patient_id}{$event} ) {
        # A: Count the number of hash keys at this level in the master data structure I am building:
        my $value = scalar( keys %{$redcap->{$patient_id}{$event}} );
        # if there are any keys then add '1' to that number, and that will
        # become the number of the current OnCore/REDCap instance being processed
        $instance = $value + 1;
    }
    else {
        # otherwise, the current record we are processing MUST be the very first instance, 
        # so number it thusly:
        $instance = 1;
    } # close if/else test

    # initialize the hash
    foreach my $field ( @fields_to_print ) {
        $redcap->{$patient_id}{$event}{$instance}{$field} = undef;
    } # close foreach loop
	
    if ( $biopsy_date ) {
        $redcap->{$patient_id}{$event}{$instance}{bx_date} = $biopsy_date;
    }

    # Set the Dropdown option for the biopsy event timepoint in REDCap
    # depending on which of these two variables evaluates to 'True'
    if ( $screening ) {
        $redcap->{$patient_id}{$event}{$instance}{bx_timepoint} = '1';
    }
    elsif ( $progression ) {
        $redcap->{$patient_id}{$event}{$instance}{bx_timepoint} = '2';
    }

    my $name = q{};
    if ( $hash{OfPatienttookaSteroidint} ) {
        if ( $hash{OfPatienttookaSteroidint} eq 'Yes' ) {
            $redcap->{$patient_id}{$event}{$instance}{steroids} = '1';
            # what about a name in the preceding column of the
            # OnCore table that we are parsing?
            if ( $hash{LIST_ALL_ANTICANCER_MEDS_TAKEN} ) {
                # test to see if any of the text matches known steroid names
                if ( ($name) = $hash{LIST_ALL_ANTICANCER_MEDS_TAKEN} =~ m/(Prednisone|Hydrocortisone|Dexamethasone)/i ) {
                    # if you found a steroid drug name then capture and
                    # pass it onto REDCap
                    $redcap->{$patient_id}{$event}{$instance}{specify_steroids} = $name;
                }
 	        else {
                    # But if you didnt find a steroid drug name, you
		    # know that one was administered, but we dont
		    # know the name
		   $redcap->{$patient_id}{$event}{$instance}{specify_steroids} = "UNK";
                }
            } # close if test for value in MEDS_TAKEN field from OnCore
        }
        else {
                $redcap->{$patient_id}{$event}{$instance}{steroids} = "0";
        } # close if/else test for value in Patient_Took_Steroids
    }
    elsif ( $hash{LIST_ALL_ANTICANCER_MEDS_TAKEN} ) {
        # Sometimes the value in Column 19 is NOT a YES, 
        # but there was a steroid drug name specified in this field.
        if ( ($name) = $hash{LIST_ALL_ANTICANCER_MEDS_TAKEN} =~ m/(Prednisone|Hydrocortisone|Dexamethasone)/ ) {
            # capture these again, even if we already did it above. I
            # know it is inefficient, but I think the code flows
            # better this way (maybe)
            $redcap->{$patient_id}{$event}{$instance}{steroids} = '1';
            $redcap->{$patient_id}{$event}{$instance}{specify_steroids} = $name;
        }
        else {
            $redcap->{$patient_id}{$event}{$instance}{steroids} = '0';
 	}
    } 

    # N.B. I did not see any entries in the OnCore Biopsy Collection Table
    # with a site of 'Lung' but in REDCap that is a site that can be selected
    my %biopsy_sites = ( Bone          => '1',
  		         Liver         => '2',
		         Lung          => '3',
                         'Lymph nodes' => '4',
		         Other         => '5',
                   );
	
    if ( $hash{SITE} ) {
        my $site = $hash{SITE};
	my $other_site = q{};

	if ( $hash{IF_OTHER_SPECIFY} ) {
            $other_site = $hash{IF_OTHER_SPECIFY};
	}

        if ( $biopsy_sites{$site} ) {     
            $redcap->{$patient_id}{$event}{$instance}{site_biopsy} = $biopsy_sites{$site};
        }
        else {
	    # if the string in the OnCore SITE field is not a key in the %biopsy_sites hash
	    # then by definition, the site_biopsy = 'Other' which is '5' on the menu
            $redcap->{$patient_id}{$event}{$instance}{site_biopsy} = '5';
        }

        if ( $site eq 'Bone' && $other_site ) {
            $redcap->{$patient_id}{$event}{$instance}{bone_bx_location} = $other_site;
        }
        elsif ( $other_site ) {
            # if the biopsy SITE is specified in OnCore as 'Other' then hopefully
	    # there is also an entry in the IF_OTHER_SPECIFY field, but sometimes
	    # the CRC entered information in the IF_OTHER_SPECIFY field, even if
	    # the biopsy SITE does not contain 'Other', and even if the SITE is
	    # not 'Bone' (which was captured above).
            $redcap->{$patient_id}{$event}{$instance}{other_site_bx} = $other_site;
        }		
    } # close if ( $hash{SITE} );        
    $redcap->{$patient_id}{$event}{$instance}{biopsy_collection_complete} = '2';
} # close sub

sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for patient $patient_id in Package Biopsy\n";
    }
    return $good_date;
} # close sub iso_date

=pod

These are some notes that I had in my previous longer version of the
parse_oncore_tables.pl script and now I moved them over here

<2017-09-05 Tue 10:21>
Q1: How many biopsies could a patient have? For example, are any
OnCore patients with NO biopsies?  How many with multiple biopsies (I
can see a few examples of this just from the first page of the table).

There are 246 unique SEQUENCE_NO_ patient ids in the first column of
the su2c_biopsy_v3_filtered.tsv table. Huh, the demographics table
from OnCore has 256 unique SEQUENCE_NO_ patient_ids, so possibly 6
patients in OnCore with a demographics record do not have a biopsy?  I
am going to make a list of those six for future reference.

Of the 246 patient_ids in this biopsy table, ALL of them have matching
IDs in the demographics table.  From the converse search, I confirmed
that all of the 246 patient_ids in the biopsy table match a record in
the demographics table.  These six patient_ids, from the demographics
table, however, do NOT have a matching biopsy (For some reason?):
100 HAS pr_ca_tx record & subsequent_tx record
207 LACKS pr_ca_tx record & subsequent_tx record
245 LACKS pr_ca_tx record & subsequent_tx record
254 LACKS pr_ca_tx record & subsequent_tx record
DTB-VA-172 LACKS pr_ca_tx record & subsequent_tx record
DTB-VA-179 LACKS pr_ca_tx record & subsequent_tx record

UPDATE 2017-11-03 I wrote to Alex and Jaselle about this and they said that these are
patients from another center, and we don't have access to the original data (if the other
center did not fill it in), and therefore I can just treat them as empty.  This has a 
ramification which is that I cannot use the biopsy, and specifically the event/timepoint of
a patient's biopsy as my primary classifier at a high level in the hierarchy because otherwise
These six patients would basically not exist.

What about multiple biopsies? Most patients have a single biopsy, but
many have two, and some three, a single patient has had 5 biopsies. So
the range is from zero up to five, it would seem.

if ( there is a steroid drug name specifed in one column ) {

}
OR ( another column contains a Yes ) {
    THEN the patient was administerd steroids, but we may 
    not know the name.  Okay?
} 

=cut


1;
