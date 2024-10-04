package Koha::Plugin::HKS3::GeoSearch;

use Modern::Perl;

use base qw(Koha::Plugins::Base);
use Koha::Plugins::Tab;
use C4::Biblio;
use Koha::Biblios;
use Koha::Items;
use Cwd qw(abs_path);
use C4::Auth qw(in_iprange);
use C4::Context;
use C4::Koha;
use Koha::AuthorisedValues;

use Mojo::JSON qw(decode_json encode_json);

our $VERSION = "0.9";

our $metadata = {
    name            => 'GeoSearch Plugin',
    author          => 'Mark Hofstetter',
    date_authored   => '2022-09-24',
    date_updated    => "2024-10-04",
    minimum_version => '22.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'display Search Results on a Map'
};

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    $self->{cgi} = CGI->new();

    return $self;
}

sub configure {
    my ( $self ) = @_;
    my $cgi = CGI->new;

    if ($cgi->param('submit') eq 'Save') {
        my $radius = $cgi->param('defaultSearchRadius');
        if ($radius =~ /km$/) {
            $radius *= 1000;
        } else {
            $radius += 0; # numify
        }

        my $mapConfig;
        if ($cgi->param('useMapConfig')) {
            $mapConfig->{url} = $cgi->param('mapConfigUrl');
            $mapConfig->{tileLayerOpts} = decode_json($cgi->param('mapConfigLeafletOpts'));
            $mapConfig->{maxInitialResultsZoom} = $cgi->param('mapConfigMaxInitialResultsZoom');
        }

        $self->store_data({
            username            => $cgi->param('username'),
            defaultPosition_lat => $cgi->param('defaultPosition_lat'),
            defaultPosition_lon => $cgi->param('defaultPosition_lon'),
            defaultSearchRadius => $radius,
            useGeolocation      => $cgi->param('useGeolocation') // 0,
            mapConfig           => ($mapConfig && encode_json($mapConfig)),
            languageCode        => $cgi->param('languageCode'),
        });
        $self->go_home;
    } else {
        my $template = $self->get_template({ file => 'configure.tt' });
        my $mapConfigJson = $self->retrieve_data('mapConfig');
        my %params;
        if ($mapConfigJson) {
            my $mapConfig = decode_json($mapConfigJson);
            $params{useMapConfig} = 1;
            $params{mapConfigUrl} = $mapConfig->{url};
            $params{mapConfigLeafletOpts} = encode_json($mapConfig->{tileLayerOpts});
            $params{mapConfigMaxInitialResultsZoom} = $mapConfig->{maxInitialResultsZoom};
        }
        $template->param(
            leaflet_inc         => $self->mbf_read('leaflet.inc'),
            username            => $self->retrieve_data('username'),
            defaultPosition_lat => $self->retrieve_data('defaultPosition_lat'),
            defaultPosition_lon => $self->retrieve_data('defaultPosition_lon'),
            defaultSearchRadius => $self->retrieve_data('defaultSearchRadius'),
            useGeolocation      => $self->retrieve_data('useGeolocation'),
            languageCode        => $self->retrieve_data('languageCode'),
            %params,
        );
        $self->output_html($template->output);
    }
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ( $self ) = @_;

    return 'geo_search';
}

sub opac_head {
    my ( $self ) = @_;

    my $components = '<script>' . $self->mbf_read('components.js') . '</script>';
    return $components . $self->mbf_read('leaflet.inc');
}


sub opac_js {
    my ( $self ) = @_;

    my $template = $self->get_template({ file => 'opac_js.tt' });
    $template->param(
        useGeolocation => $self->retrieve_data('useGeolocation') ? 1 : 0,
        defaultPosition => [
            $self->retrieve_data('defaultPosition_lat') || 48,
            $self->retrieve_data('defaultPosition_lon') || 13,
        ],
        defaultSearchRadius => $self->retrieve_data('defaultSearchRadius') || 30_000,
        mapConfig => $self->retrieve_data('mapConfig'),
        languageCode => $self->retrieve_data('languageCode'),
    );

    return '<script>' . $template->output . '</script>';
}

1;
