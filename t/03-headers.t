use v6;
use Test;
use HTTP::Tiny::Headers;

my $headers = HTTP::Tiny::Headers.new();

$headers.header('A', 'b');
$headers.header('a', 'c'); # replace it
is $headers.header('a'), 'c';

my @pairs = $headers.pairs();
is +@pairs, 1;


