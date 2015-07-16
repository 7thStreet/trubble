package Trubble::Lunch;


sub get_response {
    my @vals = localtime();
    if ($vals[2] < 1) {
        return "no. too early.";
    }
    return undef;
}

return 1;

