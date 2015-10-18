use v6;

unit class HTTP::Tiny::Request;

use HTTP::Tiny::Headers;

has Str $.method;
has Str $.scheme;
has Str $.host;
has Int $.port;
has Str $.path-query;
has HTTP::Tiny::Headers $.headers = HTTP::Tiny::Headers.new;

my %DefaultPort = http => 80, https => 443;

method host-port() {
    $!port == %DefaultPort{$!scheme} ?? $!host !! "$!host:$!port";
}

