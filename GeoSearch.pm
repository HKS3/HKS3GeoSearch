package Koha::Plugin::HKS3GeoSearch::GeoSearch;

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

#  sub static_routes {
#      my ( $self, $args ) = @_;
#  
#      my $spec_str = $self->mbf_read('staticapi.json');
#      my $spec     = decode_json($spec_str);
#  
#      return $spec;
#  }


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

    my $js = <<'JS';
    <script>
    var page = $('body').attr('ID');
    console.log('geo search', page);
    if (page == 'results') {
    $( document ).ready(function() {
      console.log('on search page ', page);
      $(".main").prepend('<div id="geo_search_map"></div>');
      var map = L.map('geo_search_map').setView([48, 13], 13);
      var tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
      }).addTo(map);

      var biblionumbers = [];
      $(".addtocart").each(function() {
        console.log($(this).attr("data-biblionumber"));
        biblionumbers.push( $(this).attr("data-biblionumber") );
      });
      console.log(biblionumbers);
      $(function(e) {
        var ajaxData = { 'bn': biblionumbers };
        $.ajax({
            url: '/api/v1/contrib/geo_search/biblionumbers',
            type: 'GET',
            dataType: 'json',
            data: ajaxData,
            traditional: true
            })
        .done(function(data) {
            var bounds = L.latLngBounds()
            console.log(data['data']);
                $.each(data['data'], function( index, value ) {
                    console.log(value['coordinates']);
                    var marker = L.marker(value['coordinates']).addTo(map);
                    marker.bindPopup(index+1 + '. ' + value['title'] );
                    bounds.extend(value['coordinates']);
                });
            map.fitBounds(bounds);
            })
        .error(function(data) {});
        });
    });
    } else if (page == 'advsearch') {
var geosearch =`
<div class="col-sm-6 col-lg-3">
<div id="geosearch" class="advsearch_limit">
                            <fieldset>
                                <label for="limit-yr">Geographic Search</label>
                                <input type="text" size="6" id="lat" name="lat" title="Enter Latitude" value="48.3">
                                <input type="text" size="6" id="lng" name="lng" title="Enter Longitude" value="14.3">
                                <input type="text" size="6" id="rad" name="radius" title="Enter Radius" value="120km">
                                <div class="hint">Search for Lat/long/Radius</div>
                            </fieldset>
                        </div>
</div>
`;

        $("#advsearch_limits").append(geosearch);
    }
    </script>
JS
    
    return $js;
}

sub intranet_js {
    my ( $self ) = @_;
    my $js = <<'JS';
    <script>
    var page = $('body').attr('ID');
    console.log('page: ' + page);
    </script>
JS
    return $js
}

1;
