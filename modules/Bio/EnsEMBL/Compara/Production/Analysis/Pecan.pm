=head1 LICENSE

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Analysis::Runnable::Pecan - 

=head1 SYNOPSIS

  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::Pecan
     (-workdir => $workdir,
      -fasta_files => $fasta_files,
      -tree_string => $tree_string,
      -program => "/path/to/program");
  $runnable->run;
  my @output = @{$runnable->output};

=head1 DESCRIPTION

Mavid expects to run the program mavid, a global multiple aligner for large genomic sequences,
using a fasta file and a tree file (Newick format), and eventually a constraints file.
The output (multiple alignment) is parsed and return as a Bio::EnsEMBL::Compara::GenomicAlignBlock object.

=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::Production::Analysis::Pecan;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 new

  Arg [1]   : -workdir => "/path/to/working/directory"
  Arg [2]   : -fasta_files => "/path/to/fasta/file"
  Arg [3]   : -tree_string => "/path/to/tree/file" (optional)
  Arg [4]   : -parameters => "parameter" (optional)

  Function  : contruct a new Bio::EnsEMBL::Analysis::Runnable::Pecan
  runnable
  Returntype: Bio::EnsEMBL::Analysis::Runnable::Pecan
  Exceptions: none
  Example   :

=cut


sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($workdir, $fasta_files, $tree_string, $parameters, $exonerate_exe,
      $pecan_exe_dir, $pecan_java_class,  $estimate_tree_exe, $java_exe) =
        rearrange(['WORKDIR', 'FASTA_FILES', 'TREE_STRING','PARAMETERS', 'EXONERATE_EXE',
            'PECAN_EXE_DIR', 'PECAN_JAVA_CLASS', 'ESTIMATE_TREE_EXE', 'JAVA_EXE'], @args);


  $self->workdir($workdir) if (defined $workdir);      
  chdir $self->workdir;
  unless (defined $estimate_tree_exe) { die 'estimate_tree_exe is not given'; }

  $self->fasta_files($fasta_files) if (defined $fasta_files);
  if (defined $tree_string) {
    $self->tree_string($tree_string)
  } else {
    # Use EstimateTree.py program to get a tree from the sequences
    my $run_str = "python $estimate_tree_exe " . join(" ", @$fasta_files);
    print "RUN $run_str\n";
    my @estimate = qx"$run_str";
    if (($estimate[0] !~ /^FINAL_TREE: \(.+\);/) or ($estimate[2] !~ /^ORDERED_SEQUENCES: (.+)/)) {
      throw "Error while running EstimateTree program for Pecan";
    }
    ($tree_string) = $estimate[0] =~ /^FINAL_TREE: (\(.+\);)/;
    $self->tree_string($tree_string);
    # print "THIS TREE $tree_string\n";
    my ($files) = $estimate[2] =~ /^ORDERED_SEQUENCES: (.+)/;
    @$fasta_files = split(" ", $files);
    $self->fasta_files($fasta_files);
    # print "THESE FILES ", join(" ", @$fasta_files), "\n";
    ## Build newick tree which can be stored in the meta table
    foreach my $this_file (@$fasta_files) {
      my $header = qx"head -1 $this_file";
      my ($dnafrag_id, $name, $start, $end, $strand) = $header =~ /^>DnaFrag(\d+)\|([^\.+])\.(\d+)\-(\d+)\:(\-?1)/;
      # print "HEADER: $dnafrag_id, $name, $start, $end, $strand  $header";
      $strand = 0 if ($strand != 1);
      $tree_string =~ s/(\W)\d+(\W)/$1${dnafrag_id}_${start}_${end}_${strand}$2/;
    }
    $self->{tree_to_save} = $tree_string;
    # print "TREE_TO_SAVE: $tree_string\n";
  }
  $self->parameters($parameters) if (defined $parameters);
  unless (defined $self->program) {
    if (defined $java_exe) {
      $self->program($java_exe);
    } else {
      die  "\n java executable needed \n";
    }
  }
  if (defined $pecan_exe_dir) {
    $self->pecan_exe_dir($pecan_exe_dir);
  } else {
    die "\n pecan exe_dir  needed \n";
  }
  if (defined $pecan_java_class) {
    $self->pecan_java_class($pecan_java_class);
  } else {
    die "\n pecan java_class  needed \n";
#    $self->pecan_java_class($default_java_class);
  }
  if (defined $exonerate_exe) {
    $self->exonerate_exe($exonerate_exe);
  } else {
    die "\n exonerate executable needed \n";
  }

  return $self;
}

sub workdir {
  my $self = shift;
  $self->{'_workdir'} = shift if(@_);
  return $self->{'_workdir'};
}

sub fasta_files {
  my $self = shift;
  $self->{'_fasta_files'} = shift if(@_);
  return $self->{'_fasta_files'};
}

sub tree_string {
  my $self = shift;
  $self->{'_tree_string'} = shift if(@_);
  return $self->{'_tree_string'};
}

sub parameters {
  my $self = shift;
  $self->{'_parameters'} = shift if(@_);
  return $self->{'_parameters'};
}

sub pecan_exe_dir {
  my $self = shift;
  $self->{'_pecan_exe_dir'} = shift if(@_);
  return $self->{'_pecan_exe_dir'};
}

sub pecan_java_class {
  my $self = shift;
  $self->{'_pecan_java_class'} = shift if(@_);
  return $self->{'_pecan_java_class'};
}

sub exonerate_exe {
  my $self = shift;
  $self->{'_exonerate_exe'} = shift if(@_);
  return $self->{'_exonerate_exe'};
}

sub options {
  my $self = shift;
  $self->{'_options'} = shift if(@_);
  return $self->{'_options'};
}

sub program {
  my $self = shift;
  $self->{'_program'} = shift if(@_);
  return $self->{'_program'};
}

sub output {
  my $self = shift;
  $self->{'_output'} = shift if(@_);
  return $self->{'_output'};
}

=head2 run_analysis

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Pecan
  Arg [2]   : string, program name
  Function  : create and open a commandline for the program trf
  Returntype: none
  Exceptions: throws if the program in not executable or if the results
  file doesnt exist
  Example   : 

=cut

sub run_analysis {
  my ($self, $program) = @_;

  $self->run_pecan;

  $self->parse_results;

  return 1;
}

sub run_pecan {
  my $self = shift;

  chdir $self->workdir;

  throw($self->program . " is not executable Pecan::run_analysis ")
    unless ($self->program && -x $self->program);

  my $command = $self->program;
  if ($self->parameters) {
    $command .= " " . $self->parameters;
  }
  $command .= " -cp ".$self->pecan_exe_dir." ".$self->pecan_java_class;
  if (@{$self->fasta_files}) {
    $command .= " -F";
    foreach my $fasta_file (@{$self->fasta_files}) {
      $command .= " $fasta_file";
    }
  }

  #Remove -X option. Transitive anchoring is now switched off by default
  #$command .= " -J '" . $self->exonerate_exe . "' -X";
  $command .= " -J '" . $self->exonerate_exe . "'";
  if ($self->tree_string) {
    $command .= " -E '" . $self->tree_string . "'";
  }
  $command .= " -G pecan.mfa";
  if ($self->options) {
    $command .= " " . $self->options;
  }
  print "Running pecan: " . $command . "\n";

  open(PECAN, "$command 2>&1 |") || die "Failed: $!\n";
  my $java_error = <PECAN>;
  if ($java_error) {
      die ($java_error);
  }
  close PECAN;

#  unless (system($command) == 0) {
#    throw("pecan execution failed\n");
#  }
}

=head2 parse_results

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Pecan
  Function  : parse the specifed file and produce RepeatFeatures
  Returntype: nine
  Exceptions: throws if fails to open or close the results file
  Example   : 

=cut


sub parse_results{
  my ($self, $run_number) = @_;

  my $alignment_file = $self->workdir . "/pecan.mfa";
  my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock;

  open F, $alignment_file || throw("Could not open $alignment_file");
  my $seq = "";
  my $this_genomic_align;
print "Reading $alignment_file...\n";
  while (<F>) {
    next if (/^\s*$/);
    chomp;
    ## FASTA headers are defined in the Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Pecan
    ## module (or any other module you use to create this Pecan analysis job). Here is an example:
    ## >DnaFrag1234|X.10001-20000:-1
    ## This will correspond to chromosome X, which has dnafrag_id 1234 and the region goes from
    ## position 10001 to 20000 on the reverse strand.
    if (/^>/) {
      if (/^>DnaFrag(\d+)\|(.+)\.(\d+)\-(\d+)\:(\-?1)$/) {
        if (defined($this_genomic_align) and  $seq) {
          $this_genomic_align->aligned_sequence($seq);
          $this_genomic_align_block->add_GenomicAlign($this_genomic_align);
        }
        $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;
        $this_genomic_align->dnafrag_id($1);
        $this_genomic_align->dnafrag_start($3);
        $this_genomic_align->dnafrag_end($4);
        $this_genomic_align->dnafrag_strand($5);
        $seq = "";
      } else {
        throw("Error while parsing the FASTA header. It must start by \">DnaFrag#####\" where ##### is the dnafrag_id\n$_");
      }
    } else {
      $seq .= $_;
    }
  }
  close F;
  $this_genomic_align->aligned_sequence($seq);
  $this_genomic_align_block->add_GenomicAlign($this_genomic_align);
  
  $self->output([$this_genomic_align_block]);
}


1;
