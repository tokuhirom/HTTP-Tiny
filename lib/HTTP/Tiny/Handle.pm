use v6;

unit class HTTP::Tiny::Handle;

has $.fh;

has $.timeout;
has $.SSL-options;
has Bool $.verify-SSL is required;
has $.local-address;
has Bool $.keep-alive;

method can-reuse() {
    False; # TODO
}

method close() {
    $.fh.close;
}

