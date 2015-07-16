package Trubble::Random;

use strict;
use warnings;


sub choose {
    my $body = shift;

    $body =~ s/^weather\s*(.+)//;
    my @parts = split(/\s+/, $body);

    return $parts[rand @parts];
}

return 1;

