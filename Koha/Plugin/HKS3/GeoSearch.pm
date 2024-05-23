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

use Mojo::JSON qw(decode_json);;

our $VERSION = "0.2";

our $metadata = {
    name            => 'GeoSearch Plugin',
    author          => 'Mark Hofstetter',
    date_authored   => '2022-09-24',
    date_updated    => "2022-09-24",
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

    return q|
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.1/dist/leaflet.css"
   integrity="sha256-sA+zWATbFveLLNqWO2gtiw3HL/lh1giY/Inf1BJ0z14="
   crossorigin=""/>
<script src="https://unpkg.com/leaflet@1.9.1/dist/leaflet.js"
   integrity="sha256-NDI0K41gVbWqfkkaHj15IzU7PtMoelkzyKp8TOaFQ3s="
   crossorigin=""></script>
<style>
#geo_search_map { height: 400px; }
</style>
|;
}


sub opac_js {
    my ( $self ) = @_;

    my $payload = $self->mbf_read('opac.js');

    return "<script> $payload </script>";
}

1;
