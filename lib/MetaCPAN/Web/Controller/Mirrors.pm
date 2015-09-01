package MetaCPAN::Web::Controller::Mirrors;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Web::Controller' }

sub index : Path {
    my ( $self, $c ) = @_;

    $c->add_surrogate_key('MIRRORS');
    $c->res->header(
        'Cache-Control' => 'max-age=' . $c->cdn_times->{one_day} );
    $c->cdn_cache_ttl( $c->cdn_times->{one_day} );

    my $location;
    my @protocols;
    if ( my $q = $c->req->parameters->{q} ) {
        my @parts = split( /\s+/, $q );
        foreach my $part (@parts) {
            push( @protocols, $part )
                if ( grep { $_ eq $part } qw(http ftp rsync) );
        }
        if ( $q =~ /loc\:([^\s]+)/ ) {
            $location = [ split( /,/, $1 ) ];
        }
    }

    my @or;
    push( @or, { not => { filter => { missing => { field => $_ } } } } )
        for (@protocols);

    my $cv   = AE::cv();
    my $data = $c->model('API')->request(
        '/mirror/_search',
        {
            size  => 999,
            query => { match_all => {} },
            @or ? ( filter => { and => \@or } ) : (),
            $location
            ? (
                sort => {
                    _geo_distance => {
                        location => [ $location->[1], $location->[0] ],
                        order    => 'asc',
                        unit     => 'km'
                    }
                }
                )
            : ( sort => [ 'continent', 'country' ] )
        }
    )->recv;
    my $latest = [
        map {
            {
                %{ $_->{_source} }, distance => $location
                    ? $_->{sort}->[0]
                    : undef
            }
        } @{ $data->{hits}->{hits} }
    ];
    $c->stash(
        {
            mirrors  => $latest,
            took     => $data->{took},
            total    => $data->{hits}->{total},
            template => 'mirrors.html',
        }
    );
}

__PACKAGE__->meta->make_immutable;

1;
