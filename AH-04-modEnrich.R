#  Analyse the modules with globaltest o GOstats, SPIA, hopach
# First steps similar to the DE analysis


# library("globaltest")
# library("limma")
# library("SPIA")
# library("GOstats")
library("topGO")
library("Rgraphviz")
# library("ggbio")
# library("affy")
# library("RColorBrewer")
# library("gcrma")
# library("sva")
# library("svd")
library("hgu133plus2.db")
library("WGCNA")
enableWGCNAThreads(6)
library("ReactomePA")
library("clusterProfiler")
library("igraph")


# Load previously work done
load(file = "TNF_AH-network-auto.RData", verbose = TRUE)
 ## MEs moduleColors
load(file = "Input.RData", verbose = TRUE) 
 ## data.wgcna disease samples ids
load(file = "ME.RData", verbose = TRUE)
## MEs0
load(file = "Module_info.RData", verbose = TRUE)
 ## moduleTraitCor moduleTraitPvalue

pdfn <- function(...){
  # Close any device and open a pdfn with the same options
  if (length(dev.list()) > 1) {
    dev.off()
  }
  pdf(...)
}

# Reconvert the data to the "normal" format, of each column a sample.
exprs <- t(data.wgcna)
colnames(exprs) <- samples

# # Obtain the annotation of the data 
# annots <- select(hgu133plus2.db, keys = rownames(exprs),
#                  columns = c("GO", "SYMBOL", "GENENAME", "ENTREZID"),
#                  keytype = "PROBEID")
# save(annots, file = "annots_study.RData")
load(file = "annots_study.RData")


# I assume I keep the same order of genes (Which I do)
genes <- as.factor(moduleColors)
n <- length(unique(moduleColors)) - 1

numb.col <- 0:n
names(numb.col) <- labels2colors(numb.col)

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

moduleSel <- function(modul, n){
  # Function to generate function to select the module
  a <- 0:n
  names(a) <- labels2colors(0:n)
  selFun <- function(genes){
    # Function to select those genees of the same group
    # return(a[x])
    return(genes == a[modul])
    } 
  return(selFun)
}

moduleName <- "midnightblue"

selFun <- moduleSel(moduleName, n)

# Preparing the objects with Entrezid for the reactome and kegg analysis
moduleGenes <- clusters[moduleName][[1]]
moduleGenesEntrez <- unique(annots[annots$PROBEID %in% moduleGenes, 
                                   "ENTREZID"])
moduleGenesEntrez <- moduleGenesEntrez[!is.na(moduleGenesEntrez)]
universeGenesEntrez <- unique(annots[, "ENTREZID"])
universeGenesEntrez <- universeGenesEntrez[!is.na(universeGenesEntrez)]

#Function to translate from probeid to entrezid
clustersEntrez <- sapply(clusters, function(x){
  a <- unique(annots[annots$PROBEID %in% x, 
                "ENTREZID"])
  a[!is.na(a)]
})


# ==============================================================================
#
#  Code chunk 0: Compare modules, general overview of the functions 
#
# ==============================================================================

pdfn(paste0("pathways_cluster_", moduleName, ".pdf"), onefile = TRUE, 
     width = 20, height = 20)
eGO <- compareCluster(clustersEntrez, fun = "enrichGO")
plot(eGO)
gGO <- compareCluster(clustersEntrez, fun = "groupGO")
plot(gGO)
eP <- compareCluster(clustersEntrez, fun = "enrichPathway")
plot(eP)
eK <- compareCluster(clustersEntrez, fun = "enrichKEGG")
plot(eK)

# ==============================================================================
#
#  Code chunk 1: topGO analysis of each module
#
# ==============================================================================

# Prepare the topGOdata object
GOdata <- new("topGOdata",
              ontology = "BP",
              description = paste("Molecular function of the",
                                  moduleName, "module."),
              allGenes = genes,
              annot = annFUN.db , ## the new annotation function
              affyLib = "hgu133plus2.db",
              geneSelectionFun = selFun)

save(GOdata, file = "array_BP.RData")
# load(file = "array_BP.RData")
geneSelectionFun(GOdata) <- selFun
description(GOdata) <- paste("Molecular function of the", moduleName, "module.")

resultFisher <- runTest(GOdata,
                        algorithm = "classic", statistic = "fisher")
resultKS <- runTest(GOdata, algorithm = "classic", statistic = "ks")
resultKS.elim <- runTest(GOdata, algorithm = "elim", statistic = "ks")

allRes <- GenTable(GOdata, classic = resultFisher, Ks = resultKS,
                   elim = resultKS.elim, orderBy = "classic",
                   ranksOf = "classic", topNodes = 50, numChar = 100)

write.csv(allRes, file = paste0("table_GO_", moduleName, ".csv"),
          row.names = FALSE)

pdfn(paste0("BP_GO_fisher_", moduleName, ".pdf"), onefile = TRUE)
showSigOfNodes(GOdata,
               score(resultFisher), firstSigNodes = 2, useInfo = 'all')
showSigOfNodes(GOdata,
               score(resultKS), firstSigNodes = 2, useInfo = 'all')
showSigOfNodes(GOdata,
               score(resultKS.elim), firstSigNodes = 2, useInfo = 'all')

# ==============================================================================
#
#  Code chunk 2: Reactome analysis of the module
#
# ==============================================================================

reactome_enrich <- enrichPathway(gene = moduleGenesEntrez,
                                 universe = universeGenesEntrez,
                                 pvalueCutoff = 0.05, readable = TRUE,
                                 minGSSize = 2)
write.csv(summary(reactome_enrich),
          file = paste0("reactome_", moduleName, ".csv"))
pdfn(paste0("reactome_", moduleName, ".pdf"), onefile = TRUE)
dotplot(reactome_enrich)

# One can use the fold change to visualize how are the genes expressed
# with a foldChange = vector
cnetplot(reactome_enrich, showCategory = 15, categorySize = "geneNum",
         layout = layout_nicely)
# summary(reactome_enrich)
# dput(summary(reactome_enrich))
# Can't have titles
enrichMap(reactome_enrich, layout = layout_nicely,
          vertex.label.cex = 1, n = 15)


# ==============================================================================
#
#  Code chunk 3: Kegg analysis of each module
#
# ==============================================================================

kegg_enrich <- enrichKEGG(moduleGenesEntrez,
                          universe = universeGenesEntrez,
                          minGSSize = 2)
pdfn(paste0("kegg_", moduleName, ".pdf"), onefile = TRUE)
dotplot(kegg_enrich)
cnetplot(kegg_enrich, showCategory = 15, categorySize = "geneNum",
         layout = igraph::layout_nicely)
enrichMap(kegg_enrich, layout = igraph::layout_nicely,
          vertex.label.cex = 1, n = 15)

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
dev.off()