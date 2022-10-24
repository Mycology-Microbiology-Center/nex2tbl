## Script to convert NEXUS-alignment to GenBank feature table
## Intron positions should be encoded in the following format "charset intron = 202-256 394-451;"

nex2tbl <- function(INPUT_NEX, OUTPUT_TBL,
  GENE = "gene_name",
  PRODUCT = "product_name",
  TRANSL_TABLE = 1,
  CODON_START = 1,
  FULL_GENE = FALSE
  ){


# ## Specify input and output files
# INPUT_NEX    <- "test/exons-introns_CODON_START-1_TEF1_simple.nex"
# OUTPUT_TBL   <- "test/exons-introns_CODON_START-1_TEF1_simple.nex.tbl"
# # OUTPUT_TBL <- NULL              # print the results to screen
# 
# ## Specify user-defined variables
# GENE         <- "gene_name"
# PRODUCT      <- "product_name"
# TRANSL_TABLE <- 1
# CODON_START  <- 1
# FULL_GENE    <- FALSE


library(ape)
library(plyr)

############################################################
############################################################ Data validation
############################################################

if(!CODON_START %in% c(1,2,3) | length(CODON_START) != 1){
  warning("Please provide valid CODON_START paramerter.\n")
}

if(is.na(GENE) | is.null(GENE) | length(GENE) != 1){
  warning("Please provide valid GENE name.\n")
}

if(is.na(PRODUCT) | is.null(PRODUCT) | length(PRODUCT) != 1){
  warning("Please provide valid PRODUCT description.\n")
}

if(is.na(TRANSL_TABLE) | is.null(TRANSL_TABLE) | length(TRANSL_TABLE) != 1){
  warning("Please provide valid translation table definition.\n")
}

if(FULL_GENE & CODON_START != 1){
  warning("If the sequence covers the whole coding region of a protein, GenBank expects CODON_START to be 1.\n")
}

############################################################
############################################################ Region coordinates
############################################################

## Load alignment in NEXUS format
nex <- read.nexus.data(INPUT_NEX)


## Parse coordinates of intronic regions
introns <- grep(
  pattern = "charset\\s+intron\\s*=\\s*",
  x = readLines(INPUT_NEX),
  ignore.case = TRUE,
  value = TRUE)

introns <- gsub(
  pattern = "charset\\s+intron\\s*=\\s*|;",
  replacement = "", 
  ignore.case = TRUE,
  perl = T, 
  x = introns)

## If there are no introns
if(length(introns) == 0){

  aln_len <- length(nex[[1]])
  introns <- list(
    Exon_1 = c(1, aln_len)
    )

} else {
## If there are some introns

  introns <- strsplit(x = introns, split = " ")[[1]]
  introns <- llply(.data = as.list(introns),
                   .fun = function(z){ 
                     z <- strsplit(z, split = "-")[[1]]
                     z <- as.numeric(z)
                     return(z)
                   })

  names(introns) <- paste("Intron_", 1:length(introns), sep = "")


  ## Add first and last segments
  aln_len <- length(nex[[1]])
  if(introns[[1]][1] > 1){
    introns <- c(list(c(1, introns[[1]][1] - 1)), introns)
    names(introns)[1] <- "Exon_1"
  }
  if(introns[[length(introns)]][2] < aln_len){
    introns <- c(introns, list(c(introns[[length(introns)]][2] + 1, aln_len)))
    names(introns)[length(introns)] <- "Exon_Last"
  }

} # end of introns



############ Add middle segments

## Collapse runs of consecutive numbers to ranges
collapseConsecutive <- function(x){
  
  ## Find ranges of numbers
  rg <- cumsum(c(TRUE, diff(x) > 1))
  
  ## Split numbers into ranges
  rs <- split(x = x, f = rg)
  
  ## Preserve only the first and last number in a range
  rs <- llply(.data = rs, .fun = function(z){ z[c(1, length(z))] })
  
  return(rs)
}
# collapseConsecutive(c(1,2,3,4,5,6,8,9,10,22,23))
# collapseConsecutive(c(1, 3:5,20:25,26, 28))


## Expand regions
ii <- llply(.data = introns, .fun = function(z){ z[1]:z[2] })
ii <- sort(unlist(ii))

## Find remaining exon regions
oth <- 1:max(ii)
oth <- oth[!oth %in% ii]

if(length(oth) > 0){
  ex <- collapseConsecutive(oth)
  
  ## Rename exons
  max_ex <- grep(pattern = "Exon_[0-9]+", x = names(introns), value = T, perl = T)
  max_ex <- max(as.numeric(gsub(pattern = "Exon_", replacement = "", x = max_ex)))
  names(ex) <- paste("Exon_", (max_ex + 1):(max_ex + length(ex)), sep = "")
  
  ## Add regions to the main list
  introns <- c(introns, ex)
  
  ## Sort regions by position
  introns <- introns[ order(laply(.data = introns, .fun = function(z){ z[1] })) ]
}


############################################################
############################################################ Seq analysis
############################################################


## Gap symbols
gaps <- c(".", "?", "-")

## Sequence length
SeqLen <- ldply(
  .data = nex,
  .fun = function(z){ data.frame(SeqLen = sum(!z %in% gaps)) },
  .id = "SeqID")

## Enumerate non-gap charactes
numb <- llply(
  .data = nex,
  .fun = function(z){ 
    seqlen <- sum(!z %in% gaps)
    z[!z %in% gaps] <- 1:seqlen
    z[z %in% gaps] <- NA
    z <- as.numeric(z)
    return(z)
  })

## Split alignment into regions
extract_region <- function(x, coords){ x[ coords[1]:coords[2] ] }

numb_reg <- llply(.data = numb,
                  .fun = function(z){
                    llply(.data = introns, .fun = function(cc){
                      extract_region(x = z, coords = cc) })
                  })


## Extract length of each region for each sequence
reg_len <- ldply(.data = numb_reg, .fun = function(z){
  ldply(.data = z, .fun = function(r){
    r <- na.omit(r)
    if(length(r) > 0){
      mi <- min(r, na.rm = TRUE)
      ma <- max(r, na.rm = TRUE)
    } else {
      mi <- ma <- NA
    }
    rez <- data.frame(Start = mi, End = ma)
    return(rez)
  }, .id = "Region")
}, .id = "SeqID")


## Remove missing regions
reg_len <- reg_len[!is.na(reg_len$Start), ]


## Find codon position for each sequence
get_codon <- function(z, CDSTART = NULL){
  
  ## Sequence name
  seqid <- as.character( z$SeqID[1] )
  
  ## Get sequence
  seq <- numb_reg[[ seqid ]]
  
  ## Get sequence of the first exon
  exn <- z$Region[ grep(pattern = "Exon", x = z$Region)[1] ]
  seq <- seq[[ exn ]]
  
  ## Find start postion
  frst <- which(seq == 1)
  
  if(CDSTART == 1){
    cdn <- rep(c(1,3,2), times = length(seq))
  }
  if(CDSTART == 2){
    cdn <- rep(c(2,1,3), times = length(seq))
  }
  if(CDSTART == 3){
    cdn <- rep(c(3,2,1), times = length(seq))
  }
  
  rz <- cdn[frst]
  
  rz <- data.frame(codon_start = rz)
  return(rz)
}
## e.g.,
# get_codon(z = subset(reg_len, SeqID == "AP2508"), CDSTART = 1)
# get_codon(z = subset(reg_len, SeqID == "AP2654"), CDSTART = 1)

codons <- ddply(.data = reg_len,
                .variables = "SeqID",
                .fun = function(z, ...){ get_codon(z, ...) },
                CDSTART = CODON_START)



############################################################
############################################################ Feature table
############################################################


## Prepare data for feature table construction
prep_for_tbl <- function(x){
  # x = part of a data.frame with region coordinates
  #   e.g., x <- subset(reg_len, SeqID == "SS1302")
  
  ## Extract exons
  ex <- x[ grep(pattern = "Exon_", x = x$Region), ]
  
  ## Collapse consequtive ranges
  res <- sort(unlist(alply(.data = ex, .margins = 1, .fun = function(z){ z$Start : z$End })))
  res <- collapseConsecutive(res)
  
  ## Convert to list
  # res <- alply(.data = ex, .margins = 1, .fun = function(z){ c(z$Start, z$End) })
  
  ## Add sequence attributes
  attr(res, which = "SeqID") <- as.character( x$SeqID[1] )
  attr(res, which = "codon") <- codons[ which(codons$SeqID %in% x$SeqID[1]), "codon_start" ]
  attr(res, which = "seqlen") <- SeqLen[ which(SeqLen$SeqID %in% x$SeqID[1]), "SeqLen" ]
  
  return(res)
}



## Function to construct feature table (for single sequence)
make_tbl <- function(x,
                     gene = "placeholder_gene_name", 
                     product = "placeholder_product_name",
                     transl_table = 1,
                     full_gene = FALSE){
  
  # x = output of `prep_for_tbl`
  #     list with exon coordinates + attributes
  
  min_len <- 1
  max_len <- attr(x, which = "seqlen")
  
  if(full_gene == FALSE){
    min_len <- paste("<", min_len, sep = "")
    max_len <- paste(">", max_len, sep = "")
    
    x[[1]][1] <- paste("<", x[[1]][1], sep = "")
    x[[length(x)]][2] <- paste(">", x[[length(x)]][2], sep = "")
  }
  
  ## CDS
  CDS <- laply(.data = x, .fun = paste, collapse = "\t")
  
  ## Print feature table
  cat(">Features ", attr(x, which = "SeqID"), "\n", sep = "")
  cat(paste(min_len, max_len, "gene", sep = "\t"), "\n", sep = "")
  cat("\t", "\t", "\t", "gene", "\t", gene, "\n", sep = "")
  cat(CDS[1], "\t", "CDS", "\n", sep = "")
  if(length(CDS) > 1){
    for(i in 2:length(CDS)){
      cat(CDS[i], "\n", sep = "")
    }}
  cat("\t", "\t", "\t", "product", "\t", product, "\n", sep = "")
  cat("\t", "\t", "\t", "codon_start", "\t", attr(x, which = "codon"), "\n", sep = "")
  cat("\t", "\t", "\t", "transl_table", "\t", transl_table, "\n", sep = "")
  
}


## Test:
# make_tbl( prep_for_tbl(subset(reg_len, SeqID == "SS1308")) )


## Batch processing of seqs
For_tbl <- dlply(
  .data = reg_len,
  .variables = "SeqID",
  .fun = prep_for_tbl
)


## Export feature tables to the file
if(!is.null(OUTPUT_TBL)){ sink(file = OUTPUT_TBL) }

l_ply(
  .data = For_tbl,
  .fun = make_tbl,
  gene = GENE,
  product = PRODUCT,
  transl_table = TRANSL_TABLE,
  full_gene = FULL_GENE)

## Stop writing to the file
if(!is.null(OUTPUT_TBL)){ sink() }

results <- list(
  tabular = For_tbl
  )
invisible(results)
}
