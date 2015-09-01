use strict;
use warnings;
use Test::More;
use MetaCPAN::Web::Test;
use Try::Tiny;
use MetaCPAN::Web;
use MetaCPAN::Web::Controller::Feed;

sub get_feed_ok {
    my ( $cb, $test, $extra ) = @_;
    subtest $test => sub {
        ok( my $res = $cb->( GET $test), $test );
        is( $res->code, 200, 'code 200' );
        is(
            $res->header('content-type'),
            'application/rss+xml; charset=UTF-8',
            'Content-type is application/rss+xml'
        );

        my $tx = valid_xml( $res, $test );
        $extra->( $res, $tx ) if $extra;
    };
}

test_psgi app, sub {
    my $cb = shift;

    get_feed_ok(
        $cb,
        '/feed/recent',
        sub {
            my ( $res, $tx ) = @_;
            test_cache_headers(
                $res,
                {
                    cache_control     => 'max-age=60',
                    surrogate_key     => 'RECENT',
                    surrogate_control => 'max-age=60',
                }
            );
        }

    );
    get_feed_ok(
        $cb,
        '/feed/author/PERLER',
        sub {
            my ( $res, $tx ) = @_;
            $tx->ok(
                q!grep(//rdf:item/rdf:description, "PERLER \+\+ed (\S+) from ([A-Z]+)")!,
                'found favorites in author feed',
            );
            $tx->ok(
                q!grep(//rdf:item/rdf:title, "PERLER has released (.+)")!,
                'found releases in author feed',
            );
            test_cache_headers(
                $res,
                {
                    #  cache_control     => 'max-age=3600',
                    surrogate_key => 'PERLER',

                    #  surrogate_control => 'max-age=31536000',
                }
            );
        }
    );
    get_feed_ok(
        $cb,
        '/feed/distribution/Moose',
        sub {
            my ( $res, $tx ) = @_;
            test_cache_headers(
                $res,
                {
                    #  cache_control     => 'max-age=3600',
                    surrogate_key => 'MOOSE',

                    #  surrogate_control => 'max-age=31536000',
                }
            );
        }
    );
    get_feed_ok(
        $cb,
        '/feed/news',
        sub {
            my ( $res, $tx ) = @_;
            test_cache_headers(
                $res,
                {
                    cache_control     => 'max-age=3600',
                    surrogate_key     => 'NEWS',
                    surrogate_control => 'max-age=3600',
                }
            );
        }
    );

    test_redirect( $cb, 'oalders' );
};

sub test_redirect {
    my ( $cb, $author ) = @_;
    ok( my $redir = $cb->( GET "/feed/author/\L$author" ), 'lc author feed' );
    is( $redir->code, 301, 'permanent redirect' );

    # Ignore scheme and host, just check that uri path is what we expect.
    like(
        $redir->header('location'),
        qr{^(\w+://[^/]+)?/feed/author/\U$author},
        'redirect to uc feed'
    );

    test_cache_headers(
        $redir,
        {
            cache_control     => 'max-age=604800',
            surrogate_key     => 'REDIRECT_FEED',
            surrogate_control => 'max-age=31536000',
        }
    );

}

sub valid_xml {
    my ($res) = @_;
    my ( $tx, $err );

    try { $tx = tx( $res, { feed => 1 } ) } catch { $err = $_[0] };

    ok( $tx, 'valid xml' );
    is( $err, undef, 'no errors' )
        or diag Test::More::explain $res;

    return $tx;
}

my $feed = MetaCPAN::Web::Controller::Feed->new( MetaCPAN::Web->new );

subtest 'get correct author favorite data format' => sub {
    my $favorite_data = [
        {
            author       => 'DOLMEN',
            date         => '2013-07-05T14:41:26.000Z',
            distribution => 'Git-Sub',
        }
    ];

    my $entry
        = $feed->_format_favorite_entries( 'PERLHACKER', $favorite_data );
    is(
        $entry->[0]->{abstract},
        'PERLHACKER ++ed Git-Sub from DOLMEN',
        'get correct release abstract'
    );
    is(
        $entry->[0]->{link},
        'https://metacpan.org/release/Git-Sub',
        'get correct release link'
    );
    is(
        $entry->[0]->{name},
        'PERLHACKER ++ed Git-Sub',
        'get correct release title'
    );
    is( $entry->[0]->{author}, 'PERLHACKER', 'get correct author name' );
};

subtest 'get correct author release data format' => sub {
    my $data = [
        {
            abstract     => 'Easy OO access to the FreshBooks.com API',
            author       => 'OALDERS',
            date         => '2014-05-03T03:06:44.000Z',
            distribution => 'Net-FreshBooks-API',
            name         => 'Net-FreshBooks-API-0.24',
            status       => 'latest',
        }
    ];

    my $entry = $feed->_format_release_entries($data);
    is(
        $entry->[0]->{abstract},
        'Easy OO access to the FreshBooks.com API',
        'get correct release abstract'
    );
    is(
        $entry->[0]->{link},
        'https://metacpan.org/release/OALDERS/Net-FreshBooks-API-0.24',
        'get correct release link'
    );
    is(
        $entry->[0]->{name},
        'OALDERS has released Net-FreshBooks-API-0.24',
        'get correct release title'
    );
    is( $entry->[0]->{author}, 'OALDERS', 'get correct author name' );
};

done_testing;
