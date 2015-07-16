package Trubble::Random;

use strict;
use warnings;


sub choose {
    my $body = shift;

    $body =~ s/^random:?\s*(.+)//;
    my @parts = split(/\s+/, $body);

    return $parts[rand @parts];
}

return 1;

