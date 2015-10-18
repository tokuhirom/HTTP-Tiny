use v6;
use Test;
use HTTP::Tiny::Request;
use HTTP::Tiny::Headers;

my $req = HTTP::Tiny::Request.new;
isa-ok $req.headers, HTTP::Tiny::Headers;

