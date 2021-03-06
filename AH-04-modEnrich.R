#  Analyse the modules with globaltest o GOstats, SPIA, hopach


library("topGO")
library("Rgraphviz")
library("hgu133plus2.db")
library("WGCNA")
enableWGCNAThreads(6)
library("ReactomePA")
library("clusterProfiler")
library("igraph")
library("ggplot2")
library("org.Hs.eg.db")

# Load previously work done
# load(file = "TNF_AH-network-auto.RData", verbose = TRUE)
load(file = "InputWGCNA.RData", verbose = TRUE)
load(file = "shared_genes.RData", verbose = TRUE)
load(file = "TNF_AH-network-unsig.RData", verbose = TRUE)
 ## MEs moduleColors
# load(file = "InputWGCNA.RData", verbose = TRUE)
 ## data.wgcna disease samples ids
# load(file = "ME.RData", verbose = TRUE)
## MEs0
# load(file = "Module_info.RData", verbose = TRUE)
 ## moduleTraitCor moduleTraitPvalue
keepSamples <- rownames(data.wgcna) %in% vclin$files

disease.r <- apply(vclin, 2, as.numeric)
nam <- c("status_90", "infection_hospitalization", "aki", "hvpg_corte20",
         "hvpg_corte20", "lille_corte")
for (n in nam) {
  a <- as.factor(vclin[,n])
  levels(a)[levels(a) == ""] <- NA
  disease.r[, n] <- a
}
disease <- disease.r[, -c(1, 2)]

moduleTraitCor <- cor(MEs[keepSamples, ], disease,
                      use = "p")
moduleTraitPvalue <- corPvalueStudent(moduleTraitCor, nrow(data.wgcna))
f.results <- "shared_unsigned_unsigned"
orig <- setwd(file.path(f.results))

pdfn <- function(...){
  # Close any device and open a pdfn with the same options
  if (length(dev.list()) > 1) {
    dev.off()
  }
  pdf(...)
}

# Reconvert the data to the "normal" format, of each column a sample.
exprs <- t(data.wgcna)

# Obtain the annotation of the data
# load(file = "annots_study.RData", verbose = TRUE)

# I assume I keep the same order of genes (Which I do)
warning("m is Manually selected")
m <- length(unique(moduleColors))
genes <- as.factor(moduleColors)
numb.col <- 0:(m - 1)
names(numb.col) <- c("grey", standardColors(m - 1))
match.colors <- sum(unique(moduleColors) %in% c("grey", standardColors(203)))
if (match.colors != length(unique(moduleColors))) {
  stop("Colors not correctly assigned.")
}
# converts the name to the right number
lg <- levels(genes)
for (x in names(numb.col)) {
  levels(genes)[lg == x] <- numb.col[x]
}
genes <- as.numeric(levels(genes))[genes]
names(genes) <- rownames(exprs)

# Grup al genes of the same group
clusters <- sapply(unique(moduleColors), function(x, genes, nc){
  names(genes[genes == nc[x]])
}, genes = genes, nc = numb.col)

moduleSel <- function(modul, a){
  # Function to generate function to select the module
  selFun <- function(genes){
    # Function to select those genees of the same group
    # return(a[x])
    return(genes == a[modul])
    }
  return(selFun)
}


# ==============================================================================
#
#  Code chunk 0: Compare modules, general overview of the functions
#
# ==============================================================================

#Function to translate from probeid to entrezid
clustersEntrez <- sapply(clusters, function(x){
  # a <- unique(annots[annots$PROBEID %in% x,
  #                    "ENTREZID"])
  a <- select(org.Hs.eg.db, keys = x, columns = "ENTREZID", keytype = "SYMBOL")
  a <- unique(a)
  a[!is.na(a)]
})

# pdf("clusters_.pdf", onefile = TRUE, width = 20, height = 20)
# x.axis <- theme(axis.text.x = element_text(angle = 90, hjust = 1))
# eGO <- compareCluster(clustersEntrez, fun = "enrichGO", OrgDb = "org.Hs.eg.db")
# save(eGO, file = "eGO.RData")
# plot(eGO) + ggtitle("Enrich GO") + x.axis
# cGO <- compareCluster(clustersEntrez, fun = "enrichGO", ont = "CC",
#                       OrgDb = "org.Hs.eg.db")
# save(cGO, file = "eGO.RData")
# plot(cGO) + ggtitle("Enrich cc GO") + x.axis
# gGO <- compareCluster(clustersEntrez, fun = "groupGO", OrgDb = "org.Hs.eg.db")
# save(gGO, file = "gGO.RData")
# plot(gGO) + ggtitle("Group GO") + x.axis
# eP <- compareCluster(clustersEntrez, fun = "enrichPathway")
# save(eP, file = "eP.RData")
# plot(eP) + ggtitle("Enrich Pathways") + x.axis
# eK <- compareCluster(clustersEntrez, fun = "enrichKEGG")
# save(eK, file = "eK.RData")
# plot(eK) + ggtitle("Enrich KEGG") + x.axis
# dev.off()

select.modules <- function(MTC, MTP, p.value = 0.07,
                           threshold = 0.3, ntop = NULL) {
  #MTC module trait correlation
  #MTP module trait p.value
  #threshold is the correlation threshold
  # Check that the p.value is minor and that the absolute value of the
  # correlation is >= threshold or that ntop modules are get.
  significant <- MTP <= p.value
  vclin.names <- colnames(MTC)
  modules.names <- rownames(MTC)
  if (is.null(ntop)) {
    out <- significant & abs(MTC) >= threshold
    sapply(vclin.names, function(x, y, z) {
      a <- z[y[, x]]
      a[!sapply(a, is.na)]
    }, y = out, z = modules.names)
  } else {
    sapply(vclin.names, function(a, x, y, z, k) {
      cor.r <- abs(x[y[, a], a])
      a <- names(cor.r)[rank(cor.r) <= z]
      a[!sapply(a, is.na)]
    }, x = MTC, y = significant, z = ntop)
  }
}

IM <- select.modules(moduleTraitCor, moduleTraitPvalue,
                     p.value = 0.05, ntop = 3)

imodules <- unique(unlist(IM))

universeGenesEntrez <- unique(keys(org.Hs.eg.db, keytype = "ENTREZID"))
universeGenesEntrez <- universeGenesEntrez[!is.na(universeGenesEntrez)]

out <- sapply(imodules, function(x) {

  moduleName <- substring(x, 3)
  selFun <- moduleSel(moduleName, numb.col)

  # Preparing the objects with Entrezid for the reactome and kegg analysis
  moduleGenes <- clusters[moduleName][[1]]
  moduleGenesEntrez <- unique(select(org.Hs.eg.db, keys = moduleGenes,
                                     keytype = "SYMBOL",
                                     columns = "ENTREZID"))
  moduleGenesEntrez <- moduleGenesEntrez[!is.na(moduleGenesEntrez)]


  # ============================================================================
  #
  #  Code chunk 1: topGO analysis of each module
  #
  # ============================================================================

  # Prepare the topGOdata object
  GOdata <- new("topGOdata",
                ontology = "BP",
                description = paste("Molecular function of the",
                                    moduleName, "module."),
                allGenes = genes,
                # annot = annFUN.gene2GO, ## the new annotation function
                # affyLib = "org.Hs.eg.db",
                annot = annFUN.org,
                ID = "alias",
                mapping = "org.Hs.eg",
                geneSelectionFun = selFun)

  save(GOdata, file = "array_BP.RData")
  load(file = "array_BP.RData", verbose = TRUE)
  GOdata
  geneSelectionFun(GOdata) <- selFun
  GOdata
  description(GOdata) <- paste("Molecular function of the",
                               moduleName, "module.")

  resultFisher <- runTest(GOdata,
                          algorithm = "classic", statistic = "fisher")
  resultKS <- runTest(GOdata, algorithm = "classic", statistic = "ks")
  resultKS.elim <- runTest(GOdata, algorithm = "elim", statistic = "ks")

  allRes <- GenTable(GOdata, classic = resultFisher, Ks = resultKS,
                     elim = resultKS.elim, orderBy = "classic",
                     ranksOf = "classic", topNodes = 50, numChar = 100)
  write.csv(allRes, file = paste0("table_GO_", moduleName, ".csv"),
            row.names = FALSE)

  pdf(paste0("BP_GO_", moduleName, ".pdf"), onefile = TRUE)
  tryCatch({showSigOfNodes(GOdata,
               score(resultFisher), firstSigNodes = 2, useInfo = 'all')
    title(main = "GO analysis using Fisher algorithm")},
           error = function(e) {
             message("Couldn't calculate the Fisher")
             message(e)
           })
  tryCatch({showSigOfNodes(GOdata,
                 score(resultKS), firstSigNodes = 2, useInfo = 'all')
    title(main = "GO analysis using KS algorithm")},
    error = function(e) {
      message("Couldn't calculate the KS")
      message(e)
    })
  tryCatch({showSigOfNodes(GOdata,
               score(resultKS.elim), firstSigNodes = 2, useInfo = 'all')
    title(main = "GO analysis using KS elim algorithm")},
    error = function(e) {
      message("Couldn't calculate the KSelim")
      message(e)
    })
  dev.off()
  # ============================================================================
  #
  #  Code chunk 2: Reactome analysis of the module
  #
  # ============================================================================

  reactome_enrich <- enrichPathway(gene = moduleGenesEntrez,
                                   universe = universeGenesEntrez,
                                   pvalueCutoff = 0.05, readable = TRUE,
                                   minGSSize = 2)
  if (nrow(summary(reactome_enrich)) != 0) {
    write.csv(summary(reactome_enrich),
              file = paste0("reactome_", moduleName, ".csv"))
    pdf(paste0("reactome_", moduleName, ".pdf"), onefile = TRUE)
    tryCatch({dotplot(reactome_enrich)},
             error = function(e) {
               message("Couldn't plot the dotplot for reactome")
               message(e)
             })

    # One can use the fold change to visualize how are the genes expressed
    # with a foldChange = vector
    tryCatch({cnetplot(reactome_enrich, showCategory = 15,
                       categorySize = "geneRatio",
             layout = layout_nicely)},
      error = function(e) {
        message("Couldn't plot the cnetplot for reactome")
        message(e)
      })
    # summary(reactome_enrich)
    # dput(summary(reactome_enrich))
    # Can't have titles
   tryCatch({enrichMap(reactome_enrich, layout = layout_nicely,
              vertex.label.cex = 1, n = 15)},
    error = function(e) {
      message("Couldn't map the enrichMap for reactome")
      message(e)
    })
    dev.off()
  }

  # ============================================================================
  #
  #  Code chunk 3: Kegg analysis of each module
  #
  # ============================================================================

  kegg_enrich <- enrichKEGG(moduleGenesEntrez,
                            universe = universeGenesEntrez,
                            minGSSize = 2)
  if (nrow(summary(kegg_enrich)) != 0) {
    write.csv(summary(kegg_enrich),
              file = paste0("kegg_", moduleName, ".csv"))
    pdf(paste0("kegg_", moduleName, ".pdf"), onefile = TRUE)
    tryCatch({dotplot(kegg_enrich)},
    error = function(e) {
      message("Couldn't map the dotplot for KEGG")
      message(e)
    })
    tryCatch({cnetplot(kegg_enrich, showCategory = 15, categorySize = "geneNum",
             layout = igraph::layout_nicely)},
    error = function(e) {
      message("Couldn't map the cnetplot for KEGG")
      message(e)
    })
    tryCatch({enrichMap(kegg_enrich, layout = igraph::layout_nicely,
              vertex.label.cex = 1, n = 15)},
    error = function(e) {
      message("Couldn't map the enrichMap for KEGG")
      message(e)
    })
    dev.off()
  }

})
print(out)

# ==============================================================================
#
#  Code chunk 4: GSEA
#
# ==============================================================================

# gse <- gsePathway(as.vector(moduleGenesEntrez)[order(moduleGenesEntrez)],
#                   nPerm = 100,
#            minGSSize = 120, pvalueCutoff = 0.2,
#            pAdjustMethod = "BH", verbose = FALSE)
# pdfn(paste0("gsea_", moduleName, ".pdf"), onefile = TRUE)
# # General plotting
# enrichMap(gse)
# # Individual gene plot
# gseaplot(gse, geneSetID = moduleGenesEntrez[1])

