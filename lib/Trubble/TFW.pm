package Trubble::TFW;

use strict;
use warnings;

use URI;
use LWP::UserAgent;


sub tfw {
    my ($body) = @_;

    $body =~ s/^tfw\s*(.+)//;
    my $location = $1;

    return Trubble::TFW::get_response($location, 0);
}

sub tfwc {
    my ($body) = @_;

    $body =~ s/^tfw\s*(.+)//;
    my $location = $1;

    return Trubble::TFW::get_response($location, 1);
}

sub get_response {
    my ($location, $celsius) = @_;

    my $ua = LWP::UserAgent->new();
    $ua->agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:28.0) Gecko/20100101 Firefox/28.0");

    my $url = URI->new("http://thefuckingweather.com/");
    $url->query_form(where => $location);

    if ($celsius) {
        $url->query_form(unit => "c");
    }
    
    $url = $url->as_string();

    my $response = $ua->get($url);
    my $content = $response->decoded_content();

    $content =~ m!<span class="temperature" tempf="\d+">(\d+)</span>!;
    my $temperature = $1;

    $content =~ m!<p class="remark">(.+?)</p>!;
    my $remark = $1;

    my $msg = "";
    if ($celsius) {
        $msg = $temperature . "C: " . $remark;
    } else {
        $msg = $temperature . "F: " . $remark;
    }

    return $msg;
}

return 1;

