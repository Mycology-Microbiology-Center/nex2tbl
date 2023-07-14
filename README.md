# nex2tbl

nex2tbl is an R tool aimed to help with submission of protein-coding DNA sequences to GenBank. Such sequences are commonly submitted through BankIt portal, where a [Feature Table File](https://www.ncbi.nlm.nih.gov/WebSub/html/help/feature-table.html) (\*.tbl file) is prompted if the user uploads multiple records. Preparation of the tbl file can be a laborious task, especially if the sequences include multiple introns or start from different codon positions. nex2tbl allows to create a minimum essential tbl with 2 [feature keys](https://www.insdc.org/submitting-standards/feature-table/#7.2) (`gene` and `CDS`) and 5 [qualifiers](http://www.insdc.org/documents/feature_table.html#7.3.1) (`gene`, `product`, `codon_start`, `transl_table`, and `partial` aka `<`/`>`) that are altogether enough for GenBank to correctly translate DNA into amino acids.

## Usage

- Make sure that `ape` and `plyr` packages are installed in your R environment.  

- Load the script.
```R
source("https://raw.githubusercontent.com/Mycology-Microbiology-Center/nex2tbl/main/nex2tbl.R")
```

- Specify input and output file names, as well as user-defined variables. Example:
```R
nex2tbl(
  INPUT_NEX = "exons-introns_CODON_START-2_RPB1.nex",
  OUTPUT_TBL = "exons-introns_CODON_START-2_RPB1.tbl",
  GENE = "rpb1",
  PRODUCT = "RNA polymerase II largest subunit",
  CODON_START = 2,
  TRANSL_TABLE = 1,
  FULL_GENE = FALSE
)
```
- Execute this script, and resulting tbl file will appear in your working directory.

## Documentation

Input for the tool is an alignment of the submitted sequences of one gene in the nexus format (\*.nex, [example](/test/exons-introns_CODON_START-2_RPB1.nex)). Intron positions should be specified in the end of the file as column spans in a single charset called `intron`, like this:
```
BEGIN SETS;
charset intron = 202-256 394-451;
END;
```

In addition, the user must specify the following variables:
- `GENE` - gene name, e.g., "rpb1".
- `PRODUCT` - name of the produced protein, e.g., "RNA polymerase II largest subunit".
- `CODON_START` - indicates the offset at which the first complete codon of a coding region can be found in the alignment. It is specified in relation to the first column of the first exon (which is not necessarily in the beginning of alignment!) and can only take values 1, 2, or 3. On the example below, the first complete codon starts in the 3rd column of the first exon, therefore `CODON_START` will be 3. To define this variable the user must know the coding frame of alignment beforehand.

![start_codon_example](https://github.com/Mycology-Microbiology-Center/nex2tbl/assets/62290967/136cc2cf-4e72-4ca9-831a-96747c35bc0e)

- `TRANSL_TABLE` - defines the [genetic code table](https://www.insdc.org/submitting-standards/genetic-code-tables/) used, by default is 1 - universal genetic code table.
- `FULL_GENE` - can be `FALSE` or `TRUE` depending on whether the sequence covers the whole coding region of a protein. Usually it is not the case, and then locations of the first and last regions (assumed to be incomplete) will be indicated with `<` and `>` before the numbers. If `TRUE`, GenBank expects `CODON_START` to be 1. 

### Output example for a single sequence
```
>Features seq4
<1	>2119	gene
			gene	rpb2
<1	74	CDS
128	1087
1144	>2119
			product	RNA polymerase II second largest subunit
			codon_start	3
			transl_table	1
```

### Notes

- Intron-only sequences are not supported - if they are present in the alignment, warnings will be shown and such sequences will be absent in the tbl.
- If charsets are not specified, whole aligment will be treated as a single exon.

## Credits

- Code: Vladimir Mikryukov
- Idea: Anton Savchenko and Iryna Yatsiuk
