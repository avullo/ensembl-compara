=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>

=head1 NAME

Bio::EnsEMBL::Compara::SpeciesTreeNode

=head1 DESCRIPTION

Specific subclass of the NestedSet to handle species trees

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::SpeciesTreeNode
  +- Bio::EnsEMBL::Compara::NestedSet

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with an underscore (_).

=cut

package Bio::EnsEMBL::Compara::SpeciesTreeNode;

use strict;
use warnings;

use Scalar::Util qw(weaken);

use base ('Bio::EnsEMBL::Compara::NestedSet');


sub _complete_cast_node {
    my ($self, $orig) = @_;
    $self->node_name($orig->name);
    if (exists $orig->{'_gdb'}) {
        $self->{'_genome_db'} = $orig->{'_gdb'};
        $self->genome_db_id($orig->{'_gdb'}->dbID);
        weaken($self->{'_genome_db'});
        $self->node_name($orig->{'_gdb'}->get_scientific_name('unique'));
    }
    if ($orig->isa('Bio::EnsEMBL::Compara::NCBITaxon')) {
        $self->taxon($orig);
    } elsif ($orig->{'_taxon'}) {
        $self->taxon($orig->{'_taxon'});
    } else {
        $self->taxon($orig->{'_taxon'}) if $orig->{'_taxon'};
        $self->taxon_id($orig->taxon_id);
    }
}


sub copy {
    my $self = shift;

    my $mycopy = $self->SUPER::copy(@_);

    $mycopy->taxon_id($self->taxon_id);
    $mycopy->genome_db_id($self->genome_db_id);
    $mycopy->name($self->name);
    return $mycopy;
}


sub find_nodes_by_field_value {
    my ($self, $field, $expected) = @_;

    return unless $self->can($field);
    my @nodes;
    for my $node (@{$self->get_all_nodes}) {
        push @nodes, $node if ($node->$field eq $expected);
    }
    return [@nodes];
}


=head2 taxon_id

    Arg[1]      : (opt.) <int> Taxon ID
    Example     : my $taxon_id = $tree->taxon_id
    Description : Getter/Setter for the taxon_id of the node
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub taxon_id {
    my ($self, $taxon_id) = @_;
    if (defined $taxon_id) {
        $self->{'_taxon_id'} = $taxon_id;
        delete $self->{'_taxon'};
    }
    return $self->{'_taxon_id'};
}

sub taxon {
    my ($self, $taxon) = @_;

    if (defined $taxon) {
        $self->{'_taxon_id'} = $taxon->dbID;
        $self->{'_taxon'} = $taxon;

    } elsif (!$self->{'_taxon'}) {
        if (defined $self->{'_taxon_id'}) {
            $self->{'_taxon'} = $self->adaptor->db->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($self->{'_taxon_id'});
        } else {
            throw("taxon_id is not defined. Can't fetch Taxon without a taxon_id");
        }
    }

    return $self->{'_taxon'};
}


sub genome_db_id {
    my ($self, $genome_db_id) = @_;
    if (defined $genome_db_id) {
        $self->{'_genome_db_id'} = $genome_db_id;
    }
    return $self->{'_genome_db_id'};
}

sub genome_db {
    my ($self) = @_;
    return $self->{'_genome_db'} if $self->{'_genome_db'};
    my $genome_db_id = $self->genome_db_id;
    return undef unless (defined $genome_db_id);
    $self->{'_genome_db'} = $self->adaptor->db->get_GenomeDBAdaptor->fetch_by_dbID($self->genome_db_id);
    weaken($self->{'_genome_db'});
    return $self->{'_genome_db'};
}

sub node_name {
    my ($self, $name) = @_;
    if (defined $name) {
        $self->{'_node_name'} = $name;
    }
    return $self->{_node_name};
}

sub name {
    my $self = shift;
    return $self->node_name(@_);
}

sub string_node {
    my $self = shift;

    my $s = $self->right_index ? sprintf('(%s,%s)', $self->left_index, $self->right_index).' ' : '';
    $s .= $self->toString()."\n";

    return $s;
}


sub get_scientific_name {
    my $self = shift;
    if (my $gdb = $self->genome_db) {
        return $gdb->get_scientific_name('unique');
    } elsif (my $taxon = $self->taxon) {
        return $taxon->scientific_name();
    }
    return $self->node_name;
}

sub get_common_name {
    my $self = shift;
    if (my $gdb = $self->genome_db) {
        return $gdb->display_name;
    } elsif (my $taxon = $self->taxon) {
        return $taxon->get_common_name();
    }
    return;
}


sub get_divergence_time {
    my ($self, $query_timetree) = @_;

    require Bio::EnsEMBL::Compara::Utils::SpeciesTree;
    if ($query_timetree && !$self->taxon->has_tag('ensembl timetree mya')) {
        my $mya = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate($self);
        $self->taxon->add_tag('ensembl timetree mya', $mya);
    }
    return $self->taxon->get_value_for_tag('ensembl timetree mya');
}


sub toString {
    my $self = shift;

    my @elts;
    push @elts, ($self->name ||  '(unnamed)');
    push @elts, sprintf('taxon_id=%s', $self->taxon_id) if $self->taxon_id;
    push @elts, sprintf('genome_db_id=%s', $self->genome_db_id) if $self->genome_db_id;

    return join(' ', @elts);
}


1;
