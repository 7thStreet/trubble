package Trubble::Dinklage;

use strict;
use warnings;


my @dinklages = ();


sub check_for_dinklage {
    my $message = shift;

    if ($message =~ /dinklage/i) {
        push(@dinklages, time());

        # play clears
        if ($message =~ /^ygor: dinklage$/) {
            while (scalar(@dinklages)) {
                shift(@dinklages);
            }
        }

        while (scalar(@dinklages) > 20) {
            shift(@dinklages);
        }

        if (scalar(@dinklages) < 20) {
            return;
        }

        # if it's been said 20 times within the past two minutes, set our guns to troll
        my $min_dinklage = $dinklages[0];
        my $max_dinklage = $dinklages[19];

        if ($max_dinklage - $min_dinklage <= 120) {

            # us trolling clears the queue
            while (scalar(@dinklages)) {
                shift(@dinklages);
            }

            return "ygor: dinklage";
        }

    }
}

return 1;

