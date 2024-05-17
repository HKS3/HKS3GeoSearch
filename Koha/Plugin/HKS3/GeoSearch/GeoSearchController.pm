package Koha::Plugin::HKS3::GeoSearch::GeoSearchController;
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use C4::Biblio;
use MARC::File::XML ( DefaultEncoding => 'utf8' );

sub get {
    my $c = shift->openapi->valid_input or return;
    my $biblionumbers = $c->validation->every_param('bn');
    my @data;

    for my $biblio_number (@$biblionumbers) {
        my $marcxml = C4::Biblio::GetXmlBiblio( $biblio_number );
        my $record  = MARC::Record->new_from_xml( $marcxml, 'UTF-8', 'MARC21' );
        if ( $record->field('034') ) { 
            push @data, {
                bn => $biblio_number,
                coordinates => [ $record->field('034')->subfield("s"), $record->field('034')->subfield("t") ],
                title => sprintf(
                    "<a href='/cgi-bin/koha/opac-detail.pl?biblionumber=%d'>%s</a>",
                    $biblio_number, $record->field('245')->subfield("a")
                ),
            };
        } 
    }

    return $c->render( status => 200, openapi => { data => \@data, count => scalar(@data) });
}

1;
