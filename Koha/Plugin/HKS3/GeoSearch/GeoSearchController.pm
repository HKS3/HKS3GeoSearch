package Koha::Plugin::HKS3::GeoSearch::GeoSearchController;
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use JSON;

use Koha::Plugin::HKS3::GeoSearch;

use C4::AuthoritiesMarc;
use C4::Biblio;
use MARC::File::XML ( DefaultEncoding => 'utf8' );
use Koha::Caches;
use Koha::Plugins::Datas;

sub cache {
    return Koha::Caches->get_instance(__PACKAGE__);
}

sub decimalize {
    my $coord = shift;

    if ($coord =~ /^[NEWS]/) {
        my ($hemi, $hours, $minutes, $seconds) = $coord =~ /^([NEWS])\s*(\d{,3})\s*(\d{,2})\s*(\d{,2})$/;
        if ($hours) {
            my $decimal = $hours + $minutes/60 + $seconds/3600;
            if ($hemi =~ /[SW]/) {
                $decimal *= -1;
            }
            return $decimal;
        } elsif ($coord =~ /^([NEWS])(\d+\.\d+)$/) {
            # Already in mostly-decimal
            my $decimal = $2;
            if ($1 =~ /[SW]/) {
                $decimal *= -1;
            }
            return $decimal;
        } else {
            warn "Unrecognized coordinate format: '$coord'";
            return;
        }
    }

    return $coord;
}

sub get_record_location {
    my $record = shift;
    my $geofield = $record->field('034');

    if ($geofield) {
        my $lat = decimalize($geofield->subfield('s'));
        my $lng = decimalize($geofield->subfield('t'));
        if ($lat and $lng) {
            return { coordinates => [ $lat, $lng ] };
        }

        my $west  = decimalize($geofield->subfield('d'));
        my $east  = decimalize($geofield->subfield('e'));
        my $north = decimalize($geofield->subfield('f'));
        my $south = decimalize($geofield->subfield('g'));
        if ($west and $east and $north and $south) {
            return {
                bounds => [
                    [ 0+$north, 0+$west ],
                    [ 0+$south, 0+$east ]
                ],
            };
        }
    }
}

sub get_biblionumbers {
    my $c = shift->openapi->valid_input or return;
    my $biblionumbers = $c->validation->every_param('bn');
    my @data;

    for my $biblio_number (@$biblionumbers) {
        my $marcxml = C4::Biblio::GetXmlBiblio( $biblio_number );
        my $record  = MARC::Record->new_from_xml( $marcxml, 'UTF-8', 'MARC21' );
        my $location = get_record_location($record);

        if (!$location) {
            warn "No location found for $biblio_number, checking authority";
            my $authid = $record->subfield('651', '9');
            warn "Authid is $authid";
            if ($authid) {
                my $authrecord = C4::AuthoritiesMarc::GetAuthority( $authid );
                $location = get_record_location($authrecord);
            }
        }

        if ($location) {
            my $title = sprintf(
                "<a href='/cgi-bin/koha/opac-detail.pl?biblionumber=%d'>%s</a>",
                $biblio_number, $record->field('245')->subfield("a")
            );
            push @data, {
                bn => $biblio_number,
                title => $title,
                %$location,
            };
        } 
    }

    return $c->render( status => 200, openapi => { data => \@data, count => scalar(@data) });
}

sub get_geocode {
    my $self = shift;
    my $app = $self->app;

    my $c = $self->openapi->valid_input or return;
    my $query = $c->validation->param('q');
    my $limit = $c->validation->param('limit') // 5;
    my $cache_key = "$query:$limit";

    my $cached = $self->cache->get_from_cache($cache_key);
    if ($cached) {
        warn "Returning cached result for '$cache_key'";
        return $c->render( status => 200, openapi => $cached );
    }

    my $url = URI->new('http://api.geonames.org/searchJSON');
    $url->query_param(q => $query);
    $url->query_param(inclBbox => 'true');

    # ugly, I know. See https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=37431
    $url->query_param(username => Koha::Plugins::Datas->find("Koha::Plugin::HKS3::GeoSearch", 'username')->plugin_value);
    $url->query_param(maxRows => $limit);

    my $ua = LWP::UserAgent->new;
    my $res = $ua->get($url);
    if (!$res->is_success) {
        die "Failed to query GeoNames: " . $res->as_string;
    }

    my $json = $res->decoded_content;
    my $results = decode_json $json;
    my @filtered = map {
        +{
            lat => $_->{lat},
            lng => $_->{lng},
            name => $_->{name},
            countryName => $_->{countryName},
            countryCode => $_->{countryCode},
            bbox => {
                north => $_->{bbox}{north},
                east  => $_->{bbox}{east},
                west  => $_->{bbox}{west},
                south => $_->{bbox}{south},
            },
        }
    } $results->{geonames}->@*;

    my $result = {
        places => \@filtered,
        count => $results->{totalResultsCount},
    };

    $self->cache->set_in_cache($cache_key, $result);
    return $c->render( status => 200, openapi => $result );
}

1;
