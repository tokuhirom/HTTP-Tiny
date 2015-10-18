use v6;

unit class HTTP::Tiny::Headers;

has %!headers;

method new(*%args) {
    my $self = self.bless();
    for %args.kv -> $key, $value {
        $self.push-header($key, $value);
    }
    $self;
}

method push-header(Str $key, Str $value) {
    %!headers.push($key.lc() => $value);
}

multi method header(Str $key) {
    my $value = %!headers{$key.lc};
    $value ?? $value[0] !! Nil;
}

multi method header(Str $key, Str $value) {
    %!headers{$key.lc} = [$value];
}

method header-all(Str $key) {
    my $value = %!headers{$key.lc};
    $value ?? @$value !! ();
}

method pairs() {
    gather {
        for %!headers.kv -> $k, $v {
            for $v {
                take $k => $v;
            }
        }
    }
}

method remove-header(Str $key) {
    %!headers{$key.lc};
}


