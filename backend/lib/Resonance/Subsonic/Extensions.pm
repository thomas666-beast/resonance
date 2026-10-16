package Resonance::Subsonic::Extensions;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(extensions extension_names);

# Extensions we advertise to OpenSubsonic clients.
# Each entry: name, versions.
sub extensions () {
    return [
        { name => 'formPost',        versions => [1] },
        { name => 'transcodeOffset', versions => [1] },
        { name => 'songLyrics',      versions => [1] },
    ];
}

sub extension_names () {
    return [ map { $_->{name} } @{ extensions() } ];
}

1;
