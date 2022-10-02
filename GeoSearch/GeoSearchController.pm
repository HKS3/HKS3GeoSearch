package Koha::Plugin::HKS3GeoSearch::GeoSearch::GeoSearchController;

use utf8;
use Mojo::Base 'Mojolicious::Controller';

use C4::Context;
use C4::Biblio;
use C4::XSLT;

use C4::Biblio;
use C4::XSLT;

use Koha::Biblios;
use Koha::Items;
use Mojo::JSON qw(decode_json encode_json);
use Encode qw(encode_utf8);
use MARC::File::XML ( DefaultEncoding => 'utf8' );

sub post {
    my $c = shift->openapi->valid_input or return;
    my $biblionumbers = $c->validation->every_param('biblionumber');

##     my $dbh = C4::Context->dbh;
## 
##     my $sql= <<'SQL';
## with search as (
## select authid, 
##        ExtractValue(marcxml, '//datafield[@tag="035"]/subfield[@code="a"]')  as idn,
##        ExtractValue(marcxml, '//datafield[@tag="150"]/subfield[@code="a"]') as fieldvalue,
##        gnd_id nid
##   from auth_header where authtypecode = 'GENRE/FORM' and origincode = 'rda')
## select * from search where biblionumber in  ?
## order by fieldvalue
## SQL
## 
##     my $query = $dbh->prepare($sql);
##     $query->execute($searchterm);
##     my $items = $query->fetchall_arrayref({});

    return $c->render( status => 200, openapi => {data => $biblionumbers, info => 'test'}  );
}


sub get {
    my $c = shift->openapi->valid_input or return;
    my $biblionumbers = $c->validation->every_param('bn');
    my $data = [];
    my $i = 0;
    for my $b (@$biblionumbers) {
        my $d = {};
        my $marcxml =  C4::Biblio::GetXmlBiblio( $b );
        my $record  = MARC::Record->new_from_xml( $marcxml, 'UTF-8', 'MARC21' );
        $d->{coordinates} = [$record->field('034')->subfield("s"), $record->field('034')->subfield("t")];
        $d->{title}       = sprintf("<a href='/cgi-bin/koha/opac-detail.pl?biblionumber=%d'>%s</a>",
                            $b, $record->field('245')->subfield("a"));
        push @$data, $d;
        $i++;
    }
    return $c->render( status => 200, openapi => {data => $data,  count => $i}  );
}

1;

