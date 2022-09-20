# nex2tbl
nex2tbl is a tool aimed to help with submission of protein-coding DNA sequences to GenBank. Such sequences are commonly submitted through BankIt portal, where a [Feature Table File](https://www.ncbi.nlm.nih.gov/WebSub/html/help/feature-table.html) (.tbl file) is prompted if a user uploads multiple records. Prepareation of .tbl can be a laborous task, especially if sequences include multiple introns or start from different codon positions. nex2tbl allows to create a minimum essential .tbl with 2 feature keys `gene` and `CDS` and 3 qualifiers `product`, `codon_start`, and `transl_table` that are alltogether enough for GenBank to correctly translate DNA to amino acids.

Input for the tool is alignment of the submitted sequences of the _same_ gene in nexus format ([example](/test/exons-introns_CODON_START-1_TEF1_simple.nex)). Intron positions should be specified as column spans in a single charset called `intron`:
```
BEGIN SETS;
charset intron = 202-256 394-451;
END;
```
In addition, a user must specify the following values (explained in detail [here](http://www.insdc.org/documents/feature_table.html#7.3.1)).

- `GENE` - gene name, e.g., "rpb1".
- `PRODUCT` - name of the produced protein, e.g., "RNA polymerase II largest subunit".
- `TRANSL_TABLE` - defines the genetic code table used, by default is 1 - universal genetic code table.
- `FULL_GENE` - can be FALSE ot TRUE depending on if the sequence covers the whole coding region of a protein. Usually it is not the case, and then locations of partial (incomplete) regions will be indicated with a  `<` or `>` before the number. Note: if TRUE, GenBank expects CODON_START to be 1. 
- `CODON_START` - indicates the offset at which the first complete codon of a coding region can be found, relative to the first base of a sequence that starts first in alignment. Can be 1, 2, or 3. On the example below it is seq4, and `CODON_START` will be 3.

```
codon_pos	23123123123123123123123
seq1		--------ttggcttcgttgttt
seq2		-------gctggcgacgttgttc
seq3		-----------------ttgttc
seq4		gaccgttgcttgcgacgctgttc
column_n	123456789 etc..........
```

Example of output for a single sequence:
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
