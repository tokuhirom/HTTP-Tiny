use v6;
unit class HTTP::Tiny;

my class HTTP::Tiny::Handle {
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
}

has $.cookie_jar;
has $.default-headers;
has $.http-proxy;
has $.https-proxy;
has Bool $.keep-alive = True;
has $.local-address;
has Int $.max-redirect = 5;
has $.max_size;
has $.proxy;
has Set $.no-proxy;
has Int $.timeout = 60;
has $.SSL_options;
has Bool $.verify_SSL = True;
has Str $.agent = "HTTP::Tiny/Perl6"; # TODO: inject library version
has %.has-proxy;

has $!handle;

method new(*%args) {
    %args = self!init-proxies(%args);
    self.bless(|%args)!initialize();
}

method !initialize() {
    # TODO: $class->_validate_cookie_jar( $args{cookie_jar} ) if $args{cookie_jar};
    self;
}

method !init-proxies(%args) {
    # get proxies from %ENV only if not provided; explicit undef will disable
    # getting proxies from the environment

    # generic proxy
    unless %args<proxy>:exists {
        %args<proxy> = %*ENV<all_proxy> || %*ENV<ALL_PROXY>;
    }

    if %args<proxy>.defined {
        self!split-proxy( 'generic proxy' => %args<proxy> ); # validate
    } else {
        %args<proxy>:delete;
    }

    # http proxy
    if ! %args<http_proxy> {
        # under CGI, bypass HTTP_PROXY as request sets it from Proxy header
        temp %*ENV<HTTP_PROX> = Nil if %*ENV<REQUEST_METHOD>;
        %args<http_proxy> = %*ENV<http_proxy> || %*ENV<HTTP_PROXY> || %args<proxy>;
    }

    if %args<http_proxy>.defined {
        self!split-proxy( http_proxy => %args<http_proxy> ); # validate
        %args<has-proxy><http> = True;
    }
    else {
        %args<http_proxy>:delete;
    }

    # https proxy
    unless %args<https_proxy>:exists {
        %args<https_proxy> = %*ENV<https_proxy> || %*ENV<HTTPS_PROXY> || %args<proxy>;
    }

    if %args<https_proxy> {
        self!split-proxy( https_proxy => %args<https_proxy> ); # validate
        %args<has-proxy><https> = True;
    }
    else {
        %args<https_proxy>:delete;
    }

    # Split no_proxy to array reference if not provided as such
    %args<no_proxy> = do {
        %args<no_proxy> //= %*ENV<no_proxy>;

        if %args<no_proxy> {
            given %args<no_proxy> {
                when Str {
                    set(%args<no_proxy>.split(/\s*\,\s*/));
                }
                when Set {
                    %args<no_proxy>;
                }
                when Array {
                    set(|%args<no_proxy>);
                }
                default {
                    die "Invalid argument type for no_proxy: {%args<no_proxy>.WHAT}";
                }
            }
        } else {
            set();
        }
    };

    return %args;
}

BEGIN {
    for <get head put post delete> -> $method {
        ::?CLASS.^add_method($method, method ($url) {
            self.request($method, $url);
        });
    }
}

my class X::HTTP::Tiny::InvalidProxyURL {
    has $.type;
    has $.url;

    method message() {
        return qq{$!type URL must be in format http[s]://[auth@]<host>:<port>/\n};
    }
}

method !split-proxy(Str $type, Str $proxy) {
    my ($scheme, $host, $port, $path-query, $auth) = self.split-url($proxy);
    return ($scheme, $host, $port, $auth);

    CATCH {
        X::HTTP::Tiny::InvalidProxyURL.new(type => $type, url => $proxy).throw;
    }
}

method request(Str $method, Str $url) {
    return self!request($method, $url);

    CATCH {
        my $resp = HTTP::Tiny::Response.new();
        $resp.status(599);
        $resp.reason('Internal Exception');
        $resp.content-type('text/plain');
        $resp.content($_);
        return $resp;
    }
}

my %DefaultPort = http => 80, https => 443;

method !request(Str $method, Str $url) {
    my ($scheme, $host, $port, $path_query, $auth) = self.split-url($url);

    my $request = {
        method    => $method,
        scheme    => $scheme,
        host      => $host,
        port      => $port,
        host_port => ($port == %DefaultPort{$scheme} ?? $host !! "$host:$port"),
        uri       => $path_query,
        headers   => {},
    };

    # We remove the cached handle so it is not reused in the case of redirect.
    # If all is well, it will be recached at the end of _request.  We only
    # reuse for the same scheme, host and port
    my $handle = $!handle;
    if $handle {
        $!handle = Nil;

        unless $handle.can-reuse( $scheme, $host, $port ) {
            $handle.close;
            $handle = Nil;
        }
    }
    $handle //= self!open-handle( $request, $scheme, $host, $port );

}

method !open-handle($request, Str $scheme, Str $host, Int $port) {
    my $handle  = HTTP::Tiny::Handle.new(
        timeout         => $.timeout,
        SSL-options     => $.SSL-options,
        verify-SSL      => $.verify-SSL,
        local-address   => $.local-address,
        keep-alive      => $.keep-alive
    );

    if %.has-proxy{$scheme} && ! $.no-proxy{$host} {
        return self!proxy-connect( $request, $handle );
    } else {
        return $handle.connect($scheme, $host, $port);
    }
}

method proxy-connect($request, $handle) {
    my @proxy_vars;
    if ( $request<scheme> eq 'https' ) {
        die qq{No https_proxy defined} unless $!https_proxy>;
        @proxy_vars = $self!split-proxy( 'https_proxy', $!https_proxy );
        if $proxy_vars[0] eq 'https' {
            die qq{Can't proxy https over https: {$request<uri>} via {$self<https_proxy>}};
        }
    }
    else {
        die qq{No http_proxy defined} unless $!http_proxy;
        @proxy_vars = $self!split-proxy( 'http_proxy', $!http_proxy );
    }

    my ($p_scheme, $p_host, $p_port, $p_auth) = @proxy_vars;

    if $p_auth.elems > 0 && ! $request<headers><proxy-authorization>.defined {
        self!add-basic-auth-header( $request, 'proxy-authorization' => $p_auth );
    }

    $handle.is-proxy(True);
    $handle.connect($p_scheme, $p_host, $p_port);

    if ($request<scheme> eq 'https') {
        $self!create-proxy-tunnel( $request, $handle );
    } else {
        # non-tunneled proxy requires absolute URI
        $request<uri> = "$request->{scheme}://$request->{host_port}$request->{uri}";
    }

    return $handle;
}

grammar URLGrammar {
    token TOP { <scheme> '://' [ <auth> '@' ]? <host> [ ':' <port>  ]? <path-query> .*? }
    token auth { <user> ':' <host>+ }
    token user { <-[ \/ \? \# \@ ]>+ }
    token host { <-[ \/ \? \# \@ \: ]>+ }
    token port { <[0 .. 9]>+ }
    token path-query { <-[ \# ]>+ }
    token scheme { <-[ : / \? \# ]>+ }
}

method split-url(Str $url) {
    my $parsed = URLGrammar.parse($url);
    if $parsed {
        my $scheme = ~$<scheme>;
        my $host = $<host>:exists ?? $<host>.Str.lc !! 'localhost';
        my $port = do {
            if $<port>:exists {
                $<port>.Int;
            } else {
                given $scheme {
                    when 'http' {
                        $port = 80
                    }
                    when 'https' {
                        $port = 443
                    }
                    default {
                        Nil
                    }
                }
            }
        }

        my $path-query = ~$<path-query>;

        my $auth;
        if $<auth>:exists {
            $<auth>.Str.subst(/\%(<[0..9 A..F a..f]> ** 2)/, -> $/ { chr(:16(~$/[0])) }, :global);
        }

        return $scheme, $host, $port, $path-query, $auth;
    } else {
        X::HTTP::Tiny::InvalidURL.new(url => $url).throw;
    }
}

=begin pod

=head1 NAME

HTTP::Tiny - blah blah blah

=head1 SYNOPSIS

  use HTTP::Tiny;

=head1 DESCRIPTION

HTTP::Tiny is ...

=head1 AUTHOR

Tokuhiro Matsuno <tokuhirom@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2015 Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
