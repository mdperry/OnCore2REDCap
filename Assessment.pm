package Assessment;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = 'extract_assessments';
our @EXPORT    = 'extract_assessments';
use Date::Calc qw ( Delta_Days );


sub extract_assessments {
    my $patient_id = shift @_;
    my %hash = %{shift @_};
    my $redcap = shift @_;
    my @fields_to_print = @{shift @_};
    my $ass = shift @_;
    my @gu = shift @_;
    my $timespans = shift @_;

=head 2017-10-15 Newest version

DOES NOT put any radiographic disease assessment data in the 
aggregator, instead each record will be assigned either a screening or a visit repeating instrument

=cut	        

    my $event = q{};
    my $date = q{};
    # There are 9 records where this field is blank
    # UPDATE, After cleaning this up, there are only
    # 2 records where this field is blank
    if ( $hash{FIRST_DOSE_DATE} and $hash{FIRST_DOSE_DATE} ne ' ' ) {
        $date = iso_date( $hash{FIRST_DOSE_DATE} );
    }
    else {
        # However all 9 have a value in this field:
        $date = iso_date( $hash{VISIT_DATE} );
    }

    my $instance = '0';


=pod

This is where I need to insert the logic to get the correct timepoint event
for each assessment

The Choices from REDCap are:
screening:
pre_study_screen_arm_2-radiographic_disease_assessment

baseline:
every_3_months_arm_2-radiographic_disease_assessment

progression (or progression_1) (biopsy_2):
progression_arm_2-radiographic_disease_assessment
_every_3_months_pos_arm_2-radiographic_disease_assessment <<< This is not annotated or tagged in the incoming OnCore tables, therefore this can never be an output choice for REDCap_
followup_postbx_2_arm_2-radiographic_disease_assessment

progression_2 (biopsy_3, bx_3):
progression_2_arm_2-radiographic_disease_assessment
_every_3_months_pos_arm_2b-radiographic_disease_assessment <<< This is not annotated or tagged in the incoming OnCore tables, therefore this can never be an output choice for REDCap_
followup_postbx_3_arm_2-radiographic_disease_assessment

progression_3:
progression_3_arm_2-radiographic_disease_assessment

=cut

    if ( $hash{SEGMENT} =~ m/Screening/ ) {
        $event = 'pre_study_screen_arm_2-radiographic_disease_assessment';
    }
    elsif ( $hash{SEGMENT} =~ m/Month/ ) {
	$event = 'every_3_months_arm_2-radiographic_disease_assessment';
    }
    elsif ($hash{SEGMENT} =~ m/Follow|Progression/ ) {
        if ( exists $timespans->{$patient_id} ) {
	    if ( exists $timespans->{$patient_id}{biopsy_dates} ) {
                my @biopsy_dates = sort @{$timespans->{$patient_id}{biopsy_dates}};
                if ( scalar( @biopsy_dates ) == 1 ) {
                    # there is one progression biopsy date, and therefore whether this assessment
		    # was for a Follow Up or a Progression/Study Termination SEGMENT it has to be
		    # after that biopsy (I believe)
                    if ( $hash{SEGMENT} =~ m/Follow/ ) {
  	                $event = 'followup_postbx_2_arm_2-radiographic_disease_assessment';
		    }
                    else {
	                $event = 'progression_arm_2-radiographic_disease_assessment';
		    }
		}
		elsif ( scalar( @biopsy_dates ) < 1 ) {
                    # these are for patients who had progression events, but no progression
		    # biopsies; the @biopsy_dates array is empty and contains no elements
                    $event = 'progression_arm_2-radiographic_disease_assessment';
		}
                elsif ( scalar( @biopsy_dates ) > 1 ) {
		    # there are two, or more, progression biopsy dates
                    my ( $year1, $month1, $day1 ) = split /-/, $date;
                    my ( $year2, $month2, $day2 ) = split /-/, $biopsy_dates[1];
             	    my $days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2);
                    # If this post-biopsy assessment record occurred BEFORE the date of
		    # The second progression biopsy, then this has to be a post-progression_1 assessment
		    if ( $days > -1 ) {
                        if ( $hash{SEGMENT} =~ m/Follow/ ) {
	                    $event = 'followup_postbx_2_arm_2-radiographic_disease_assessment';
			}
			else {
	                    $event = 'progression_arm_2-radiographic_disease_assessment';
		        }
 		    }
		    else {
                        # If the number of days difference between the second progression
			# biopsy and the assessment is positive, then for the Follow Up
			# there is only one choice for this value
                        if ( $hash{SEGMENT} =~ m/Follow/ ) {
	                    $event = 'followup_postbx_3_arm_2-radiographic_disease_assessment';
			}
			else {
                            # Progression Assessments can be progression, progression_2 or progression_3
	                    if ( scalar( @biopsy_dates ) > 2 ) {
                                my ( $year1, $month1, $day1 ) = split /-/, $date;
                                my ( $year2, $month2, $day2 ) = split /-/, $biopsy_dates[2];
             	                my $days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2);
                                # If this progression assessment record occurred BEFORE the date of
		                # The third progression biopsy, then this has to be a progression_2 assessment
		                if ( $days > -1 ) {
	                            $event = 'progression_2_arm_2-radiographic_disease_assessment';
		                }
		                else {
			            # otherwise this assessment occured AFTER the third progression biopsy
			            # and therefore has to be a progression_3 assessment
	                            $event = 'progression_3_arm_2-radiographic_disease_assessment';
		                }
			    }
		        }
		    }
	        } # close if biopsy dates array
	    } # close outer if/else test
        } # close if test to see if this record's patient_id is in the %timespans hash
    }
    else {
            die "I found a disease assessment with a SEGMENT I was not expecting";
    }

=pod

2017-11-14 In this newly modified version, all four of those REDCap Events
have to be repeating instruments, so they all need an instance number both in 
the data structure that I am building, and also in the output table that the script
generates.

However, it is not enough to map dates to instances, such that the first date
is the first instance, because there can be MULTIPLE assessments on a single date
So if two records have the same date their results need to be aggregated without
overwriting.  So for each record we need to ask first and foremost:
"Are there any other records for this REDCap event?"  If the answer is no, then
This record has to be, by definitition, instance number 1.  If the answer is yes
Then the second question we need to ask is "Is there already any data collected 
for this REDCap event on this date?" 
If the answer is no, then we need to count the number of instances, and then increment
it 1 so that the current record becomes a new instance number.
If the answer is Yes, then we don't need to do anything to the instance number
We just need to add this data and capture it in the right way in the data structure

=cut
    
    # Does the passed in %ass hash (a global variable) already contain a record (or records) for THIS REDCap event
    # for this patient?
    if ( $ass->{$patient_id}{$event} ) {
        # then the current record being processed CANNOT be the first record (or instance) for this REDCap event
	# for this patient id and either gets a new instance number if the date on this record
	# is a new date, or, if there is already data stored for this date then this record gets processed
	# and added to the existing data AND THE INSTANCE NUMBER STAYS THE SAME, right??
        # Does this current record have the same date as any other screening event radiographic disease
        # assessments that have been processed for this patient thus far?

        if ( $ass->{$patient_id}{$event}{$date} ) {
	    # if there is already data captured for this $event on
	    # this $date THEN: Do one thing

	    # Only enter this block if this date is already in the data structure,
	    # because that means we must already have
	    # an instance number as well, and we need to aggregate/update the values in the
	    # current record into the existing data structure (keyed on date) in the %ass hash,
	    # WITHOUT overwriting any stored information

	    # Since I want to aggregate the procedures that share the same $event
	    # and the same $date, I need to extract the instance number from before and
	    # use it again, right?

	    $instance = $ass->{$patient_id}{$event}{$date}{'instance'};
        } # close if test block
	else {
            # IF there is no previous information captured for this $event
	    # on this $date THEN: increment the instance counter for this event

	    # This must be the first record with this date SO: I need to initialize the values for
	    # this record in the %ass hash, AND I similarly need to initialize the values
	    # for this record in the %redcap data structure (so that I can copy the values over later on)

	    # THEREFORE: count how many different dates there are for this specific event BEFORE you process the date
	    # for the current record.  Whatever the number of hash keys, add a '1' and that will be the
	    # number of this current instance WAIT, what happened to the add a 1 part?
	    my $value = scalar( keys %{$ass->{$patient_id}{$event}} );
	    $instance = $value + 1;
            # Store the instance number in this cache data structure
	    $ass->{$patient_id}{$event}{$date}{'instance'} = $instance;

	    # AND initialize the hash keys for this event on this date		    
	    foreach my $field ( @gu ) {
	        $ass->{$patient_id}{$event}{$date}{$field} = undef;
	    }                 

	    # Explicitly label and pass in the date of the assessment (not
	    # just keeping it as a hash key, higher up)	    
	    $ass->{$patient_id}{$event}{$date}{assess_date} = $date;		

	    # Also, prepare a placeholder in the larger data structure that we
 	    # are going to use later:
	    foreach my $field ( @fields_to_print ) {
	        $redcap->{$patient_id}{$event}{$instance}{$field} = undef;
	    } # close foreach my $field
	} # close inner else block
    } # close if ( $ass->{$patient_id}{$event} ) 
    else {
        # this record is the very first event of this type processed for this patient ID
	# therefore the instance number for this repeating instrument has to be '1'
        $instance = '1';	
        # Store the instance number in this cache data structure
	$ass->{$patient_id}{$event}{$date}{'instance'} = '1';

        # AND initialize the hash keys for this event on this date
        foreach my $field ( @gu ) {
	    $ass->{$patient_id}{$event}{$date}{$field} = undef;
        }

	# Explicitly label and pass in the date of the assessment (not
	# just keeping it as a hash key, higher up)
        $ass->{$patient_id}{$event}{$date}{'assess_date'} = $date;		

	# Also, prepare a placeholder in the larger data structure that we
	# are going to use later:
        foreach my $field ( @fields_to_print ) {
	    $redcap->{$patient_id}{$event}{$instance}{$field} = undef;
        } # close foreach my $field
    } # close inner if/else test

=pod

So at this point either we created a brand new instance for the date of this record
Or we created another instance with a new date for this record
Or we established that there is already both a date and an instance number for
this record and we therefore have to add the data in this record to an existing
instance

MDPQ: How often do 'Screening ' SEGMENTs have different dates?
find out.  Ay-yi-yi.  It happens. Hmmm

Okay, so here we are, right at the crux of the biscuit.  As initially written, there were only two types of 
Records. Either Screening records, which were ASSUMED to always share the same date, and which therefore needed to
be collapsed, or aggregated, into one row of the future output table OR, Repeating Records.  There could be multiple 
Repeating radiographic_disease_assessment records that shared the same date (because, for example, a patient might 
have both a Bone Scan, AND some other kind of assessment, on a single visit, right?).

What my initial processing did not take into account was that there might be Screening records with different dates.
In the original version the second date clobbers the first date recorded, like this:
    $ass{$patient_id}{'screening'}{assess_date} = $date;

Whereas what it probably needs to say is this:
    $ass{$patient_id}{'screening'}{$date}{assess_date} = $date;

Which necessitates some downstream changes to the processing, and possibly a new
repeating instrument in the screening arm.  I am going to check now and see 
if the possibility of repeating here is already built-in to the REDCap project.
Yes, I think so!

In the a previous version of the script I used this code to assign values to 
variables in the %ass hash but I am not setting these above
    # UPDATE: According to Jaselle's response to my detailed query, the OnCore field named 'FIRST_DOSE_DATE
    # most closely approximates the REDCap field 'assess_date'   

        if ( $screening ) {
            $ass{$patient_id}{'screening'}{$date}{assess_date} = $date;
        }
        else {
            $ass{$patient_id}{'visits'}{$date}{assess_date} = $date;
        }

=cut	

    # N.B. This hash is just here for my own reference, it does not get
    # used by any code in this Perl Module, more of a reminder, actually
    my %exam_types = ( 'CT scan' => 'assess_exam___1',
                       'TCH99 Bone Scan' => 'assess_exam___2',
                       'MRI' => 'assess_exam___3',
                       'PSMA PET' => 'assess_exam___4',
                       'NaF PET' => 'assess_exam___5',
                       'Other' => 'assess_exam___6',
                     );

    # N.B. These mappings between the OnCore PROCEDURES and the REDCap
    # Exam Types have been confirmed by Jaselle (I had _MANY_ questions)
    my %procedure_types = ( "CT Scan (non-spiral)" => "assess_exam___1",
                            "Spiral" => "assess_exam___1",
                            "CTA" => "assess_exam___1",
                            "Bone Scan" => "assess_exam___2",
                            "MRI" => "assess_exam___3",
                            "Whole Body PET/CT" => 'assess_exam___6',
                            "Other (specify in comments)" => 'assess_exam___6',
                            "Bone Marrow Biopsy" => 'assess_exam___6',
                            "Chest X-Ray" => 'assess_exam___6',
                          );

    # these false values are for a radio selection I think
    my %red_exams = ( "assess_exam___1" => "0",
                      "assess_exam___2" => "0",
                      "assess_exam___3" => "0",
                      "assess_exam___4" => "0",
                      "assess_exam___5" => "0",
                      "assess_exam___6" => "0",
                   );
    # Extract the PROCEDURE from this OnCore record and 
    if ( $hash{PROCEDURE} ) {     	    
        if ( $procedure_types{$hash{PROCEDURE}} ) {
            $red_exams{$procedure_types{$hash{PROCEDURE}}} = 1;
        }
        else {
	    # If there is a value in the PROCEDURE field that is not in my %procedure_types hash
	    # then by definition the Procedure type is Other
            $red_exams{assess_exam___6} = '1';
        } # close inner if/else test
    }
    else {
        # Some of the records in the incoming table are blank, and "some" of these 
        # _MAY_ have COMMENTS
        $red_exams{assess_exam___6} = '1';
    }

    # I initialized the %red_exams hash so that each value was a '0' but hopefully parsing
    # the current record will update one of those values to a '1'
    foreach my $type ( sort keys %red_exams ) {
        unless ( $ass->{$patient_id}{$event}{$date}{$type} ) {
	    $ass->{$patient_id}{$event}{$date}{$type} = $red_exams{$type};
        } 
    } # close foreach loop

    # Did any of the steps above trigger an "Other" category??
    if ( $red_exams{assess_exam___6} ) {
        if ( $hash{PROCEDURE} ) {
 	    if ( $hash{PROCEDURE} =~ m/comments/ ) {
                # There are three records where in OnCore they selected 'Other' and specifically put the details
	        # in the COMMENTS2 column:        
                if ( $hash{COMMENTS2} ) {
 	            if ( $ass->{$patient_id}{$event}{$date}{other_exam} ) {
                                $ass->{$patient_id}{$event}{$date}{other_exam} .= "; $hash{COMMENTS2}";
	            }
		    else {
                        $ass->{$patient_id}{$event}{$date}{other_exam} = $hash{COMMENTS2};
	            }
	        }
	    }
	    else {
                # If some earlier block of code triggered this flag for "other" then transfer the entire text from the 
                # OnCore table's PROCEDURE field into what will beocme the REDCap table's other_exam variable
            	if ( $ass->{$patient_id}{$event}{$date}{other_exam} ) {
                    $ass->{$patient_id}{$event}{$date}{other_exam} .= "; $hash{PROCEDURE}";
		}
		else {
                    $ass->{$patient_id}{$event}{$date}{other_exam} = $hash{PROCEDURE};
		}
            } # close if/else test
        }
        elsif ( $hash{COMMENTS2} ) {
            # Stop for a second to consider the logic of this flow.  To enter this block of code two things have to
  	    # have occured (I think): 1. $red_exams{assess_exam___6} evaluates to 'TRUE' (should contain a '1')
	    # 2. The PROCEDURE field in the incoming OnCore table for this record is blank (i.e., Empty), so now
	    # If there is anything in the COMMENTS2 field we are going to store that information in the Other Exam
	    # Textbox in the REDCap form.  MDPQ: How many records meet this criteria? A: There are only 4 records (there are
	    # four other records where both PROCEDURE and COMMENTS2 are blank).  Three of the four that get captured here
	    # had cancelled procedures (if I understand correctly).
            $ass->{$patient_id}{$event}{$date}{other_exam} = $hash{COMMENTS2};
        } # close if/else test
    } # close if ( $red_exams{assess_exam___6} )

=pod

To clarify, since there are only 8 records in the incoming OnCore table that lack a PROCEDURE
I DO NOT need to capture any information regarding procedures from the COMMENTS2 field
in the OnCore table (except that I will try to for those 8.)
The main thing I am going to use the COMMENTS2 field for is to capture information
and details about the site of metastasis. Okay? Oh, wait, like there is no other information
about sites except in the COMMENTS2 section, right? Yes. There is indirect information in that
for example, if the PROCEDURE was a Bone Scan, and if the ARE_LESIONS_PRESENT was a Yes then
that means that the metastatic site was in Bone, but I think that is generally(?) reflected in the COMMENTS2
free text. Let's check that.  Column 16 matches 'Bone Scan' Column 17 matches 'Yes' what is in Column
19? Does it always say something about bone?
There are 1388 rows in that table (+ a Header row), 632 match Bone, 630 match Bone Scan
543/630 also say 'Yes' in column 17.
16      bone
118     Bone
342
So maybe I should automatically insert this code, if it matches bone and it says yes, 
then check off bone?

=cut        

    my %sites = ( 'Bone' => 'assess_sites___1',
                  'Lymph Node' => 'assess_sites___2',
                  'Liver' => 'assess_sites___3',
                  'Soft Tissue' => 'assess_sites___4',
                  'Other' => 'assess_sites___5',
                  'None' => 'assess_sites___6',
            );

    # this hash gets initialized, or zeroed out
    # every time there is a new radiographic assessment parsed from
    # the OnCore table, right? 
    my %red_sites = ( assess_sites___1 => "0",
                      assess_sites___2 => "0",
                      assess_sites___3 => "0",
                      assess_sites___4 => "0",
                      assess_sites___5 => "0",
                      assess_sites___6 => undef,
	      );

    if ( $hash{ARE_LESIONS_PRESENT_} ) {
        my $value = $hash{ARE_LESIONS_PRESENT_};
        push( @{$red_sites{assess_sites___6}}, $value, );
    }

    # This explicitly sets one of the metastatic sites to 'Bone'
    # If the Exam Type was a Bone Scan, and it was noted that
    # lesions are present
    if ( $hash{PROCEDURE} && $hash{ARE_LESIONS_PRESENT_} ) {
        if ( $hash{PROCEDURE} =~ m/Bone/i ) {
            if ( $hash{ARE_LESIONS_PRESENT_} eq 'Yes' ) {
                $red_sites{assess_sites___1} = '1';
	    }
        }
    } # close outer if test
		
    # Don't even process those comments if they are blank
    if ( $hash{COMMENTS2} ) {
        my @comments = split( /. |, |; |: /, $hash{COMMENTS2} );
        # iterate over the array containing the parsed terms
        foreach my $comment ( @comments ) {
            my $matched = q{};
            # test each array element for possible matches to one of the
            # terms in the REDCap checkbox form
 	    # MDP Q: Why did I ever bother parsing it into an Array?
	    # why not just test the whole string?
            if ( $comment =~ m/Bone/i ) {
                # case insensitive match to "Bone" anywhere in this
                # current parsed term will select the corresponding
                # checkbox for this record
                $red_sites{assess_sites___1} = '1';
                $matched++;
            }

            if ( $comment =~ m/Lymph|Node/i ) {
                # N.B. It is perfectly fine if one 'COMMENTS2' record
                # contains information on Multiple metastatic sites, so in
                # the REDCap check box it is fine to have multiple sites
                # checked off
                $red_sites{assess_sites___2} = '1';
                $matched++;
            }
                
            if ( $comment =~ m/Liver/i ) {
                $red_sites{assess_sites___3} = '1';
                $matched++;
            }

            if ( $comment =~ m/Soft Tissue/i ) {
                $red_sites{assess_sites___4} = '1';
                $matched++;
            }
            # There are going to be lots of examples, I think where something in the comments is not going to
	    # match the regex pattern sieve above, and when that happens I want to be sure to trigger
	    # this flag in REDCap.  This idea has evolved through several iterations, but I have
	    # finally concluded that no matter how fancy I get, in the end, if there is any text in the comments
	    # field then I want it to be in the other_sites_mets text field
            unless ( $matched ) {
	        # By definition (and after consulting with Jaselle) if there
	        # was no match to the previous four patterns, then check off other
                $red_sites{assess_sites___5} = '1';
            }
            $ass->{$patient_id}{$event}{$date}{other_sites_mets}{$hash{COMMENTS2}}++;
        } # close outer foreach loop
    } # close if test for value in COMMENTS2 field

    # copy the results over to the %ass data structure
    foreach my $site ( sort keys %red_sites ) {
        if ( $site eq 'assess_sites___6' ) {
            if ( $red_sites{assess_sites___6} ) {
                # You May Recall, that I am anticipating a mixture of
	        # Yes and No in this array
	        if ( grep { /Yes/ } @{$red_sites{assess_sites___6}} ) {
                    $ass->{$patient_id}{$event}{$date}{assess_sites___6} = '0' unless $ass->{$patient_id}{$event}{$date}{assess_sites___6};
	        }
		elsif ( grep { /No/ } @{$red_sites{assess_sites___6}} ) {
	            $ass->{$patient_id}{$event}{$date}{assess_sites___6} = '1';
	        }
	    }
	    else {
	        $ass->{$patient_id}{$event}{$date}{assess_sites___6} = '0' unless $ass->{$patient_id}{$event}{$date}{assess_sites___6};
	    }
        } # close if ( $site eq 'assess_sites___6' )
        else { 
	    # Everytime you update a value in the %ass hash make sure you are not
	    # overwriting a previous value
	    $ass->{$patient_id}{$event}{$date}{$site} = $red_sites{$site} unless $ass->{$patient_id}{$event}{$date}{$site};
        } # close if/else test for ( $site eq 'assess_sites___6' )
    } # close foreach my $site loop


=pod

		
Response 43 rows
Progressive Disease 342 rows
BLANK, Empty 343 rows
Stable 660 rows

Bone response and RECIST response in REDCap don't seem to correspond precisely to the OnCore choices.  
In REDCap there are five choices:
1. Complete Response
2. Partial Response
3. Progressive Disease
4. Stable Disease
5. N/A. 

N.B.: RECIST response is different from COMPARED_WITH_PREVIOUS_SCAN.
So I am setting this to N/A, uniformly

Mapping

=cut

    my %bone_responses = ( 'Response' => '2', # 2. Partial Response
 		           'Progressive Disease' => '3', # 3. Progressive Disease
			   'Stable' => '4', # 4. Stable Disease
	                 );

=pod

MDPQ: what IF the 'COMPARED_WITH_PREVIOUS_SCAN' has different values for different
assessment examinations from the same date?  What happens then? The last one to get processed for that
date overwrites all of the earlier values, right?

I am going to check that out and see if for a given patient_id
on a given date, are there different values in column 'R'?? Because if that happens then I need to work out
an algorthim to capture that.

=cut

    if ( $hash{COMPARED_WITH_PREVIOUS_SCAN} ) {
        if ( $bone_responses{$hash{COMPARED_WITH_PREVIOUS_SCAN}} ) {
            my $value = $bone_responses{$hash{COMPARED_WITH_PREVIOUS_SCAN}};
            $ass->{$patient_id}{$event}{$date}{pre_tx_resp_bone_2} = $value unless $ass->{$patient_id}{$event}{$date}{pre_tx_resp_bone_2};
	    }
	    else { # I need to rethink this, do I always want it to be 5 and overwrite???
	        $ass->{$patient_id}{$event}{$date}{pre_tx_resp_bone_2} = '5' unless $ass->{$patient_id}{$event}{$date}{pre_tx_resp_bone_2};
	    }
    } # close if ( $hash{COMPARED_WITH_PREVIOUS_SCAN} ) 
		
    $ass->{$patient_id}{$event}{$date}{pre_tx_resp_recist_2} = '5';
    $ass->{$patient_id}{$event}{$date}{radiographic_disease_assessment_complete} = '2';

} # close sub

=pod


=HEAD1 These Notes here were in my main monolithic script, directly after the end
of the code block above (and therefore before where the biopsy code used to start)
I have moved the comments into this Assessment.pm Perl module just in case they
are relevant

N.B., In contrast to what I said in my queries to Jaselle, upon closer examination, among
the records that have something filled in for the COMMENTS2 field, there is not any
additional information regarding the Exam Type (that isn't already captured in
the PROCEDURE column, so I was wrong when I claimed that).

The Bone Response and the RECIST Response are radio buttons so they are mutually
exclusive for a given time point, is that correct? Hmmmm.

I am going to say that unless there is a Bone Scan then the Bone response
is N/A okay?
Hmmm, Jaselle clearly states that the RECISt response must be different than
the COMPARED_WITH_PREVIOUS_SCAN.  Oh, lets see if there are any entries in COMPARED WITH PREVIOUS
SCAN that are not in a bone? Oh yes, there are.  Hmmm.

=cut

sub iso_date {
    # Actually, except for the warning to STDERR this works alright, it converts
    # an inadvertent ' ' into a '' which I suppose is what you want
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, "for a patient in Package Assessment\n";
    }
    # $good_date = $bad_date;
    return $good_date;
} # close sub iso_date

1;

