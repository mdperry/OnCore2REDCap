package Bloodlabs;

use base 'Exporter';
our @EXPORT_OK = 'extract_labs';
our @EXPORT    = 'extract_labs';

=pod
   
PSA Lab Test, 

Standard Blood Labs or just simply, Labs

2017-09-26 It took quite a bit of debugging to get the different Blood lab results to 
appear in the printout in the proper place.  The Repeating Instruments for the PSA Labs were
relatively well-behaved, I just had to tweak the code such that the very first PSA Lab
was printed out on the Aggregator row.  To get the other values to appear, there were 
a few issues, I suppose. Hmmm, perhaps this was irrelevant: but some fields coming in from
OnCore were: '', hmmm.
The main problem was that I was processing four different screening rows, ignoring one or two
of these rows by filtering them out because there was no corresponding tests in REDCap, But as 
I was trying to accumulate the values from those fields into my data structure, I kept overwriting 
the values from earlier incoming rows, with the undef value, no, actually, my test was overwriting
the test results with 'ND' This was confusing for a good little while until I dumped out the
data structure for each incoming line and figured it out.  WARNING: This may resurface again
elsewhere in this processing(?)

2017-11-09 
Here are the maximum number of new REDCap Events and Instruments that I need to incorporate

pre_study_screen_arm_2-psa_lab_test
pre_study_screen_arm_2-labs
every_3_months_arm_2-psa_lab_test
progression_arm_2-psa_lab_test
progression_arm_2-labs
every_3_months_pos_arm_2-psa_lab_test
progression_2_arm_2-psa_lab_test
progression_2_arm_2-labs
every_3_months_pos_arm_2b-psa_lab_test
progression_3_arm_2-psa_lab_test
progression_3_arm_2-labs

In the SEGMENT column there are:
Five different strings.  Wow that is really a lot of Screening 
records isn't it?
   2 Follow-up
 156 Month 3
 230 Month 6 and every 3 months afterwards
 457 Progression/Study Termination
1234 Screening

Every patient_id has 5 Screening labs, and 2 have 6 while one
even has 7 

243     5
2       6
1       7

Generally four of the Screening lab records are NOT PSA and one is PSA
Which are the patients with more than five Screening Labs?
DTB-124
and
DTB-138 
each have 6 
and 
DTB-169 has 7 

DTB-124 has two Screening assays for the actual Blood draws, with Hematocrit, and WBC etc. And 
they are approx 2 weeks apart in the same year.  As far as I can tell they are both valid.
So presumably they would like to capture both of those.

That is the same deal for DTB-138, the Screening test that is repeated is the actual blood
and once again, two records, this time slightly less than 2 weeks apart.

For DTB-169 It does not seem like anything important was repeated.  There are two records that
are blank and that I would've filtered out.

Now what about the Screening records that are for the PSA tests? One, exactly one per patient
in this OnCore table.  So previously, the PSA lab tests were NOT agreggated into the big data structure?
Or were they? See below, yes they were. A screening one was.

From reading below I have discovered a few things.  For the PSA Lab tests, if it
was the very first one then I would report it in the aggregator data structure, and the very first one was always
the Screening segment, I gather.  Any other PSA tests were reported below in a separate record and they
were all treated like 3 month repeating PSA tests (even if they were Progression or Follow-up I guess)

Now I am a bit confused because . . . I thought, for some reason, which I don't precisely recall
right now, that if a record was captured below in a repeating instrument then it could't be stored
in the Aggregator data structure(?!?).  No that is clearly incorrect because I have those tests
where I count things, right?

Okay let's write it down again here.  If a redcap instrument can be filled out multiple
times during the same redcap event, that that is by definition a so-called repeating
instrument.  So for example, disease_radiographic_assessment can occur in the
screening arm, AND in the every 3 month arm. However in the Screening arm there is only
ever a single disease_radiographic_assessment, so that instrument is NOT repeating
at that timepoint.  However in the 3 month arm event it IS a repeating instrument because
there can/will be multiple assessments every 3 months.  So it is not the fact that
an instrument gets its data stored in the Screening Arm that makes it non-repeating
it is that there are NOT multiple Screening arm assessments.  If there are
multiple Screening arm anything (instrument) then the results of the form
cannot, by definition, be a repeating instrument.

UPDATE, instead of trying to guess and infer I actually went in and figured 
out which instruments in the current project are repeating.
patient_disposition
screening_preenrollment_treatment
every_3_months-PSA
every_3_months-radiographic_disease_assessment

That is all, as it currently stands.

So circle around, what about the two records with Follow-up in their
SEGMENT in this table?
DTB-085 Has two labs, one is a PSA and one . . . isn't
This patient has 3 PSA LAB results, one each for:
Screening
Progression
Follow-up

He has two alk-phos/LDH lab results, one for Screening and one for Follow-up
And then he has Screening Row that I am not going to capture, One Screening row
for real blood work, and one Screening Row for the Testosterone assay.

So there are NO every 3 months things.  Since he has a progression PSA, I am going to
guess that he went to Progression within the first 3 months (or six months) and therefore
he went off study after that so he has a followup.  Oh, but it seems like . . . there is
no event for follow up for psa lab, okay I am going to skip it for now.  There is only
follow up after a progression biopsy, I think and only for radiographic assessment.
Radiographic assessment is the only table that has followup in REDCap

So, now I need an example from this blood labs table of a patient that has the most
different SEGMENTS to see how I will handle it.
There are about 30 or so that have at least 4 different types of entries
4       098
4       153
4       178

These patients have the most records in total 
14      153 <- And this one
14      178 <- This one too
15      011
15      013
16      098 <- This one could be a good example

I will start with DTB-098 and see if I can come up with a logical flow
Then test it on the whole data set, and check DTB-153 and DTB-178 in the output
Table to see if I think they were handled correctly.
DTB-098 Has
5	Screening 1 PSA
1	Month 3 1 PSA
5	Month 6 and every 3 months afterwards 5 PSA
5	Progression/Study Termination 2 PSA, 1 alk_phos, 1 testosterone, 1 blank row

So that means Yes, I can match on Month and call that repeating, Oh-Ho, I definitely need to get a repeating Progression
for PSA, right? So I need to count the instance for all PSA except screening, and wait, is there even a labs in Progression?
Yes, there is.

So a cursory, semi-detailed, analysis of the resulting DTB-098 seems pretty good for transferring the different labs and psa-labs
to REDCap, but lets check out the other two (for validation)
DTB-153 Yes, checks out fine, as expected/predicted
DTB-178 Yes, this one also looks good to me in the final table.  In other words
There is a single Screening Stage PSA lab test and then there are four other blood labs results at the Screening Stage
in OnCore that get aggregated into one record (I think one gets ignored).  There follows five separate PSA lab tests every
3 months before Progression, then at the Progression stage there is one more PSA lab test and one more blood lab test from the same date
but appearing on separate lines, which I think is how I want it.  So to a first approximation I believe that this
Perl Module is now working as advertised.

=cut

sub extract_labs {
    my $patient_id = shift @_;
    my %hash = %{shift @_};
    my $redcap = shift @_;
    my @fields_to_print = shift @_;

    my $segment = q{};
    my $screening = q{};
    my $progression = q{};
    my $every_3_months = q{};
    my $event = q{};
    my $psa_date = q{};
    my $visit_date = q{};
    my $instance = q{};
    
    if ( $hash{SEGMENT} ) {
        $segment = $hash{SEGMENT};
    }
    else {
        next;
    }

    if ( $segment =~ m/Screening/ ) {
        $screening = '1';
    }
    elsif ( $segment =~ m/Progression/ ) {
        $progression = '1';
    }
    elsif ( $segment =~ m/Month/ ) {
	$every_3_months = '1';
    }
    else {
        next; # skipping 'Follow-up' for now
    }
    
    # Is the current record for a PSA Test?
    if ( $hash{PSA__COMPLEXED__DIRECT_MEASUREME} ) {
        if ( $segment =~ m/Screening/ ) {
            $event = 'pre_study_screen_arm_2-BLANK';
        }
        elsif ( $segment =~ m/Progression/ ) {
	    $event = 'progression_arm_2-psa_lab_test';
        }
        elsif ( $segment =~ m/Month/ ) {
 	    $event = 'every_3_months_arm_2-psa_lab_test';
        }

	if ( $hash{VISIT_DATE} ) {
            $psa_date = iso_date( $hash{VISIT_DATE} );
        }
	# Is this a Screening PSA Test?
        if ( $screening ) {
	    # if so, then the values go into the aggregator data structure
            $redcap->{$patient_id}{$event}{psa_date} = $psa_date;
            $redcap->{$patient_id}{$event}{psa_value} = $hash{PSA__COMPLEXED__DIRECT_MEASUREME};
            $redcap->{$patient_id}{$event}{psa_lab_test_complete} = '2';
	}
        elsif ( $every_3_months || $progression ) {
            # Otherwise this is a repeating REDCap Instrument PSA Test and we
            # need to initialize all of the variables in the data structure
            # Q: For this specific patient_id, how many rows from the OnCore blood
	    # labs table have already been processed?
            # A: Count the number of defined elements in this array
            if ( $redcap->{$patient_id}{$event} ) {
      	        my $value = scalar( keys %{$redcap->{$patient_id}{$event}} );
                # if the array has defined elements then add '1' to that number, and that will
	        # become the number of the current instance we are processing
                $instance = $value + 1;
            }
            else {
                # otherwise, this MUST be the very first instance 
                # (of the repeating instruments/forms), so number it thusly:
                $instance = 1;
	    } # close if/else test

            # initialize all of the hash key/column field names for this row in the
            # REDCap import TSV file, even though we are only going to fill in 3 or 4 values
            foreach my $field ( @fields_to_print ) {
                $redcap->{$patient_id}{$event}{$instance}{$field} = undef;
	    } # close foreach
	    $redcap->{$patient_id}{$event}{$instance}{psa_date} = $psa_date;
            $redcap->{$patient_id}{$event}{$instance}{psa_value} = $hash{PSA__COMPLEXED__DIRECT_MEASUREME};
            $redcap->{$patient_id}{$event}{$instance}{psa_lab_test_complete} = '2';
	}
    } # close if ( $hash{PSA__COMPLEXED__DIRECT_MEASUREME} )
    else {
        # The current record being process is therefore NOT a PSA test, which means that the blood lab
        # results might go in the aggregator,
        # However it turns out that there are other rows, that are NOT Screening and Not PSA but
        # which may have blood lab tests to capture (I believe).  Any like that in REDCap now? Nope
        # I was feeling perplexed about how to handle all of the actual EMPTY rows in this OnCore table but
        # I think I have a way to do so, to filter the unwanted ones out

        # So this record is either a Screening Blood Lab record, OR a Progression Blood Lab record
	# but we need to aggregate any related records under the same date.  Also, I just checked the spreadsheets
	# where I had parsed the OnCore Blood labs table based on +/- Screening and +/- PSA and while there are about a dozen
	# Month 3 or Month 6 rows that do not contain a PSA lab test THEY ARE ALL EMPTY so my script will skip over them
	# For the non-Screening, non-PSA lab tests they mainly seem to be alk_phos or testosterone, plus the stuff that
	# PROMOTE does not collect

            # Check the current contents of the data structure being built.
            # Only enter this block of code when one of the two situations has occurred:
            # Either (A.), the wbc_n_value hash key evaluates to 'FALSE' (which means it is empty),
            # OR,
            # (B.) that hash key contains the value 'ND'
            # In either situation, we want to see if there is a new value in the record we are currently processing from OnCore
            # What I don't want to do is overwrite a good value in the data structure (from parsing a previous record) with
            # an empty or blank value from this record.
	
        next unless ( $hash{LDH_} || $hash{ALKALINE_PHOSPHATASE} || $hash{TESTOSTERONE__TOTAL} || $hash{HEMOGLOBIN} );

	# If this is a Screening record then we already have an initialized data structure, but if this is a Progression
	# record then . . . we do not have a data structure pre-initialized so we need to create one.
	# DIGRESSION: If I really, really needed to I could incorporate the date in my processing so that
	# Progression lab tests for the same date would be in one instrument, but right now I really cannot be bothered to get
	# that fancy, so each OnCore Record for Progession will translate directly into a single REDCap record
        if ( $segment =~ m/Screening/ ) {
            $event = 'pre_study_screen_arm_2-BLANK';
        }
        elsif ( $segment =~ m/Progression/ ) {
	    $event = 'progression_arm_2-labs';
        }

	if ( $progression ) {
	    if ( $redcap->{$patient_id}{$event} ) {
      	        my $value = scalar( keys %{$redcap->{$patient_id}{$event}} );
                # if the array has defined elements then add '1' to that number, and that will
	        # become the number of the current instance we are processing
                $instance = $value + 1;
            }
            else {
                # otherwise, this MUST be the very first instance 
                # (of the repeating instruments/forms), so number it thusly:
                $instance = 1;
	    } # close if/else test

            # initialize all of the hash key/column field names for this row in the
            # REDCap import TSV file, even though we are only going to fill in 3 or 4 values
            foreach my $field ( @fields_to_print ) {
                $redcap->{$patient_id}{$event}{$instance}{$field} = undef;
	    } # close foreach
        } # close if ( $progression )
	
        if ( $hash{VISIT_DATE} ) {
            $lab_date = iso_date( $hash{VISIT_DATE} );
        }	

	if ( $screening ) {
            $redcap->{$patient_id}{$event}{lab_date} = $lab_date;
	}
	elsif ( $progression ) {
            $redcap->{$patient_id}{$event}{$instance}{lab_date} = $lab_date;
	}
	        
        if ( $screening ) {
	    if ( !$redcap->{$patient_id}{$event}{alp_value} || $redcap->{$patient_id}{$event}{alp_value} eq 'ND' ) {
                if ( $hash{ALKALINE_PHOSPHATASE} ) {
                    $redcap->{$patient_id}{$event}{alp_value} = $hash{ALKALINE_PHOSPHATASE};
                }
                else {
                    $redcap->{$patient_id}{$event}{alp_value} = 'ND';        
                } # close if/else test
	    }
	}
	elsif ( $progression ) {
            if ( $hash{ALKALINE_PHOSPHATASE} ) {
                $redcap->{$patient_id}{$event}{$instance}{alp_value} = $hash{ALKALINE_PHOSPHATASE};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{alp_value} = 'ND';        
            } # close if/else test
	}

	 if ( $screening ) {   
            if ( !$redcap->{$patient_id}{$event}{ldh_value} || $redcap->{$patient_id}{$event}{ldh_value} eq 'ND' ) {
                if ( $hash{LDH_} ) {
                    $redcap->{$patient_id}{$event}{ldh_value} = $hash{LDH_};
                }
                else {
                    $redcap->{$patient_id}{$event}{ldh_value} = 'ND';
                } # close if test
	    }
	}
	elsif ( $progression ) {
            if ( $hash{LDH_} ) {
                $redcap->{$patient_id}{$event}{$instance}{ldh_value} = $hash{LDH_};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{ldh_value} = 'ND';
            } # close if test
	}

        if ( $screening ) {        
	    if ( !$redcap->{$patient_id}{$event}{tst_value} || $redcap->{$patient_id}{$event}{tst_value} eq 'ND' ) {
                if ( $hash{TESTOSTERONE__TOTAL} ) {
                    $redcap->{$patient_id}{$event}{tst_value} = $hash{TESTOSTERONE__TOTAL};
                }
                else {
                    $redcap->{$patient_id}{$event}{tst_value} = 'ND';
                } # close if test
            }
	}
	elsif ( $progression ) {
            if ( $hash{TESTOSTERONE__TOTAL} ) {
                $redcap->{$patient_id}{$event}{$instance}{tst_value} = $hash{TESTOSTERONE__TOTAL};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{tst_value} = 'ND';
            } # close if test
	}

        if ( $screening ) {
	    # Remember, undef evaluates to 'FALSE'
            if ( !$redcap->{$patient_id}{$event}{hgb_value} || $redcap->{$patient_id}{$event}{hgb_value} eq 'ND' ) {
                if ( $hash{HEMOGLOBIN} ) {
                    $redcap->{$patient_id}{$event}{hgb_value} = $hash{HEMOGLOBIN};
                }
                else {
                    $redcap->{$patient_id}{$event}{hgb_value} = 'ND';
                } # close if test
	    }
	}
	elsif ( $progression ) {
            if ( $hash{HEMOGLOBIN} ) {
                $redcap->{$patient_id}{$event}{$instance}{hgb_value} = $hash{HEMOGLOBIN};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{hgb_value} = 'ND';
            } # close if test
	}

	if ( $screening ) {
	    if ( !$redcap->{$patient_id}{$event}{plt_value} || $redcap->{$patient_id}{$event}{plt_value} eq 'ND' ) {
                if ( $hash{PLATELETS} ) {
                    $redcap->{$patient_id}{$event}{plt_value} = $hash{PLATELETS};
                }
                else {
                    $redcap->{$patient_id}{$event}{plt_value} = 'ND';
                } # close if test
	    }
	}
	elsif ( $progression ) {
            if ( $hash{PLATELETS} ) {
                $redcap->{$patient_id}{$event}{$instance}{plt_value} = $hash{PLATELETS};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{plt_value} = 'ND';
            } # close if test
	}

        if ( $screening ) {
 	    if ( !$redcap->{$patient_id}{$event}{wbc_value} || $redcap->{$patient_id}{$event}{wbc_value} eq 'ND' ) {
                if ( $hash{WBC} ) {
                    $redcap->{$patient_id}{$event}{wbc_value} = $hash{WBC};
                }
                else {
                    $redcap->{$patient_id}{$event}{wbc_value} = 'ND';
                } # close if test
	    }
	}
	elsif ( $progression ) {
            if ( $hash{WBC} ) {
                $redcap->{$patient_id}{$event}{$instance}{wbc_value} = $hash{WBC};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{wbc_value} = 'ND';
            } # close if test
	}

	if ( $screening ) {
	    if ( !$redcap->{$patient_id}{$event}{wbc_n_value} || $redcap->{$patient_id}{$event}{wbc_n_value} eq 'ND' ) {
                # don't test for defined here because the empty string is 'defined'
                if ( $hash{WBC_NEUTROPHILS} ) {
                    $redcap->{$patient_id}{$event}{wbc_n_value} = $hash{WBC_NEUTROPHILS};
                }
                else {
                    $redcap->{$patient_id}{$event}{wbc_n_value} = 'ND';
                } # close if test
            }
	}
	elsif ( $progression ) {
            if ( $hash{WBC_NEUTROPHILS} ) {
                $redcap->{$patient_id}{$event}{$instance}{wbc_n_value} = $hash{WBC_NEUTROPHILS};
            }
            else {
                $redcap->{$patient_id}{$event}{$instance}{wbc_n_value} = 'ND';
            } # close if test
	}

	if ( $screening ) {
            $redcap->{$patient_id}{$event}{albumin_value} = 'ND';
            $redcap->{$patient_id}{$event}{labs_complete} = '2';
        }
        elsif ( $progression ) {
            $redcap->{$patient_id}{$event}{$instance}{albumin_value} = 'ND';
            $redcap->{$patient_id}{$event}{$instance}{labs_complete} = '2';
        }
    } # close main outer if/else test
} # close sub


sub iso_date {
    my $good_date = q{};
    my $bad_date = shift @_;
    if ( $bad_date =~ m/\d\d-\d\d-\d\d\d\d/ ) {
        my ( $month, $day, $year, ) = split( /-/, $bad_date );
        $good_date = $year . '-' . $month . '-' . $day;
    }
    else {
        print STDERR "Could not properly parse this as a date:\t", $bad_date, " for patient $patient_id in Package Bloodlabs\n";
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

