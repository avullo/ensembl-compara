CREATE TABLE `genome_db` (
  `genome_db_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `taxon_id` int(10) unsigned DEFAULT NULL,
  `name` varchar(128) NOT NULL DEFAULT '',
  `assembly` varchar(100) NOT NULL DEFAULT '',
  `genebuild` varchar(100) NOT NULL DEFAULT '',
  `has_karyotype` tinyint(1) NOT NULL DEFAULT '0',
  `is_high_coverage` tinyint(1) NOT NULL DEFAULT '0',
  `genome_component` varchar(5) DEFAULT NULL,
  `strain_name` varchar(40) DEFAULT NULL,
  `display_name` varchar(255) DEFAULT NULL,
  `locator` varchar(400) DEFAULT NULL,
  `first_release` smallint(6) DEFAULT NULL,
  `last_release` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`genome_db_id`),
  UNIQUE KEY `name` (`name`,`assembly`,`genome_component`),
  KEY `taxon_id` (`taxon_id`)
) ENGINE=MyISAM  ;

CREATE TABLE `genomic_align` (
  `genomic_align_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_align_block_id` bigint(20) unsigned NOT NULL,
  `method_link_species_set_id` int(10) unsigned NOT NULL DEFAULT '0',
  `dnafrag_id` bigint(20) unsigned NOT NULL DEFAULT '0',
  `dnafrag_start` int(10) NOT NULL DEFAULT '0',
  `dnafrag_end` int(10) NOT NULL DEFAULT '0',
  `dnafrag_strand` tinyint(4) NOT NULL DEFAULT '0',
  `cigar_line` mediumtext NOT NULL,
  `visible` tinyint(2) unsigned NOT NULL DEFAULT '1',
  `node_id` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`genomic_align_id`),
  KEY `genomic_align_block_id` (`genomic_align_block_id`),
  KEY `method_link_species_set_id` (`method_link_species_set_id`),
  KEY `dnafrag` (`dnafrag_id`,`method_link_species_set_id`,`dnafrag_start`,`dnafrag_end`),
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM  MAX_ROWS=1000000000 AVG_ROW_LENGTH=60;

CREATE TABLE `genomic_align_block` (
  `genomic_align_block_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `method_link_species_set_id` int(10) unsigned NOT NULL DEFAULT '0',
  `score` double DEFAULT NULL,
  `perc_id` tinyint(3) unsigned DEFAULT NULL,
  `length` int(10) NOT NULL,
  `group_id` bigint(20) unsigned DEFAULT NULL,
  `level_id` tinyint(2) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`genomic_align_block_id`),
  KEY `method_link_species_set_id` (`method_link_species_set_id`)
) ENGINE=MyISAM ;

CREATE TABLE `genomic_align_tree` (
  `node_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` bigint(20) unsigned DEFAULT NULL,
  `root_id` bigint(20) unsigned NOT NULL DEFAULT '0',
  `left_index` int(10) NOT NULL DEFAULT '0',
  `right_index` int(10) NOT NULL DEFAULT '0',
  `left_node_id` bigint(10) DEFAULT NULL,
  `right_node_id` bigint(10) DEFAULT NULL,
  `distance_to_parent` double NOT NULL DEFAULT '1',
  PRIMARY KEY (`node_id`),
  KEY `parent_id` (`parent_id`),
  KEY `root_id` (`root_id`),
  KEY `left_index` (`root_id`,`left_index`)
) ENGINE=MyISAM ;

CREATE TABLE `hmm_annot` (
  `seq_member_id` int(10) unsigned NOT NULL,
  `model_id` varchar(40) DEFAULT NULL,
  `evalue` float DEFAULT NULL,
  PRIMARY KEY (`seq_member_id`),
  KEY `model_id` (`model_id`)
) ENGINE=MyISAM ;

CREATE TABLE `hmm_curated_annot` (
  `seq_member_stable_id` varchar(40) NOT NULL,
  `model_id` varchar(40) DEFAULT NULL,
  `library_version` varchar(40) NOT NULL,
  `annot_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reason` mediumtext,
  PRIMARY KEY (`seq_member_stable_id`),
  KEY `model_id` (`model_id`)
) ENGINE=MyISAM ;

CREATE TABLE `hmm_profile` (
  `model_id` varchar(40) NOT NULL,
  `name` varchar(40) DEFAULT NULL,
  `type` varchar(40) NOT NULL,
  `compressed_profile` mediumblob,
  `consensus` mediumtext,
  PRIMARY KEY (`model_id`,`type`)
) ENGINE=MyISAM ;

CREATE TABLE `homology` (
  `homology_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  `description` enum('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog','gene_split','between_species_paralog','alt_allele','homoeolog_one2one','homoeolog_one2many','homoeolog_many2many') DEFAULT NULL,
  `is_tree_compliant` tinyint(1) NOT NULL DEFAULT '0',
  `dn` float(10,5) DEFAULT NULL,
  `ds` float(10,5) DEFAULT NULL,
  `n` float(10,1) DEFAULT NULL,
  `s` float(10,1) DEFAULT NULL,
  `lnl` float(10,3) DEFAULT NULL,
  `species_tree_node_id` int(10) unsigned DEFAULT NULL,
  `gene_tree_node_id` int(10) unsigned DEFAULT NULL,
  `gene_tree_root_id` int(10) unsigned DEFAULT NULL,
  `goc_score` tinyint(3) unsigned DEFAULT NULL,
  `wga_coverage` decimal(5,2) DEFAULT NULL,
  `is_high_confidence` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`homology_id`),
  KEY `method_link_species_set_id` (`method_link_species_set_id`),
  KEY `species_tree_node_id` (`species_tree_node_id`),
  KEY `gene_tree_node_id` (`gene_tree_node_id`),
  KEY `gene_tree_root_id` (`gene_tree_root_id`)
) ENGINE=MyISAM ;

CREATE TABLE `homology_member` (
  `homology_id` int(10) unsigned NOT NULL,
  `gene_member_id` int(10) unsigned NOT NULL,
  `seq_member_id` int(10) unsigned DEFAULT NULL,
  `cigar_line` mediumtext,
  `perc_cov` float unsigned DEFAULT '0',
  `perc_id` float unsigned DEFAULT '0',
  `perc_pos` float unsigned DEFAULT '0',
  PRIMARY KEY (`homology_id`,`gene_member_id`),
  KEY `homology_id` (`homology_id`),
  KEY `gene_member_id` (`gene_member_id`),
  KEY `seq_member_id` (`seq_member_id`)
) ENGINE=MyISAM  MAX_ROWS=300000000;

CREATE TABLE `mapping_session` (
  `mapping_session_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` enum('family','tree') DEFAULT NULL,
  `when_mapped` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `rel_from` int(10) unsigned DEFAULT NULL,
  `rel_to` int(10) unsigned DEFAULT NULL,
  `prefix` char(4) NOT NULL,
  PRIMARY KEY (`mapping_session_id`),
  UNIQUE KEY `type` (`type`,`rel_from`,`rel_to`,`prefix`)
) ENGINE=MyISAM ;

CREATE TABLE `member_xref` (
  `gene_member_id` int(10) unsigned NOT NULL,
  `dbprimary_acc` varchar(10) NOT NULL,
  `external_db_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`gene_member_id`,`dbprimary_acc`,`external_db_id`),
  KEY `external_db_id` (`external_db_id`)
) ENGINE=MyISAM ;

CREATE TABLE `meta` (
  `meta_id` int(11) NOT NULL AUTO_INCREMENT,
  `species_id` int(10) unsigned DEFAULT '1',
  `meta_key` varchar(40) NOT NULL,
  `meta_value` text NOT NULL,
  PRIMARY KEY (`meta_id`),
  UNIQUE KEY `species_key_value_idx` (`species_id`,`meta_key`,`meta_value`(255)),
  KEY `species_value_idx` (`species_id`,`meta_value`(255))
) ENGINE=MyISAM  ;

CREATE TABLE `method_link` (
  `method_link_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(50) NOT NULL DEFAULT '',
  `class` varchar(50) NOT NULL DEFAULT '',
  PRIMARY KEY (`method_link_id`),
  UNIQUE KEY `type` (`type`)
) ENGINE=MyISAM ;

CREATE TABLE `method_link_species_set` (
  `method_link_species_set_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `method_link_id` int(10) unsigned NOT NULL,
  `species_set_id` int(10) unsigned NOT NULL,
  `name` varchar(255) NOT NULL DEFAULT '',
  `source` varchar(255) NOT NULL DEFAULT 'ensembl',
  `url` varchar(255) NOT NULL DEFAULT '',
  `first_release` smallint(6) DEFAULT NULL,
  `last_release` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`method_link_species_set_id`),
  UNIQUE KEY `method_link_id` (`method_link_id`,`species_set_id`),
  KEY `species_set_id` (`species_set_id`)
) ENGINE=MyISAM ;

CREATE TABLE `method_link_species_set_attr` (
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  `n_goc_null` int(11) DEFAULT NULL,
  `n_goc_0` int(11) DEFAULT NULL,
  `n_goc_25` int(11) DEFAULT NULL,
  `n_goc_50` int(11) DEFAULT NULL,
  `n_goc_75` int(11) DEFAULT NULL,
  `n_goc_100` int(11) DEFAULT NULL,
  `perc_orth_above_goc_thresh` float DEFAULT NULL,
  `goc_quality_threshold` int(11) DEFAULT NULL,
  `wga_quality_threshold` int(11) DEFAULT NULL,
  `perc_orth_above_wga_thresh` float DEFAULT NULL,
  `threshold_on_ds` int(11) DEFAULT NULL,
  PRIMARY KEY (`method_link_species_set_id`)
) ENGINE=MyISAM ;

CREATE TABLE `method_link_species_set_tag` (
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  `tag` varchar(50) NOT NULL,
  `value` mediumtext NOT NULL,
  PRIMARY KEY (`method_link_species_set_id`,`tag`),
  KEY `tag` (`tag`)
) ENGINE=MyISAM ;

CREATE TABLE `ncbi_taxa_name` (
  `taxon_id` int(10) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `name_class` varchar(50) NOT NULL,
  KEY `taxon_id` (`taxon_id`),
  KEY `name` (`name`),
  KEY `name_class` (`name_class`)
) ENGINE=MyISAM ;

CREATE TABLE `ncbi_taxa_node` (
  `taxon_id` int(10) unsigned NOT NULL,
  `parent_id` int(10) unsigned NOT NULL,
  `rank` char(32) NOT NULL DEFAULT '',
  `genbank_hidden_flag` tinyint(1) NOT NULL DEFAULT '0',
  `left_index` int(10) NOT NULL DEFAULT '0',
  `right_index` int(10) NOT NULL DEFAULT '0',
  `root_id` int(10) NOT NULL DEFAULT '1',
  PRIMARY KEY (`taxon_id`),
  KEY `parent_id` (`parent_id`),
  KEY `rank` (`rank`),
  KEY `left_index` (`left_index`),
  KEY `right_index` (`right_index`)
) ENGINE=MyISAM ;

CREATE TABLE `other_member_sequence` (
  `seq_member_id` int(10) unsigned NOT NULL,
  `seq_type` varchar(40) NOT NULL,
  `length` int(10) NOT NULL,
  `sequence` mediumtext NOT NULL,
  PRIMARY KEY (`seq_member_id`,`seq_type`)
) ENGINE=MyISAM  MAX_ROWS=10000000 AVG_ROW_LENGTH=60000;

CREATE TABLE `peptide_align_feature` (
  `peptide_align_feature_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `qmember_id` int(10) unsigned NOT NULL,
  `hmember_id` int(10) unsigned NOT NULL,
  `qgenome_db_id` int(10) unsigned DEFAULT NULL,
  `hgenome_db_id` int(10) unsigned DEFAULT NULL,
  `qstart` int(10) NOT NULL DEFAULT '0',
  `qend` int(10) NOT NULL DEFAULT '0',
  `hstart` int(11) NOT NULL DEFAULT '0',
  `hend` int(11) NOT NULL DEFAULT '0',
  `score` double(16,4) NOT NULL DEFAULT '0.0000',
  `evalue` double NOT NULL,
  `align_length` int(10) NOT NULL,
  `identical_matches` int(10) NOT NULL,
  `perc_ident` int(10) NOT NULL,
  `positive_matches` int(10) NOT NULL,
  `perc_pos` int(10) NOT NULL,
  `hit_rank` int(10) NOT NULL,
  `cigar_line` mediumtext,
  PRIMARY KEY (`peptide_align_feature_id`)
) ENGINE=MyISAM  MAX_ROWS=100000000 AVG_ROW_LENGTH=133;

CREATE TABLE `seq_member` (
  `seq_member_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `stable_id` varchar(128) NOT NULL,
  `version` int(10) DEFAULT '0',
  `source_name` enum('ENSEMBLPEP','ENSEMBLTRANS','Uniprot/SPTREMBL','Uniprot/SWISSPROT','EXTERNALPEP','EXTERNALTRANS','EXTERNALCDS') NOT NULL,
  `taxon_id` int(10) unsigned NOT NULL,
  `genome_db_id` int(10) unsigned DEFAULT NULL,
  `sequence_id` int(10) unsigned DEFAULT NULL,
  `gene_member_id` int(10) unsigned DEFAULT NULL,
  `has_transcript_edits` tinyint(1) NOT NULL DEFAULT '0',
  `has_translation_edits` tinyint(1) NOT NULL DEFAULT '0',
  `description` text,
  `dnafrag_id` bigint(20) unsigned DEFAULT NULL,
  `dnafrag_start` int(10) DEFAULT NULL,
  `dnafrag_end` int(10) DEFAULT NULL,
  `dnafrag_strand` tinyint(4) DEFAULT NULL,
  `display_label` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`seq_member_id`),
  UNIQUE KEY `stable_id` (`stable_id`),
  KEY `taxon_id` (`taxon_id`),
  KEY `genome_db_id` (`genome_db_id`),
  KEY `source_name` (`source_name`),
  KEY `sequence_id` (`sequence_id`),
  KEY `gene_member_id` (`gene_member_id`),
  KEY `dnafrag_id_start` (`dnafrag_id`,`dnafrag_start`),
  KEY `dnafrag_id_end` (`dnafrag_id`,`dnafrag_end`),
  KEY `seq_member_gene_member_id_end` (`seq_member_id`,`gene_member_id`)
) ENGINE=MyISAM  MAX_ROWS=100000000;

CREATE TABLE `seq_member_projection` (
  `source_seq_member_id` int(10) unsigned NOT NULL,
  `target_seq_member_id` int(10) unsigned NOT NULL,
  `identity` float(5,2) DEFAULT NULL,
  PRIMARY KEY (`target_seq_member_id`),
  KEY `source_seq_member_id` (`source_seq_member_id`)
) ENGINE=MyISAM ;

CREATE TABLE `seq_member_projection_stable_id` (
  `target_seq_member_id` int(10) unsigned NOT NULL,
  `source_stable_id` varchar(128) NOT NULL,
  PRIMARY KEY (`target_seq_member_id`),
  KEY `source_stable_id` (`source_stable_id`)
) ENGINE=MyISAM ;

CREATE TABLE `sequence` (
  `sequence_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `length` int(10) NOT NULL,
  `md5sum` char(32) NOT NULL,
  `sequence` longtext NOT NULL,
  PRIMARY KEY (`sequence_id`),
  KEY `md5sum` (`md5sum`)
) ENGINE=MyISAM  MAX_ROWS=10000000 AVG_ROW_LENGTH=19000;

CREATE TABLE `species_set` (
  `species_set_id` int(10) unsigned NOT NULL,
  `genome_db_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`species_set_id`,`genome_db_id`),
  KEY `genome_db_id` (`genome_db_id`)
) ENGINE=MyISAM ;

CREATE TABLE `species_set_header` (
  `species_set_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `size` int(10) unsigned NOT NULL,
  `first_release` smallint(6) DEFAULT NULL,
  `last_release` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`species_set_id`)
) ENGINE=MyISAM ;

CREATE TABLE `species_set_tag` (
  `species_set_id` int(10) unsigned NOT NULL,
  `tag` varchar(50) NOT NULL,
  `value` mediumtext NOT NULL,
  PRIMARY KEY (`species_set_id`,`tag`),
  KEY `tag` (`tag`)
) ENGINE=MyISAM ;

CREATE TABLE `species_tree_node` (
  `node_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) unsigned DEFAULT NULL,
  `root_id` int(10) unsigned DEFAULT NULL,
  `left_index` int(10) NOT NULL DEFAULT '0',
  `right_index` int(10) NOT NULL DEFAULT '0',
  `distance_to_parent` double DEFAULT '1',
  `taxon_id` int(10) unsigned DEFAULT NULL,
  `genome_db_id` int(10) unsigned DEFAULT NULL,
  `node_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`node_id`),
  KEY `taxon_id` (`taxon_id`),
  KEY `genome_db_id` (`genome_db_id`),
  KEY `parent_id` (`parent_id`),
  KEY `root_id` (`root_id`,`left_index`)
) ENGINE=MyISAM ;

CREATE TABLE `species_tree_node_attr` (
  `node_id` int(10) unsigned NOT NULL,
  `nb_long_genes` int(11) DEFAULT NULL,
  `nb_short_genes` int(11) DEFAULT NULL,
  `avg_dupscore` float DEFAULT NULL,
  `avg_dupscore_nondub` float DEFAULT NULL,
  `nb_dubious_nodes` int(11) DEFAULT NULL,
  `nb_dup_nodes` int(11) DEFAULT NULL,
  `nb_genes` int(11) DEFAULT NULL,
  `nb_genes_in_tree` int(11) DEFAULT NULL,
  `nb_genes_in_tree_multi_species` int(11) DEFAULT NULL,
  `nb_genes_in_tree_single_species` int(11) DEFAULT NULL,
  `nb_nodes` int(11) DEFAULT NULL,
  `nb_orphan_genes` int(11) DEFAULT NULL,
  `nb_seq` int(11) DEFAULT NULL,
  `nb_spec_nodes` int(11) DEFAULT NULL,
  `nb_gene_splits` int(11) DEFAULT NULL,
  `nb_split_genes` int(11) DEFAULT NULL,
  `root_avg_gene` float DEFAULT NULL,
  `root_avg_gene_per_spec` float DEFAULT NULL,
  `root_avg_spec` float DEFAULT NULL,
  `root_max_gene` int(11) DEFAULT NULL,
  `root_max_spec` int(11) DEFAULT NULL,
  `root_min_gene` int(11) DEFAULT NULL,
  `root_min_spec` int(11) DEFAULT NULL,
  `root_nb_genes` int(11) DEFAULT NULL,
  `root_nb_trees` int(11) DEFAULT NULL,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM ;

CREATE TABLE `species_tree_node_tag` (
  `node_id` int(10) unsigned NOT NULL,
  `tag` varchar(50) NOT NULL,
  `value` mediumtext NOT NULL,
  KEY `node_id_tag` (`node_id`,`tag`),
  KEY `tag` (`tag`)
) ENGINE=MyISAM ;

CREATE TABLE `species_tree_root` (
  `root_id` int(10) unsigned NOT NULL,
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  `label` varchar(256) NOT NULL DEFAULT 'default',
  PRIMARY KEY (`root_id`),
  UNIQUE KEY `method_link_species_set_id` (`method_link_species_set_id`,`label`)
) ENGINE=MyISAM ;

CREATE TABLE `stable_id_history` (
  `mapping_session_id` int(10) unsigned NOT NULL,
  `stable_id_from` varchar(40) NOT NULL DEFAULT '',
  `version_from` int(10) unsigned DEFAULT NULL,
  `stable_id_to` varchar(40) NOT NULL DEFAULT '',
  `version_to` int(10) unsigned DEFAULT NULL,
  `contribution` float DEFAULT NULL,
  PRIMARY KEY (`mapping_session_id`,`stable_id_from`,`stable_id_to`)
) ENGINE=MyISAM ;

CREATE TABLE `synteny_region` (
  `synteny_region_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`synteny_region_id`),
  KEY `method_link_species_set_id` (`method_link_species_set_id`)
) ENGINE=MyISAM ;

