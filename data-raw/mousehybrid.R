
library('devtools')

##*###
##Read data
##*###
data_dir = '../nogit/data/mousehybrid'
files = list.files(data_dir, pattern = '.*\\.rds', full.names = TRUE)
data_list = lapply(files, readRDS)
names(data_list) = c('c57', 'cast', 'phenodata', 'featdata')
lapply(data_list, dim)

main <- function(data_list){

    ##*###
    ##featdata
    ##*###

    ##set row- and col-names
    featdata = data_list[['featdata']]
    var = featdata[['chrom:pos']]
    length(unique(var))
    rownames(featdata) = var
    colnames(featdata) = c('feat', 'chr', 'pos', 'c57', 'cast', 'var')

    ##factor -> chars
    factor.cols = unlist(lapply(featdata, is.factor))
    featdata[, factor.cols] = lapply(featdata[, factor.cols], as.character)

    ##check number of starting genes with at least two variants
    feat2nvars = table(featdata[, 'feat'])
    length(feat2nvars) #14,550
    feat.pass = names(feat2nvars)[feat2nvars > 1]
    length(feat.pass) #12,948
    feat.filt = merge(featdata, as.matrix(feat.pass), by.x = 'feat', by.y = 1)
    length(unique(feat.filt[, 'feat'])) #12948
    nrow(feat.filt) #174,831
    
    ##Dump for annovar annot
    ##chromosome, start position, end position, the reference nucleotides and the observed nucleotides
    ##In some cases, users may want to specify only positions but not the actual nucleotides. In that case, "0" can be used to fill in the 4th and 5th column
    n.vars = nrow(feat.filt)
    ref = rep(0, n.vars)
    alt = ref
    feat.filt = cbind(feat.filt, ref, alt)
    j.tab = file.path(data_dir, 'vars.twovargenes.anno')
    write.table(feat.filt[, c('chr', 'pos', 'pos', 'ref', 'alt')], sep = '\t', col.names = FALSE, row.names = FALSE, quote = FALSE, file = j.tab)
    
    
    ##*###
    ##Count data
    ##*###
    refcount = data_list[['c57']]
    altcount = data_list[['cast']]
    rownames(refcount) = featdata[, 'var']
    rownames(altcount) = featdata[, 'var']
    acset = list(featdata = featdata, refcount = refcount, altcount = altcount)    

    ##filter vars on expression in at least n cells
    ncells = 1
    mincount = 3
    acset = filter_var_mincount(acset, mincount, ncells)

    ##filter feats on number of vars
    nmin_var = 2
    acset = filter_feat_nminvar(acset, nmin_var)
                
    ##filter feats on counts. Require feat to have at least two vars that have expression in at least three cells, among cells that express at least two vars.
    mincount = 3
    ncells = 3
    acset = filter_feat_counts(acset, mincount, ncells)
        
    ##filter feats on gt. Require feat to have at least two vars that have monoallelic calls in at least three cells, among cells that have at least two vars with monoallelic calls.
    ncells = 3
    acset = call_gt(acset)
    acset = filter_feat_gt(acset, ncells)
    
    ##filter genes with variants on different chromosomes
    featdata = acset[['featdata']]
    feat2chr = tapply(featdata[, 'chr'], featdata[, 'feat'], table)
    feat2nchr = unlist(lapply(feat2chr, length))
    pass_feat = names(feat2nchr)[which(feat2nchr == 1)]
    acset = subset_feat(acset, pass_feat)
    
    
    ##*###
    ##phenodata
    ##*###

    pheno = data_list[['phenodata']]

    ##factor -> chars
    factor.cols = unlist(lapply(pheno, is.factor))
    pheno[, factor.cols] = lapply(pheno[, factor.cols], as.character)

    ##set row- and col-names
    colnames(pheno)[1] = 'sample'
    rownames(pheno) = pheno[, 'sample']

    ##ensure order is the same in pheno as in count matrixes
    nrow(pheno) == ncol(refcount)
    nrow(pheno) == length(which(pheno[, 'sample'] == colnames(refcount)))
    nrow(pheno) == length(which(colnames(altcount) == colnames(refcount)))
    pheno = pheno[colnames(refcount), ]


    ##*###
    ##Dump
    ##*###
    ##store in list
    mousehybrid = c(acset[c('featdata', 'refcount', 'altcount')], list(phenodata = pheno))

    ##dump
    save(mousehybrid, file = '../nogit/data/mousehybrid/mousehybrid.rda')

    
    ##Dump only 300 genes to package, since max size of data in Bioconductor pkg is 1M
    ngenes = 300
    featdata = mousehybrid$featdata
    feat2var = tapply(featdata$var, featdata$feat, unique)
    sel_vars = unlist(feat2var[1:ngenes])
    mousehybrid = subset_rows(mousehybrid, sel_vars)
    
    devtools::use_data(mousehybrid, overwrite = T)    
}
