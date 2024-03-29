## Script to convert NEXUS-alignment to GenBank feature table
## Intron positions should be encoded in the following format "charset intron = 202-256 394-451;"

nex2tbl <- function(INPUT_NEX,
                    OUTPUT_TBL,
                    GENE = "gene_name",
                    PRODUCT = "product_name",
                    CODON_START = 1,
                    TRANSL_TABLE = 1,
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
  # CODON_START  <- 1
  # TRANSL_TABLE <- 1
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
  
  ## Verify that all sequence names are unique
  if(length(names(nex)) != length(unique(names(nex)))){
    stop("Sequence names are not unique in the Nexus file!\n")
  }
  
  
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
  
  ## Calculate alignment length
  aln_len <- length(nex[[1]])
  
  ## If there are no introns
  if(length(introns) == 0){
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

  } # end of introns
  
  
  ############ Add exon segments
  
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
  
  ## Find exon regions
  oth <- 1:aln_len
  oth <- oth[!oth %in% ii]
  
  if(length(oth) > 0){
    ex <- collapseConsecutive(oth)
    
    ## Rename exons
    names(ex) <- paste("Exon_", 1:length(ex), sep = "")

    ## Add regions to the main list
    introns <- c(introns, ex)
    
    ## Sort regions by position
    introns <- introns[ order(laply(.data = introns, .fun = function(z){ z[1] })) ]
  }
  
  
  ## Check if there are any exon regions
  if(!sum(grepl(pattern = "Exon", x = names(introns))) > 0){
    stop("There are no exon regions in the alignment!\n")
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
  
  
  ## Find if sequence starts with an intron
  reg_len <- ddply(.data = reg_len, .variables = "SeqID",
                   .fun = function(x){
                     if(grepl(pattern = "Intron", x = x$Region[1])){
                       x$StartsWithIntron <- TRUE
                     } else {
                       x$StartsWithIntron <- FALSE
                     }
                     return(x)
                   })
  
  
  ## Find codon position for each sequence
  get_codon <- function(z, CDSTART = NULL){
    
    ## Sequence name
    seqid <- as.character( z$SeqID[1] )
    
    ## Get sequence
    seq <- numb_reg[[ seqid ]]
    
    ## Get sequence of all exons
    seq <- seq[ grep(pattern = "Exon", x = names(seq)) ]
    seq <- unlist(seq)
    
    ## Find start postion of the first exon basepair
    frst <- which.min(seq)
    
    if(CDSTART == 1){
      cdn <- rep(c(1,3,2), times = length(seq))
    }
    if(CDSTART == 2){
      cdn <- rep(c(2,1,3), times = length(seq))
    }
    if(CDSTART == 3){
      cdn <- rep(c(3,2,1), times = length(seq))
    }
    
    rz <- cdn[ frst ]
    
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
    
    if(nrow(ex) >= 1){
      ## Collapse consequtive ranges
      res <- sort(unlist(alply(.data = ex, .margins = 1, .fun = function(z){ z$Start : z$End })))
      res <- collapseConsecutive(res)
      
      ## Convert to list
      # res <- alply(.data = ex, .margins = 1, .fun = function(z){ c(z$Start, z$End) })
      
      ## Add sequence attributes
      attr(res, which = "SeqID") <- as.character( x$SeqID[1] )
      attr(res, which = "codon") <- codons[ which(codons$SeqID %in% x$SeqID[1]), "codon_start" ]
      attr(res, which = "seqlen") <- SeqLen[ which(SeqLen$SeqID %in% x$SeqID[1]), "SeqLen" ]
      
    } else {
      ## The case with intron-only sequence
      cat("WARNING: Intron-only sequence - ", as.character( x$SeqID[1] ), "\n")
      res <- NULL
    }
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
    
    ## Skip intron-only sequences (no output returned)
    if(is.null(x)){ return(NULL) }
    
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
  
  attr(For_tbl, "split_type")   <- NULL
  attr(For_tbl, "split_labels") <- NULL
  
  ## Remove NULL (no exons) instances
  nulls <- laply(.data = For_tbl, .fun = is.null)
  if(any(nulls)){ For_tbl <- For_tbl[ -which(nulls) ] }
  
  ## Remove NAs (empty sequence)
  # nas <- ...
  # if(any(nas)){ For_tbl <- For_tbl[ -which(nas) ] }
  
  
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
    tabular = reg_len,
    codons = codons
  )
  invisible(results)
}
