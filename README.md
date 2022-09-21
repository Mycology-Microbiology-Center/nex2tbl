# nex2tbl
nex2tbl is a tool aimed to help with submission of protein-coding DNA sequences to GenBank. Such sequences are commonly submitted through BankIt portal, where a [Feature Table File](https://www.ncbi.nlm.nih.gov/WebSub/html/help/feature-table.html) (\*.tbl file) is prompted if a user uploads multiple records. Preparation of tbl file can be a laborious task, especially if the sequences include multiple introns or start from different codon positions. nex2tbl allows to create a minimum essential tbl with 2 [feature keys](https://www.insdc.org/submitting-standards/feature-table/#7.2) (`gene` and `CDS`) and 3 [qualifiers](http://www.insdc.org/documents/feature_table.html#7.3.1) (`product`, `codon_start`, and `transl_table`) that are altogether enough for GenBank to correctly translate DNA into amino acids.

Current way of usage: download [nex2tbl.R](/nex2tbl.R), place it in the directory with your input files, specify file names and user-defined variables in the beginning of the script, and execute commands sequentially. Resulting tbl file will appear in the same directory.

Input for the tool is alignment of the submitted sequences of one gene in nexus format ([example](/test/exons-introns_CODON_START-1_TEF1_simple.nex)). Intron positions should be specified as column spans in a single charset called `intron`, like this:
```
BEGIN SETS;
charset intron = 202-256 394-451;
END;
```

In addition, a user must specify the following variables:
- `GENE` - gene name, e.g., "rpb1".
- `PRODUCT` - name of the produced protein, e.g., "RNA polymerase II largest subunit".
- `TRANSL_TABLE` - defines the genetic code table used, by default is 1 - universal genetic code table.
- `FULL_GENE` - can be `FALSE` or `TRUE` depending on whether the sequence covers the whole coding region of a protein. Usually it is not the case, and then locations of partial (incomplete) regions will be indicated with `<` or `>` before the number. Note: if `TRUE`, GenBank expects `CODON_START` to be 1. 
- `CODON_START` - indicates the offset at which the first complete codon of a coding region can be found in the alignment. It is specified in relation to the first base of the first exon and therefore can only take values 1, 2, or 3. On the example below, the first complete codon is in the seq4 and starts at the column 3 (marked with arrows), therefore `CODON_START` will be 3. Note: to define this variable a user must know the coding frame of alignment in advance.

```
             ↓
codon_pos  23123123123123123123123
seq1       --------ttggcttcgttgttt
seq2       -------gctggcgacgttgttc
seq3       -----------------ttgttc
seq4       gaccgttgcttgcgacgctgttc
column_n   123456789 etc..........
             ↑
```
### Example of output for a single sequence
```
>Features AP0451
<1	>817	gene
			gene	rpb1
<37	371	CDS
420	737
789	>817
			product	RNA polymerase II largest subunit
			codon_start	3
			transl_table	1
```
### Current limitations
- Value of `codon_start` won't be present in tbl for sequences that start from intron. Otherwise, the file will be ok.
- Exon-only alignment is not supported.
- Intron-only alignment is not supported.
### Credits
- Code: Vladimir Mikryukov
- Idea: Anton Savchenko and Iryna Yatsiuk
