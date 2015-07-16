package Trubble::Countdown;

use strict;
use warnings;

use Time::Piece;
use Time::Seconds;

use Try::Tiny;


sub get_countdown {
    my ($is_countdown, $is_countup, $countdown_name) = @_;

    my $make_until_date_func = sub {
        my ($name, $dates) = @_;

        return sub {
            my $current_date = shift;

            my $next_start = undef;
            for my $dates (@$dates) {
                my $start_date = $dates->[0];
                my $end_date = $dates->[1];

                if (!defined($next_start) && $current_date < $start_date) {
                    $next_start = $start_date;
                } elsif ($start_date <= $current_date && $current_date < $end_date) {
                    return "it's already $name...";
                }
            }

            my $delta = $next_start - $current_date;
            my $days = int($delta->days);
            return $days . ($days == 1 ? " day " : " days ") . "until $name";

            };
    };

    my $spring_dates = [
        [Time::Piece->strptime("2014-03-20", "%Y-%m-%d"), Time::Piece->strptime("2014-06-20", "%Y-%m-%d")],
        [Time::Piece->strptime("2015-03-20", "%Y-%m-%d"), Time::Piece->strptime("2015-06-20", "%Y-%m-%d")],
        [Time::Piece->strptime("2016-03-20", "%Y-%m-%d"), Time::Piece->strptime("2016-06-21", "%Y-%m-%d")],
        [Time::Piece->strptime("2017-03-20", "%Y-%m-%d"), Time::Piece->strptime("2017-06-21", "%Y-%m-%d")],
        [Time::Piece->strptime("2018-03-20", "%Y-%m-%d"), Time::Piece->strptime("2018-06-21", "%Y-%m-%d")],
    ];
    my $spring_func = &$make_until_date_func("spring", $spring_dates);

    my $summer_dates = [
        [Time::Piece->strptime("2014-06-20", "%Y-%m-%d"), Time::Piece->strptime("2014-09-23", "%Y-%m-%d")],
        [Time::Piece->strptime("2015-06-20", "%Y-%m-%d"), Time::Piece->strptime("2015-09-23", "%Y-%m-%d")],
        [Time::Piece->strptime("2016-06-21", "%Y-%m-%d"), Time::Piece->strptime("2016-09-22", "%Y-%m-%d")],
        [Time::Piece->strptime("2017-06-21", "%Y-%m-%d"), Time::Piece->strptime("2017-09-22", "%Y-%m-%d")],
        [Time::Piece->strptime("2018-06-21", "%Y-%m-%d"), Time::Piece->strptime("2018-09-23", "%Y-%m-%d")],
    ];
    my $summer_func = &$make_until_date_func("summer", $summer_dates);

    my $fall_dates = [
        [Time::Piece->strptime("2014-09-23", "%Y-%m-%d"), Time::Piece->strptime("2014-12-21", "%Y-%m-%d")],
        [Time::Piece->strptime("2015-09-23", "%Y-%m-%d"), Time::Piece->strptime("2015-12-22", "%Y-%m-%d")],
        [Time::Piece->strptime("2016-09-22", "%Y-%m-%d"), Time::Piece->strptime("2016-12-21", "%Y-%m-%d")],
        [Time::Piece->strptime("2017-09-22", "%Y-%m-%d"), Time::Piece->strptime("2017-12-21", "%Y-%m-%d")],
        [Time::Piece->strptime("2018-09-23", "%Y-%m-%d"), Time::Piece->strptime("2018-12-21", "%Y-%m-%d")],
    ];
    my $fall_func = &$make_until_date_func("fall", $fall_dates);

    my $winter_dates = [
        [Time::Piece->strptime("2014-12-21", "%Y-%m-%d"), Time::Piece->strptime("2015-03-20", "%Y-%m-%d")],
        [Time::Piece->strptime("2015-12-22", "%Y-%m-%d"), Time::Piece->strptime("2016-03-20", "%Y-%m-%d")],
        [Time::Piece->strptime("2016-12-21", "%Y-%m-%d"), Time::Piece->strptime("2017-03-20", "%Y-%m-%d")],
        [Time::Piece->strptime("2017-12-21", "%Y-%m-%d"), Time::Piece->strptime("2018-03-20", "%Y-%m-%d")],
        [Time::Piece->strptime("2018-12-21", "%Y-%m-%d"), Time::Piece->strptime("2019-03-20", "%Y-%m-%d")],
    ];
    my $winter_func = &$make_until_date_func("winter", $winter_dates);

    my $obama_func = sub {
        my $current_date = shift;

        my $target_date = Time::Piece->strptime("2017-01-20", "%Y-%m-%d");

        if ($current_date < $target_date) {
            my $delta = $target_date - $current_date;
            my $days = int($delta->days);

            return $days . ($days == 1 ? " day " : " days ") . "until obama returns to chicago";
        } else {
            return "obama must already be back in chicago...";
        }
    };

    my $ryan_func = sub {
        return "r͢ỳa͡n ҉co͘m͢e͏s";
    };

    my $jen_func = sub {
        return "0 days until jen chen bitching";
    };

    my $elevator_func = sub {
        my $current_date = shift;

        my $begin_date = Time::Piece->strptime("2012-09-25", "%Y-%m-%d");

        my $delta = $current_date - $begin_date;
        my $days = int($delta->days);

        return $days . " days without being beat up in the elevator";
    };

    my $bnerx_func = sub {
        return "a month and a half";
    };

    my $onerx_func = sub {
        my $current_date = shift;

        my $target_date = Time::Piece->strptime("2015-07-15", "%Y-%m-%d");

        if ($current_date < $target_date) {
            my $delta = $target_date - $current_date;
            my $days = int($delta->days);

            return $days . ($days == 1 ? " day " : " days ") . "until onerx";
        } else {
            return "onerx must already be launched...";
        }
    };

    my %countdown_funcs = (
        "spring" => $spring_func,
        "summer" => $summer_func,
        "fall" => $fall_func,
        "autumn" => $fall_func,
        "winter" => $winter_func,
        "obama back to chicago" => $obama_func,
        "ryan" => $ryan_func,
        "jen chen bitching" => $jen_func,
        "elevator beating" => $elevator_func,
        "bnerx" => $bnerx_func,
        "onerx" => $onerx_func,
    );

    my $make_until_month_func = sub {
        my ($name, $month) = @_;

        my $dates = [];
        for my $year (qw(2014 2015 2016 2017 2018 2019)) {
            my $next_month = $month + 1;
            my $next_year = $year;
            if ($next_month == 13) {
                $next_month = 1;
                $next_year = $year + 1;
            }

            push(@$dates, [
                Time::Piece->strptime("$year-$month-01", "%Y-%m-%d"),
                Time::Piece->strptime("$next_year-$next_month-01", "%Y-%m-%d"),
            ]);
        }

        return &$make_until_date_func($name, $dates);
    };

    my $months = {
        "january" => 1,
        "february" => 2,
        "march" => 3,
        "april" => 4,
        "may" => 5,
        "june" => 6,
        "july" => 7,
        "august" => 8,
        "september" => 9,
        "october" => 10,
        "november" => 11,
        "movember" => 11,
        "december" => 12,
    };

    for my $name (keys %$months) {
        $countdown_funcs{$name} = &$make_until_month_func($name, $months->{$name});
    }

    my $current_date = localtime();

    if (!defined($countdown_funcs{$countdown_name})) {
        my $ret = "";
        try {
            my $dates = [[
                 Time::Piece->strptime($countdown_name, "%Y-%m-%d"),
                 Time::Piece->strptime($countdown_name, "%Y-%m-%d") + ONE_DAY,
            ]];
            my $date_func = &$make_until_date_func($countdown_name, $dates);
            $ret = &$date_func($current_date);
        } catch {
            $ret = "unknown countdown '$countdown_name'";
        };
        return $ret;
    }

    return $countdown_funcs{$countdown_name}($current_date);
}

return 1;

