## To test

Either add visibility of 034s  and 034t in framework manually or issue the following commands in the database

update marc_subfield_structure set hidden = 0 where tagfield = '034' and tagsubfield = 's' and frameworkcode = 'BKS';
update marc_subfield_structure set hidden = 0 where tagfield = '034' and tagsubfield = 't' and frameworkcode = 'BKS';

and then restart_all (or just memcached)

insert some test data

perl insert_geo_data.pl

