use v6;

use Test;
use HTTP::Tiny;

my $ua = HTTP::Tiny.new;
subtest {
    my ($scheme, $host, $port, $path-query, $auth) = $ua.split-url("http://google.com/");
    is 'http', $scheme;
    is 'google.com', $host;
    is 80, $port;
}, 'http://google.com/';

