=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a protein_tree cluster as input
Run an MCOFFEE multiple alignment on it, and store the resulting alignment
back into the protein_tree_member table.

input_id/parameters format eg: "{'gene_tree_id'=>726093}"
    gene_tree_id       : use family_id to run multiple alignment on its members
    options            : commandline options to pass to the 'mcoffee' program

=head1 SYNOPSIS

my $db     = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $mcoffee = Bio::EnsEMBL::Compara::RunnableDB::Mcoffee->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id,
                                                    -analysis   => $analysis );
$mcoffee->fetch_input(); #reads from DB
$mcoffee->run();
$mcoffee->output();
$mcoffee->write_output(); #writes to DB

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA;

use strict;

use IO::File;
use File::Basename;
use File::Path;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'use_exon_boundaries'   => 0,                       # careful: 0 and undef have different meanings here
    };
}


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for mcoffee from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

    if (defined $self->param('flow_other_method') and $self->param('flow_other_method') and $self->input_job->retry_count >= 3) {
        $self->dataflow_output_id($self->input_id, 2);
        $self->input_job->incomplete(0);
        die "The MSA failed 3 times. Trying another method.\n";
    }


    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);
    $self->param('protein_tree', $self->param('tree_adaptor')->fetch_by_dbID($self->param('gene_tree_id')));
    $self->param('protein_tree')->preload();

  # No input specified.
  if (!defined($self->param('protein_tree'))) {
    $self->post_cleanup;
    $self->throw("MCoffee job no input protein_tree");
  }

  print "RETRY COUNT: ".$self->input_job->retry_count()."\n";

  print "MCoffee alignment method: ".$self->param('method')."\n";

  #
  # A little logic, depending on the input params.
  #
  # Protein Tree input.
    #$self->param('protein_tree')->flatten_tree; # This makes retries safer
    # The extra option at the end adds the exon markers
    $self->param('input_fasta', $self->dumpProteinTreeToWorkdir($self->param('protein_tree'), $self->param('use_exon_boundaries')) );

  if (defined($self->param('redo')) && $self->param('method') eq 'unalign') {
    # Redo - take previously existing alignment - post-process it
    my $redo_sa = $self->param('protein_tree')->get_SimpleAlign(-id_type => 'MEMBER');
    $redo_sa->set_displayname_flat(1);
    $self->param('redo_alnname', $self->worker_temp_directory . $self->param('gene_tree_id').'.fasta' );
    my $alignout = Bio::AlignIO->new(-file => ">".$self->param('redo_alnname'),
                                     -format => "fasta");
    $alignout->write_aln( $redo_sa );
  }

  #
  # Ways to fail the job before running.
  #

  # Error writing input Fasta file.
  if (!$self->param('input_fasta')) {
    $self->post_cleanup;
    $self->throw("MCoffee: error writing input Fasta");
  }

  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs MCOFFEE
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift;

    return if ($self->param('single_peptide_tree'));
    $self->param('msa_starttime', time()*1000);
    $self->run_msa;
}


=head2 write_output
`
    Title   :   write_output
    Usage   :   $self->write_output
    Function:   parse mcoffee output and update protein_tree_member tables
    Returns :   none
    Args    :   none

=cut

sub write_output {
    my $self = shift @_;

    return if ($self->param('single_peptide_tree'));
    $self->parse_and_store_alignment_into_proteintree;

    # Store various alignment tags:
    $self->_store_aln_tags($self->param('protein_tree')) unless ($self->param('redo'));

}

sub post_cleanup {
    my $self = shift;

    if($self->param('protein_tree')) {
        $self->param('protein_tree')->release_tree;
        $self->param('protein_tree', undef);
    }

    $self->SUPER::post_cleanup if $self->can("SUPER::post_cleanup");
}

##########################################
#
# internal methods
#
##########################################


sub run_msa {
    my $self = shift;
    my $input_fasta = $self->param('input_fasta');

    # Make a temp dir.
    my $tempdir = $self->worker_temp_directory;
    print "TEMP DIR: $tempdir\n" if ($self->debug);

    my $msa_output = $tempdir . 'output.mfa';
    $msa_output =~ s/\/\//\//g;
    $self->param('msa_output', $msa_output);

    my $cmd = $self->get_msa_command_line;

    $self->compara_dba->dbc->disconnect_when_inactive(1);

    print STDERR "Running:\n\t$cmd\n" if ($self->debug);
    if(system($cmd)) {
        my $system_error = $!;

        $self->post_cleanup;
        die "Failed to execute [$cmd]: $system_error ";
    }

    $self->compara_dba->dbc->disconnect_when_inactive(0);
}

########################################################
#
# ProteinTree input/output section
#
########################################################

sub update_single_peptide_tree {
  my $self   = shift;
  my $tree   = shift;

  foreach my $member (@{$tree->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
    next unless($member->sequence);
    $member->cigar_line(length($member->sequence)."M");
    $self->compara_dba->get_GeneTreeNodeAdaptor->store($member);
    printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
  }
}

sub dumpProteinTreeToWorkdir {
  my $self = shift;
  my $tree = shift;
  my $use_exon_boundaries = shift;

  my $fastafile =$self->worker_temp_directory.($use_exon_boundaries ? 'proteintree_exon_' : 'proteintree_').($tree->root_id).'.fasta';

  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if((-e $fastafile) and not $use_exon_boundaries);
  print("fastafile = '$fastafile'\n") if ($self->debug);

  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write!");

  my $seq_id_hash = {};
  my $residues = 0;
  my $member_list = $tree->get_all_leaves;

  $self->param('tag_gene_count', scalar(@{$member_list}) );
  my $has_canonical_issues = 0;
  foreach my $member (@{$member_list}) {

    # Double-check we are only using canonical
    my $gene_member; my $canonical_member = undef;
    eval {
      $gene_member = $member->gene_member; 
      $canonical_member = $gene_member->get_canonical_Member;
    };
    if($self->debug() and $@) { print "ERROR IN EVAL (node_id=".$member->node_id.") : $@"; }
    unless (defined($canonical_member) && ($canonical_member->member_id eq $member->member_id) ) {
      my $canonical_member2 = $gene_member->get_canonical_Member;
      my $clustered_stable_id = $member->stable_id;
      my $canonical_stable_id = $canonical_member->stable_id;
      $tree->store_tag('canon.'.$clustered_stable_id."_".$canonical_stable_id,1);
      $has_canonical_issues++;
#       $member->disavow_parent;
#       $self->param('tree_adaptor')->delete_flattened_leaf($member);
#       my $updated_gene_count = scalar(@{$tree->get_all_leaves});
#       $tree->adaptor->delete_tag($tree->node_id,'gene_count');
#       $tree->store_tag('gene_count', $updated_gene_count);
#       next;
    }
    ####

      return undef unless ($member->isa("Bio::EnsEMBL::Compara::GeneTreeMember"));
      next if($seq_id_hash->{$member->sequence_id});
      $seq_id_hash->{$member->sequence_id} = 1;

      my $seq = '';
      if ($use_exon_boundaries) {
          $seq = $member->sequence_exon_bounded;
      } else {
          $seq = $member->sequence;
      }
      $residues += $member->seq_length;
      $seq =~ s/(.{72})/$1\n/g;
      chomp $seq;

      print OUTSEQ ">". $member->sequence_id. "\n$seq\n";
  }
  close OUTSEQ;

  $self->throw("Cluster has canonical transcript issues: [$has_canonical_issues]\n") if (0 < $has_canonical_issues);

  if(scalar keys (%$seq_id_hash) <= 1) {
    $self->update_single_peptide_tree($tree);
    $self->param('single_peptide_tree', 1);
  }

  $self->param('tag_residue_count', $residues);
  return $fastafile;
}


sub parse_and_store_alignment_into_proteintree {
  my $self = shift;

  return if ($self->param('single_peptide_tree'));
  my $msa_output =  $self->param('msa_output');
  my $format = 'fasta';
  my $tree = $self->param('protein_tree');

  if (2 == $self->param('use_exon_boundaries')) {
    $msa_output .= ".overaln";
  }
  return unless($msa_output and -e $msa_output);

  #
  # Read in the alignment using Bioperl.
  #
  use Bio::AlignIO;
  my $alignio = Bio::AlignIO->new(-file => "$msa_output", -format => "$format");
  my $aln = $alignio->next_aln();
  my %align_hash;
  foreach my $seq ($aln->each_seq) {
    my $id = $seq->display_id;
    my $sequence = $seq->seq;
    $self->throw("Error fetching sequence from output alignment") unless(defined($sequence));
    print STDERR "# ", $sequence, "\n" if ($self->debug);
    $align_hash{$id} = $sequence;
    # Lowercase aminoacids in the output alignment -- decaf has found overalignments
    if (my @overalignments = $sequence =~ /([gastplimvdneqfywkrhcx]+)/g) {
      eval { $tree->tree->store_tag('decaf.'.$id, join(":",@overalignments));};
    }
  }

  #
  # Convert alignment strings into cigar_lines
  #
  my $alignment_length;
  foreach my $id (keys %align_hash) {
      next if ($id eq 'cons');
    my $alignment_string = $align_hash{$id};
    unless (defined $alignment_length) {
      $alignment_length = length($alignment_string);
    } else {
      if ($alignment_length != length($alignment_string)) {
        $self->throw("While parsing the alignment, some id did not return the expected alignment length\n");
      }
    }
    # Call the method to do the actual conversion
    $align_hash{$id} = $self->_to_cigar_line(uc($alignment_string));
    #print "The cigar_line of $id is: ", $align_hash{$id}, "\n";
  }

  if (defined($self->param('redo'))) {
    # We clone the tree, attach it to the new clusterset_id, then store it.
    # protein_tree_member is now linked to the new one
    my ($from_clusterset_id, $to_clusterset_id) = split(':', $self->param('redo'));
    $self->throw("malformed redo option: ". $self->param('redo')." should be like 1:1000000")
      unless (defined($from_clusterset_id) && defined($to_clusterset_id));
    $self->throw('This funtionality does not work with the new API, yet.');
    my $clone_tree = $self->param('protein_tree')->root->copy;
    my $clusterset = $self->param('tree_adaptor')->fetch_by_dbID($to_clusterset_id);
    $clusterset->add_child($clone_tree);
    $self->param('tree_adaptor')->store($clone_tree);
    # Maybe rerun indexes - restore
    # $self->param('tree_adaptor')->sync_tree_leftright_index($clone_tree);
    $self->_store_aln_tags($clone_tree);
    # Point $tree object to the new tree from now on
    $tree->release_tree; $tree = $clone_tree;
  }

  #
  # Align cigar_lines to members and store
  #
  foreach my $member (@{$tree->get_all_leaves}) {
      # Redo alignment is member_id based, new alignment is sequence_id based
      if ($align_hash{$member->sequence_id} eq "" && $align_hash{$member->member_id} eq "") {
        $self->throw("empty cigar_line for ".$member->stable_id."\n");
      }
      # Redo alignment is member_id based, new alignment is sequence_id based
      $member->cigar_line($align_hash{$member->sequence_id} || $align_hash{$member->member_id});

      ## Check that the cigar length (Ms) matches the sequence length
      # Take the M lengths into an array
      my @cigar_match_lengths = map { if ($_ eq '') {$_ = 1} else {$_ = $_;} } map { $_ =~ /^(\d*)/ } ( $member->cigar_line =~ /(\d*[M])/g );
      # Sum up the M lengths
      my $seq_cigar_length; map { $seq_cigar_length += $_ } @cigar_match_lengths;
      my $member_sequence = $member->sequence; $member_sequence =~ s/\*//g;
      if ($seq_cigar_length != length($member_sequence)) {
        print $member_sequence."\n".$member->cigar_line."\n" if ($self->debug);
        $self->throw("While storing the cigar line, the returned cigar length did not match the sequence length\n");
      }

        #
        # We can use the default store method for the $member.
          ##print "UPDATING "; $member->print_member;
          $self->compara_dba->get_GeneTreeNodeAdaptor->store_node($member);
      
  }
}

# Converts the given alignment string to a cigar_line format.
sub _to_cigar_line {
    my $self = shift;
    my $alignment_string = shift;

    $alignment_string =~ s/\-([A-Z])/\- $1/g;
    $alignment_string =~ s/([A-Z])\-/$1 \-/g;
    my @cigar_segments = split " ",$alignment_string;
    my $cigar_line = "";
    foreach my $segment (@cigar_segments) {
      my $seglength = length($segment);
      $seglength = "" if ($seglength == 1);
      if ($segment =~ /^\-+$/) {
        $cigar_line .= $seglength . "D";
      } else {
        $cigar_line .= $seglength . "M";
      }
    }
    return $cigar_line;
}

sub _store_aln_tags {
    my $self = shift;
    my $tree = shift;

    print "Storing Alignment tags...\n";

    my $sa = $tree->get_SimpleAlign;

    # Alignment percent identity.
    my $aln_pi = $sa->average_percentage_identity;
    $tree->store_tag("aln_percent_identity",$aln_pi);

    # Alignment length.
    my $aln_length = $sa->length;
    $tree->store_tag("aln_length",$aln_length);

    # Alignment runtime.
    my $aln_runtime = int(time()*1000-$self->param('msa_starttime'));
    $tree->store_tag("aln_runtime",$aln_runtime);

    # Alignment method.
    my $aln_method = ref($self); #$self->param('method');
    $tree->store_tag("aln_method",$aln_method);

    # Alignment residue count.
    my $aln_num_residues = $sa->no_residues;
    $tree->store_tag("aln_num_residues",$aln_num_residues);

}


1;
