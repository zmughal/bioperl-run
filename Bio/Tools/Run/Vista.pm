# Cared for by Shawn Hoon
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tools::Run::Vista

Wrapper for Vista

=head1 SYNOPSIS

  use Bio::Tools::Run::Vista;
  use Bio::Tools::Run::Alignment::Lagan;
  use Bio::AlignIO;

  my $sio = Bio::SeqIO->new(-file=>$ARGV[0],-format=>'fasta');
  my @seq;
  my $reference = $sio->next_seq;
  push @seq, $reference;
  while(my $seq = $sio->next_seq){
    push @seq,$seq;
  }
  my @features = grep{$_->primary_tag eq 'CDS'} $reference->get_SeqFeatures;

  my $lagan = Bio::Tools::Run::Alignment::Lagan->new;

  my $aln = $lagan->mlagan(\@seq,'(fugu (mouse human))');


  my $vis = Bio::Tools::Run::Vista->new('outfile'=>$out,
                                        'title' => "My Vista Plot",
                                        'annotation'=>\@features,
                                        'annotation_format'=>'GFF',
                                        'min_perc_id'=>75,
                                        'min_length'=>100,
                                        'plotmin'   => 50,
                                        'tickdist' => 2000,
                                        'window'=>40,
                                        'numwindows'=>4,
                                        'start'=>50,
                                        'end'=>1500,
                                        'tickdist'=>100,
                                        'bases'=>1000,
                                        'color'=> {'EXON'=>'100 0 0',
                                                   'CNS'=>'0 0 100'},
                                        'quiet'=>1);

  my $referenceid= 'human';
  $vis->run($aln,$referenceid); 

=head1 DESCRIPTION

Pls see Vista documentation for plotfile options

Wrapper for Vista :

C. Mayor, M. Brudno, J. R. Schwartz, A. Poliakov, E. M. Rubin, K. A.  Frazer, 
L. S. Pachter, I. Dubchak. 
VISTA: Visualizing global DNA  sequence alignments of arbitrary length.
Bioinformatics, 2000  Nov;16(11):1046-1047.
Get it here:
http://www-gsd.lbl.gov/vista/VISTAdownload2.html

On the command line, it is assumed that this can be executed:

java Vista plotfile

Some of the code was adapted from MLAGAN toolkit

M. Brudno,  C.B. Do,  G. Cooper,  M.F. Kim,  E. Davydov,  NISC Sequencing Consortium, 
E.D. Green,  A. Sidow and S. Batzoglou 
LAGAN and Multi-LAGAN: Efficient Tools for Large-Scale Multiple  Alignment of Genomic 
DNA, Genome Research, in press

get lagan here:

http://lagan.stanford.edu/

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org               - General discussion
  http://bio.perl.org/MailList.html   - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR

Shawn Hoon
Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

package Bio::Tools::Run::Vista;

use vars qw($AUTOLOAD @ISA %DEFAULT_VALUES %EPONINE_PARAMS
       	   @VISTA_PARAMS  $EPOJAR $JAVA $PROGRAMDIR $PROGRAMNAME $PROGRAM
            %OK_FIELD);
use strict;

use Bio::Root::Root;
use Bio::Root::IO;
use Bio::Tools::Run::WrapperBase;
use File::Copy;
@ISA = qw(Bio::Root::Root Bio::Tools::Run::WrapperBase);

BEGIN {
    $PROGRAMNAME = 'java';

    if( ! defined $PROGRAMDIR ) {
    	$PROGRAMDIR = $ENV{'JAVA_HOME'} || $ENV{'JAVA_DIR'};
    }
    if (defined $PROGRAMDIR) {
    	foreach my $progname ( [qw(java)],[qw(bin java)] ) {
  	    my $f = Bio::Root::IO->catfile($PROGRAMDIR, @$progname);
  	    if( -e $f && -x $f ) {
      		$PROGRAM = $f;
      		last;
  	    }
    	}
    }

    %DEFAULT_VALUES= ('java'     => 'java',
                      'min_perc_id'   => 75,
                      'min_length'   => 100,
                      'plotmin'      => 50,
                      'bases'    => 10000,
                      'tickdist' => 2000,
                      'resolution'=> 25,
                      'window'  => 40,
                      'title'   => 'VISTA PLOT',
                      'numwindows'=>4);

    @VISTA_PARAMS=qw(JAVA OUTFILE MIN_PERC_ID QUIET VERBOSE ANNOTATION_FORMAT
                     REGION_FILE SCORE_FILE ALIGNMENT_FILE CONTIGS_FILE DIFFS PLOTFILE
                     MIN_LENGTH PLOTMIN ANNOTATION BASES TICKDIST RESOLUTION TITLE
                     WINDOW NUMWINDOWS START END NUM_PLOT_LINES LEGEND FILENAME 
                     AXIS_LABEL TICKS_FILE COLOR USE_ORDER GAPS SNPS_FILE REPEATS_FILE 
                     FILTER_REPEATS);

    foreach my $attr ( @VISTA_PARAMS)
    { $OK_FIELD{$attr}++; }
}

sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    $self->debug( "************ attr:  $attr\n");
    $attr =~ s/.*:://;
    $attr = uc $attr;
    $self->throw("Unallowed parameter: $attr !") unless $OK_FIELD{$attr};
    $self->{$attr} = shift if @_;
    return $self->{$attr};
}

=head2 new

    Title   :   new
    Usage   :   my $vis = Bio::Tools::Run::Vista->new('outfile'=>$out,
                                      'title' => "My Vista Plot",
                                        'annotation'=>$gff_file,
                                        'annotation_format'=>'GFF',
                                        'regmin'=>75,
                                        'regmax'=>100,
                                        'min'   => 50,
                                        'tickdist' => 2000,
                                        'window'=>40,
                                        'numwindows'=>4,
                                        'quiet'=>1);
    Function:   Construtor for Vista wrapper
    Args    :   outfile - location of the pdf generated
                annotation - either a file or and array ref of Bio::SeqFeatureI
                             indicating the exons 
                regmin     -region min

=cut

sub new {
    my ($caller, @args) = @_;
    # chained new
    my $self = $caller->SUPER::new(@args);
    # so that tempfiles are cleaned up
    foreach my $key(keys %DEFAULT_VALUES){
      $self->$key($DEFAULT_VALUES{$key});
    }
    while (@args)  {
       my $attr =   shift @args;
       my $value =  shift @args;
       next if( $attr =~ /^-/ ); # don't want named parameters
	    $self->$attr($value);
    }

    return $self;
}

=head2 java

    Title   :   java
    Usage   :   $obj->java('/usr/opt/java130/bin/java');
    Function:   Get/set method for the location of java VM
    Args    :   File path (optional)

=cut

sub executable { shift->java(@_); }

sub java {
   my ($self, $exe,$warn) = @_;

   if( defined $exe ) {
     $self->{'_pathtojava'} = $exe;
   }

   unless( defined $self->{'_pathtojava'} ) {
       if( $PROGRAM && -e $PROGRAM && -x $PROGRAM ) {
	   $self->{'_pathtojava'} = $PROGRAM;
       } else {
	   my $exe;
	   if( ( $exe = $self->io->exists_exe($PROGRAMNAME) ) &&
	       -x $exe ) {
	       $self->{'_pathtojava'} = $exe;
	   } else {
	       $self->warn("Cannot find executable for $PROGRAMNAME") if $warn;
	       $self->{'_pathtojava'} = undef;
	   }
       }
   }
   $self->{'_pathtojava'};
}


=head2 run

 Title   : run
 Usage   : my @genes = $self->run($seq)
 Function: runs Vista and creates an array of features
 Returns : An Array of SeqFeatures
 Args    : A Bio::PrimarySeqI

=cut

sub run{
    my ($self,$seq,$ref) = @_;
    $ref ||=1;
    my $infile = $self->_setinput($seq,$ref);
    my @tss = $self->_run_Vista($infile);
    return @tss;

}

=head2 _setinput

 Title   : _setinput
 Usage   : Internal function, not to be called directly
 Function: writes input sequence to file and return the file name
 Example :
 Returns : string
 Args    :

=cut

sub _setinput {
    my ($self,$sim_aln,$ref) = @_;
    #better be a file
    $sim_aln->isa("Bio::Align::AlignI") || $self->throw("Expecting a Bio::Align::AlignI");
    my($pairs,$files) = $self->_mf2bin($sim_aln,$ref);
    my $plotfile = $self->_make_plotfile($sim_aln,$pairs,$files);
    return $plotfile;
}

#adapted from mlagan utils  mf2bin.pl 
sub _mf2bin {
  my ($self,$sim,$ref)= @_;
  my @seq = $sim->each_seq;
  my $reference;

  #figure out the reference sequence
  if($ref =~/\d+/){ #its a rank index
    $reference = $seq[$ref-1];
    splice @seq,($ref-1),1;
  }
  else { #its an id
    foreach my $i(0..$#seq){
      if($seq[$i]->id =~/$ref/){
        $reference  = $seq[$i];
        splice @seq,($i),1;
        last;
      }
    }
  }

  # pack bin
  # format from Alex Poliakov's glass2bin.pl script
  my %base_code = ('-' => 0, 'A' => 1, 'C' => 2, 'T' => 3, 'G' => 4, 'N' => 5,
                'a' => 1, 'c' => 2, 't' => 3, 'g' => 4, 'n' => 5);

  my @files;

  my @ref= (split ('',$reference->seq));
  my @pairs;
  foreach my $seq2(@seq){
      my ($tfh1,$outfile) = $self->io->tempfile(-dir=>$self->tempdir);
      my @seq2= (split('', $seq2->seq)); 
      foreach my $index(0..$#ref){
        print $tfh1 pack("H2",$base_code{$ref[$index]}.$base_code{$seq2[$index]});
      }
      close ($tfh1);
      undef ($tfh1);
      push @files, $outfile;
      push @pairs,[$reference->id,$seq2->id];
  }
  return \@pairs,\@files;
}

sub _make_plotfile {
  my ($self,$sim_aln,$pairs,$files) = @_;
  my ($tfh1,$plotfile) = $self->io->tempfile(-dir=>$self->tempdir);
  my @ids = map{$_->id}$sim_aln->each_seq;
  
  print $tfh1 "TITLE ".$self->title."\n\n";
  print $tfh1 "OUTPUT ".$self->outfile."\n\n" ;
  print $tfh1 "SEQUENCES ";
  print $tfh1 join(" ",@ids)."\n\n";

  foreach my $index(0..$#$pairs){
    print $tfh1 "ALIGN ".$files->[$index]." BINARY\n";
    print $tfh1 " SEQUENCES ".$pairs->[$index]->[0]." ".$pairs->[$index]->[1]."\n";
    print $tfh1 " REGIONS ".$self->min_perc_id." ".$self->min_length."\n";
    print $tfh1 " MIN ".$self->plotmin."\n";
    print $tfh1 " DIFFS ". $self->diffs ."\n\n" if $self->diffs;
    print $tfh1 " REGION_FILE ". $self->region_file ."/".$pairs->[$index]->[0]."_".$pairs->[$index]->[1].".aln\n\n" if $self->region_file;
    print $tfh1 " SCORE_FILE ". $self->score_file ."/".$pairs->[$index]->[0]."_".$pairs->[$index]->[1].".score\n\n" if $self->score_file;
    print $tfh1 " ALIGNMENT_FILE ". $self->alignment_file ."/".$pairs->[$index]->[0]."_".$pairs->[$index]->[1].".alignment\n\n" if $self->alignment_file;
    print $tfh1 " CONTIGS_FILE ". $self->contigs_file ."\n\n" if $self->contigs_file;
    print $tfh1 " USE_ORDER ". $self->use_order."\n\n" if $self->use_order;
    print $tfh1 "END \n\n";
  }
  my $annotation_file;
  if((ref $self->annotation eq 'ARRAY')&& $self->annotation->[0]->isa("Bio::SeqFeatureI")){
    $annotation_file = $self->_dump2gff($self->annotation);
    $self->annotation_format('GFF');
  }
  elsif($self->annotation){
    $annotation_file = $self->annotation;
  }
  $annotation_file .= " GFF" if $self->annotation_format=~/GFF/i;
  print $tfh1 "GENES ".$annotation_file." \n\n" if $annotation_file;
  print $tfh1 "LEGEND on\n\n";
  print $tfh1 "COORDINATE ".$pairs->[0]->[0]."\n\n";
  print $tfh1 "PAPER letter\n\n";
  print $tfh1 "BASES ".$self->bases."\n\n";
  print $tfh1 "TICK_DIST ".$self->tickdist."\n\n";
  print $tfh1 "RESOLUTION ".$self->resolution."\n\n";
  print $tfh1 "WINDOW ".$self->window."\n\n";
  print $tfh1 "NUM_WINDOWS ".$self->numwindows."\n\n";
  print $tfh1 "AXIS_LABEL ".$self->axis_label ."\n\n" if $self->axis_label;
  print $tfh1 "TICKS_FILE ".$self->ticks_file ."\n\n" if $self->ticks_file;
  print $tfh1 "GAPS ".$self->gaps ."\n\n"if $self->gaps;
  print $tfh1 "REPEATS_FILE ".$self->repeats_file ."\n\n" if $self->repeats_file;
  print $tfh1 "FILTER_REPEATS".$self->filter_repeats ."\n\n" if $self->filter_repeats;
  print $tfh1 "START ".$self->start ."\n\n" if $self->start;
  print $tfh1 "END ".$self->end ."\n\n" if $self->end;
  my $color = $self->color;
  if(ref $color eq 'HASH'){
    foreach my $region_type (keys %$color){
      print $tfh1 "COLOR ".$region_type." ".$color->{$region_type}."\n\n";
    }
  }

  close ($tfh1);
  undef $tfh1;
  if($self->plotfile) {#saving plotfile
    copy($plotfile,$self->plotfile);
  } 
  return $plotfile;
}     

sub _dump2gff {
  my ($self,$feat) = @_;
  my ($tfh1,$file) = $self->io->tempfile(-dir=>$self->tempdir);
  my @CDS = grep {$_->primary_tag eq 'CDS'}@$feat;
  foreach my $cds(@CDS){
    print $tfh1 $cds->gff_string."\n";
  }
  close ($tfh1);
  undef $tfh1;
  return $file;
}

sub _run_Vista {
    my ($self,$infile) = @_;

    #run Vista
    $self->debug( "Running Vista\n");
    my $java = $self->java;
    
    my $cmd  =   $self->java.' Vista ';
    $cmd .= " -q " if $self->quiet || $self->verbose < 0;
    $cmd .= " -d " if $self->debug;
    $cmd .= $infile;
	 my $status = system ($cmd);

   $self->throw("Problem running Vista: $? \n") if $status != 0;
   
   return 1;

}

=head2 outfile

  Title    : outfile
  Usage    : $obj->outfile
  Function : Get/Set method outfile
  Args     : 

=cut

=head2 min_perc_id

  Title    : min_perc_id
  Usage    : $obj->min_perc_id
  Function : Get/Set method min_perc_id
  Args     : 

=cut

=head2 quiet

  Title    : quiet
  Usage    : $obj->quiet
  Function : Get/Set method quiet
  Args     : 

=cut

=head2 verbose

  Title    : verbose
  Usage    : $obj->verbose
  Function : Get/Set method verbose
  Args     : 

=cut

=head2 annotation_format

  Title    : annotation_format
  Usage    : $obj->annotation_format
  Function : Get/Set method annotation_format
  Args     : 

=cut

=head2 region_file

  Title    : region_file
  Usage    : $obj->region_file
  Function : Get/Set method region_file
  Args     : 

=cut

=head2 score_file

  Title    : score_file
  Usage    : $obj->score_file
  Function : Get/Set method score_file
  Args     : 

=cut

=head2 alignment_file

  Title    : alignment_file
  Usage    : $obj->alignment_file
  Function : Get/Set method alignment_file
  Args     : 

=cut

=head2 contigs_file

  Title    : contigs_file
  Usage    : $obj->contigs_file
  Function : Get/Set method contigs_file
  Args     : 

=cut
=head2 diffs

  Title    : diffs
  Usage    : $obj->diffs
  Function : Get/Set method diffs
  Args     : 

=cut

=head2 plotfile

  Title    : plotfile
  Usage    : $obj->plotfile
  Function : Get/Set method plotfile
  Args     : 

=cut

=head2 min_length

  Title    : min_length
  Usage    : $obj->min_length
  Function : Get/Set method min_length
  Args     : 

=cut

=head2 plotmin

  Title    : plotmin
  Usage    : $obj->plotmin
  Function : Get/Set method plotmin
  Args     : 

=cut

=head2 annotation

  Title    : annotation
  Usage    : $obj->annotation
  Function : Get/Set method annotation
  Args     : 

=cut


=head2 bases

  Title    : bases
  Usage    : $obj->bases
  Function : Get/Set method bases
  Args     : 

=cut

=head2 tickdist

  Title    : tickdist
  Usage    : $obj->tickdist
  Function : Get/Set method tickdist
  Args     : 

=cut

=head2 resolution

  Title    : resolution
  Usage    : $obj->resolution
  Function : Get/Set method resolution
  Args     : 

=cut

=head2 title

  Title    : title
  Usage    : $obj->title
  Function : Get/Set method title
  Args     : 

=cut

=head2 window

  Title    : window
  Usage    : $obj->window
  Function : Get/Set method window
  Args     : 

=cut
=head2 numwindows

  Title    : numwindows
  Usage    : $obj->numwindows
  Function : Get/Set method numwindows
  Args     : 

=cut

=head2 start

  Title    : start
  Usage    : $obj->start
  Function : Get/Set method start
  Args     : 

=cut

=head2 end

  Title    : end
  Usage    : $obj->end
  Function : Get/Set method end
  Args     : 

=cut

=head2 num_plot_lines

  Title    : num_plot_lines
  Usage    : $obj->num_plot_lines
  Function : Get/Set method num_plot_lines
  Args     : 

=cut

=head2 legend

  Title    : legend
  Usage    : $obj->legend
  Function : Get/Set method legend
  Args     : 

=cut

=head2 filename

  Title    : filename
  Usage    : $obj->filename
  Function : Get/Set method filename
  Args     : 

=cut

=head2 axis_label

  Title    : axis_label
  Usage    : $obj->axis_label
  Function : Get/Set method axis_label
  Args     : 

=cut

=head2 ticks_file

  Title    : ticks_file
  Usage    : $obj->ticks_file
  Function : Get/Set method ticks_file
  Args     : 

=cut

=head2 color

  Title    : color
  Usage    : $obj->color
  Function : Get/Set method color
  Args     : 

=cut

=head2 use_order

  Title    : use_order
  Usage    : $obj->use_order
  Function : Get/Set method use_order
  Args     : 

=cut

=head2 gaps

  Title    : gaps
  Usage    : $obj->gaps
  Function : Get/Set method gaps
  Args     : 

=cut

=head2 snps_file

  Title    : snps_file
  Usage    : $obj->snps_file
  Function : Get/Set method snps_file
  Args     : 

=cut

=head2 repeats_file

  Title    : repeats_file
  Usage    : $obj->repeats_file
  Function : Get/Set method repeats_file
  Args     : 

=cut

=head2 filter_repeats

  Title    : filter_repeats
  Usage    : $obj->filter_repeats
  Function : Get/Set method filter_repeats
  Args     : 

=cut
1;
__END__

