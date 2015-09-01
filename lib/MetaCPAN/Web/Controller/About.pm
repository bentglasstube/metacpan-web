package MetaCPAN::Web::Controller::About;

use Moose;
use Format::Human::Bytes;

BEGIN { extends 'MetaCPAN::Web::Controller' }

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->add_surrogate_key('about');
    $c->browser_max_age( $c->cdn_times->{one_day} );
    $c->cdn_cache_ttl( $c->cdn_times->{one_year} );

}

sub about : Local : Path('/about') {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about.html' );
}

sub contributors : Local {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about/contributors.html' );
}

sub resources : Local {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about/resources.html' );
}

sub sponsors : Local {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about/sponsors.html' );
}

sub development : Local {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about/development.html' );
}

sub missing_modules : Local {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about/missing_modules.html' );
}

sub faq : Local {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about/faq.html' );
}

sub metadata : Local {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about/metadata.html' );
}

sub stats : Local {
    my ( $self, $c ) = @_;

    $c->add_surrogate_key('stats');

    # Only want a day for this, so they get refreshed
    $c->cdn_cache_ttl( $c->cdn_times->{one_day} );

    $c->stash( template => 'about/stats.html' );

    # See if user has the fastly credentials
    if ( my $fastly = $c->_net_fastly() ) {

        my @interested_fields = qw(hit_ratio bandwidth requests);

        my $fastly_services = $c->config->{fastly}->{service};

        my %all_stats;
        foreach my $service ( @{$fastly_services} ) {

            next unless $service->{display_on_stats_page};

            my $stats_from_fastly = $fastly->stats(
                service => $service->{id},
                by      => 'day',
            );

            my %site_stats;

            # build [ { time => $time, y => $value }, {} ]
            map {
                my $data = $_;
                my $time = $data->{start_time};
                map {
                    push @{ $site_stats{$_} },
                        { time => $time, y => $data->{$_} };
                    $site_stats{totals}->{$_} += $data->{$_};
                } @interested_fields;

            } @{$stats_from_fastly};

            $site_stats{totals}->{bandwidth} = Format::Human::Bytes->base10(
                $site_stats{totals}->{bandwidth} );

            $all_stats{ $service->{name} } = \%site_stats;
        }

        $c->stash->{fastly_stats} = \%all_stats;

    }

}

__PACKAGE__->meta->make_immutable;

1;
