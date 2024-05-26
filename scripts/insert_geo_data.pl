use Modern::Perl;

use CGI qw ( -utf8 );
use HTML::Entities;
use Try::Tiny;
use C4::Context;
use C4::Koha;
use C4::Serials;    #uses getsubscriptionfrom biblionumber
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Search;        # enabled_staff_search_views
use C4::Tags qw(get_tags);
use C4::XSLT;
use Koha::DateUtils;
use Koha::Biblios;
use Koha::Biblio;
use Koha::Items;
use Koha::ItemTypes;
use Koha::Patrons;
use Koha::Plugins;
use Data::Dumper;
use Text::CSV;
use Getopt::Long;
use Path::Tiny;

my $testdata = [
    [255, 47.9, 15.9],
    [5,   48, 16],
    [11,  48.1, 16.1],
];

for my $p (@$testdata) {
   biblio_add_geo_point(@$p);
}

sub biblio_add_geo_point {
   my ($biblionumber, $lat, $long) = @_;
   my $biblio = Koha::Biblios->find($biblionumber);
   my $framework = $biblio->frameworkcode;
   my $record = $biblio->metadata->record;
   my @fields;
   $fields[0] = MARC::Field->new('034','','','s' => $lat, 't' => $long);
   $record->append_fields(@fields);
   C4::Biblio::ModBiblio($record, $biblionumber, $framework);
}

# http://kohadev.mydnsname.org:8080/cgi-bin/koha/opac-search.pl?advsearch=1&idx=geolocation&q=lat:48+lng:16+distance:100km&do=Search
