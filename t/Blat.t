#!/usr/local/bin/perl
#-*-Perl-*-
# ## Bioperl Test Harness Script for Modules
# #
use strict;
BEGIN {
   eval { require Test; };
   if( $@ ) {
      use lib 't';
   }
   use Test;
   use vars qw($NTESTS);
   $NTESTS = 12;
   plan tests => $NTESTS;
}

END {
   foreach ( $Test::ntest..$NTESTS ) {
       skip('Unable to run Blat  tests, exe may not be installed',1);
   }
}
ok(1);
use Bio::Tools::Run::Alignment::Blat;
use Bio::Root::IO;
use Bio::SeqIO;
use Bio::Seq;

my $db =  Bio::Root::IO->catfile("t","data","blat_dna.fa");

my $query = Bio::Root::IO->catfile("t","data","blat_dna.fa");    

my  $factory = Bio::Tools::Run::Alignment::Blat->new("DB"=>$db);
ok $factory->isa('Bio::Tools::Run::Alignment::Blat');

my $blat_present = $factory->executable();

unless ($blat_present) {
       warn("blat  program not found. Skipping tests $Test::ntest to $NTESTS.\n");
       exit 0;
}

my $searchio = $factory->align($query);
my $result = $searchio->next_result;
my $hit    = $result->next_hit;
my $hsp    = $hit->next_hsp;
ok $hsp->isa("Bio::Search::HSP::HSPI");
ok ($hsp->feature1->start,1);
ok ($hsp->feature1->end,1775);
ok ($hsp->feature2->start,1);
ok ($hsp->feature2->end,1775);
my $sio = Bio::SeqIO->new(-file=>$query,-format=>'fasta');

my $seq  = $sio->next_seq ;

$searchio = $factory->align($seq);
$result = $searchio->next_result;
$hit    = $result->next_hit;
$hsp    = $hit->next_hsp;
ok $hsp->isa("Bio::Search::HSP::HSPI");
ok ($hsp->feature1->start,1);
ok ($hsp->feature1->end,1775);
ok ($hsp->feature2->start,1);
ok ($hsp->feature2->end,1775);

 
1; 
