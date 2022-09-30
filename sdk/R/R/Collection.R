# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

#' R6 Class Representing Arvados Collection
#'
#' @description
#' Collection class provides interface for working with Arvados collections,
#' for exaplme actions like creating, updating, moving or removing are possible.
#'
#' @seealso
#' \code{\link{https://github.com/arvados/arvados/tree/main/sdk/R}}

Collection <- R6::R6Class(

    "Collection",

    public = list(

        #' @field uuid Autentic for Collection UUID.
        uuid = NULL,

        #' @description
        #' Initialize new enviroment.
        #' @param api Arvados enviroment.
        #' @param uuid The UUID Autentic for Collection UUID.
        #' @return A new `Collection` object.
        #' @examples
        #' collection <- Collection$new(arv, CollectionUUID)
        initialize = function(api, uuid)
        {
            private$REST <- api$getRESTService()
            self$uuid <- uuid
        },

        #' @description
        #' Adds ArvadosFile or Subcollection specified by content to the collection. Used only with ArvadosFile or Subcollection.
        #' @param content Content to be added.
        #' @param relativePath Path to add content.
        add = function(content, relativePath = "")
        {
            if(is.null(private$tree))
                private$generateCollectionTreeStructure()

            if(relativePath == ""  ||
               relativePath == "." ||
               relativePath == "./")
            {
                subcollection <- private$tree$getTree()
            }
            else
            {
                relativePath <- trimFromEnd(relativePath, "/")
                subcollection <- self$get(relativePath)
            }

            if(is.null(subcollection))
                stop(paste("Subcollection", relativePath, "doesn't exist."))

            if("ArvadosFile"   %in% class(content) ||
               "Subcollection" %in% class(content))
            {
                if(!is.null(content$getCollection()))
                    stop("Content already belongs to a collection.")

                if(content$getName() == "")
                    stop("Content has invalid name.")

                subcollection$add(content)
                content
            }
            else
            {
                stop(paste0("Expected AravodsFile or Subcollection object, got ",
                            paste0("(", paste0(class(content), collapse = ", "), ")"),
                            "."))
            }
        },

        #' @description
        #' Read file content.
        #' @param file Name of the file.
        #' @param col Collection from which the file is read.
        #' @param sep  Separator used in reading tsv, csv file format.
        #' @param istable Used in reading txt file to check if the file is table or not.
        #' @param fileclass Used in reading fasta file to set file class.
        #' @param Ncol Used in reading binary file to set numbers of columns in data.frame.
        #' @param Nrow Used in reading binary file to set numbers of rows in data.frame size.
        #' @examples
        #' collection <- Collection$new(arv, collectionUUID)
        #' readFile <- collection$readArvFile(arvadosFile, istable = 'yes')                    # table
        #' readFile <- collection$readArvFile(arvadosFile, istable = 'no')                     # text
        #' readFile <- collection$readArvFile(arvadosFile)                                     # xlsx, csv, tsv, rds, rdata
        #' readFile <- collection$readArvFile(arvadosFile, fileclass = 'lala')                 # fasta
        #' readFile <- collection$readArvFile(arvadosFile, Ncol= 4, Nrow = 32)                 # binary, only numbers
        #' readFile <- collection$readArvFile(arvadosFile, Ncol = 5, Nrow = 150, istable = "factor") # binary with factor or text
        readArvFile = function(file, con, sep = ',', istable = NULL, fileclass = "SeqFastadna", Ncol = NULL, Nrow = NULL)
        {
            arvFile <- self$get(file)
            FileName <- arvFile$getName()
            FileName <- tolower(FileName)
            FileFormat <- gsub(".*\\.", "", FileName)
            if (FileFormat == "txt") {
                if (is.null(istable)){
                    stop(paste('You need to paste whether it is a text or table file'))
                } else if (istable == 'no') {
                    fileContent <- arvFile$read("text") # used to read
                    fileContent <- gsub("[\r\n]", " ", fileContent)
                } else if (istable == 'yes') {
                    arvConnection <- arvFile$connection("r") # used to make possible use different function later
                    fileContent <- read.table(arvConnection)
                }
            }
            else if (FileFormat  == "xlsx") {
                arvConnection <- arvFile$connection("r")
                fileContent   <- read.table(arvConnection)
            }
            else if (FileFormat == "csv" || FileFormat == "tsv") {
                arvConnection <- arvFile$connection("r")
                if (FileFormat == "tsv"){
                    mytable <- read.table(arvConnection, sep = '\t')
                } else if (FileFormat == "csv" & sep == '\t') {
                    mytable <- read.table(arvConnection, sep = '\t')
                } else if (FileFormat == "csv") {
                    mytable <- read.table(arvConnection, sep = ',')
                } else {
                    stop(paste('File format not supported, use arvadosFile$connection() and customise it'))
                }
            }
            else if (FileFormat == "fasta") {
                fileContent <- arvFile$read("text")

                # function to prosess data to fasta file
                read_fasta.file <- function(file){
                    new_file <- file
                    name <- sub("\r\n.*", "", new_file)
                    new_file <- sub(name, '', new_file)
                    new_file <- gsub("[\r\n]", "", new_file)
                    # add first atrr (name)
                    name <- sub(" .*", "", name)
                    name <- sub(".*>", "", name)
                    # add second atrr (Annot)
                    annot <- sub("\r.*", "", file)
                    # final:
                    attr(new_file, 'name') <- name
                    attr(new_file, 'Annot') <- annot
                    attr(new_file, 'class') <- fileclass
                    new_file
                }
                fastafile <- read_fasta.file(fileContent)
            }
            else if (FileFormat == "dat") {
                #fileContent <- arvFile$read()
                fileContent <- gzcon(arvFile$connection("rb"))

                # function to precess data to binary format
                read_bin.file <- function(fileContent) {
                    # read binfile
                    column.names <- readBin(fileContent, character(), n = Ncol)
                    bindata <- readBin(fileContent, numeric(), Nrow*Ncol+Ncol)
                    # check
                    res <- which(bindata < 0.0000001)
                    if (is.list(res)) {
                        bindata <- bindata[-res]
                    } else {
                        bindata <- bindata
                    }
                    # make a dataframe
                    data <- data.frame(matrix(data = NA, nrow = Nrow, ncol = Ncol))
                    for (i in 1:Ncol) {
                        data[,i] <- bindata[(1+Nrow*(i-1)):(Nrow*i)]
                    }
                    colnames(data) = column.names

                    len <- which(is.na(data[,Ncol])) # error if sth went wrong
                    if (length(len) == 0) {
                        data
                    } else {
                        stop(paste("there is a factor or text in the table, customize the function by typing more arguments"))
                    }
                }
                if (is.null(Nrow) | is.null(Ncol)){
                    stop(paste('You need to specify numbers of columns and rows'))
                }
                if (is.null(istable)) {
                    fileContent <- read_bin.file(fileContent) # call a function
                } else if (istable == "factor") { # if there is a table with col name
                    #col_factor <- readline(prompt= "Which column contains factor? ") # 5
                    #col_factor <- as.integer(col_factor)
                    fileContent <- read_bin.file(fileContent)
                    #mess <- paste("Remember to change factor to string")
                    #return(list(fileContent, mess))
                }
            }
            else if (FileFormat == "rds" || FileFormat == "rdata") {
                arvConnection <- arvFile$connection("rb")
                mytable <- readRDS(gzcon(arvConnection))
            }
            else {
                stop(parse(('File format not supported, use arvadosFile$connection() and customise it')))
            }
        },

        #' @description
        #' Write file content
        #' @param name Name of the file.
        #' @param file File to be saved.
        #' @param istable Used in writing txt file to check if the file is table or not.
        #' @examples
        #' collection <- Collection$new(arv, collectionUUID)
        #' writeFile <- collection$writeFile("myoutput.csv", file, istable = NULL)             # csv
        #' writeFile <- collection$writeFile("myoutput.fasta", file, istable = NULL)           # fasta
        #' writeFile <- collection$writeFile("myoutputtable.txt", file, istable = "yes")       # txt table
        #' writeFile <- collection$writeFile("myoutputtext.txt", file, istable = "no")         # txt text
        #' # to save file as format rds or Rdata, xslx, dat, check
        #' # https://github.roche.com/BEDA-recipes/arv-s3
        #' s3write_using(file, FUN = write.xlsx, object = "output.xlsx", bucket = my_collection) # xslx
        #' s3write_using(file, FUN = writeBin, object = "output.dat", bucket = my_collection)    # dat
        writeFile = function(name, file, istable = NULL)
        {
            # prepare file and connection
            arvFile <- collection$create(name)[[1]]
            arvFile <- collection$get(name)
            arvConnection <- arvFile$connection("w")
            # get file format
            FileName <- arvFile$getName()
            FileName <- tolower(FileName)
            FileFormat <- gsub(".*\\.", "", FileName)
            if (FileFormat == "txt") {
                if (istable == "yes") {
                    write.table(file, arvConnection)
                    arvFile$flush()
                } else if (istable == "no") {
                    write(file, arvConnection)
                    arvFile$flush()
                } else {
                    stop(paste("Specify parametr istable"))
                }
            } else if (FileFormat == "csv") {
                write.csv(file, arvConnection)
                arvFile$flush()
            } else if (FileFormat == "fasta") {
                if (is.null(attributes(file)$Annot)) {
                    stop(paste("The sequence must have a name"))
                } else {
                    file <- paste(attributes(file)$Annot, toupper(file), sep="\n")
                    write(file, arvConnection)
                    arvFile$flush()
                }
            }
        },

        #' @description
        #' Creates one or more ArvadosFiles and adds them to the collection at specified path.
        #' @param files Content to be created.
        #' @examples
        #' collection <- arv$collections_create(name = collectionTitle, description = collectionDescription, owner_uuid = collectionOwner, properties = list("ROX37196928443768648" = "ROX37742976443830153"))
        create = function(files)
        {
            if(is.null(private$tree))
                private$generateCollectionTreeStructure()

            if(is.character(files))
            {
                sapply(files, function(file)
                {
                    childWithSameName <- self$get(file)
                    if(!is.null(childWithSameName))
                        stop("Destination already contains file with same name.")

                    newTreeBranch <- private$tree$createBranch(file)
                    private$tree$addBranch(private$tree$getTree(), newTreeBranch)

                    private$REST$create(file, self$uuid)
                    newTreeBranch$setCollection(self)
                    newTreeBranch
                })
            }
            else
            {
                stop(paste0("Expected character vector, got ",
                            paste0("(", paste0(class(files), collapse = ", "), ")"),
                            "."))
            }
        },

        #' @description
        #' Remove one or more files from the collection.
        #' @param paths Content to be removed.
        #' @examples
        #' collection$remove(fileName.format)
        remove = function(paths)
        {
            if(is.null(private$tree))
                private$generateCollectionTreeStructure()

            if(is.character(paths))
            {
                sapply(paths, function(filePath)
                {
                    filePath <- trimFromEnd(filePath, "/")
                    file <- self$get(filePath)

                    if(is.null(file))
                        stop(paste("File", filePath, "doesn't exist."))

                    parent <- file$getParent()

                    if(is.null(parent))
                        stop("You can't delete root folder.")

                    parent$remove(file$getName())
                })

                "Content removed"
            }
            else
            {
                stop(paste0("Expected character vector, got ",
                            paste0("(", paste0(class(paths), collapse = ", "), ")"),
                            "."))
            }
        },

        #' @description
        #' Moves ArvadosFile or Subcollection to another location in the collection.
        #' @param content Content to be moved.
        #' @param destination Path to move content.
        #' @examples
        #' collection$move("fileName.format", path)
        move = function(content, destination)
        {
            if(is.null(private$tree))
                private$generateCollectionTreeStructure()

            content <- trimFromEnd(content, "/")

            elementToMove <- self$get(content)

            if(is.null(elementToMove))
                stop("Content you want to move doesn't exist in the collection.")

            elementToMove$move(destination)
        },

        #' @description
        #' Copies ArvadosFile or Subcollection to another location in the collection.
        #' @param content Content to be moved.
        #' @param destination Path to move content.
        #' @examples
        #' copied <- collection$copy("oldName.format", "newName.format")
        copy = function(content, destination)
        {
            if(is.null(private$tree))
                private$generateCollectionTreeStructure()

            content <- trimFromEnd(content, "/")

            elementToCopy <- self$get(content)

            if(is.null(elementToCopy))
                stop("Content you want to copy doesn't exist in the collection.")

            elementToCopy$copy(destination)
        },

        #' @description
        #' Refreshes the environment.
        #' @examples
        #' collection$refresh()
        refresh = function()
        {
            if(!is.null(private$tree))
            {
                private$tree$getTree()$setCollection(NULL, setRecursively = TRUE)
                private$tree <- NULL
            }
        },

        #' @description
        #' Returns collections file content as character vector.
        #' @examples
        #' list <- collection$getFileListing()
        getFileListing = function()
        {
            if(is.null(private$tree))
                private$generateCollectionTreeStructure()

            content <- private$REST$getCollectionContent(self$uuid)
            content[order(tolower(content))]
        },

        #' @description
        #' If relativePath is valid, returns ArvadosFile or Subcollection specified by relativePath, else returns NULL.
        #' @param relativePath Path from content is taken.
        #' @examples
        #' arvadosFile <- collection$get(fileName)
        get = function(relativePath)
        {
            if(is.null(private$tree))
                private$generateCollectionTreeStructure()

            private$tree$getElement(relativePath)
        },

        getRESTService = function() private$REST,
        setRESTService = function(newRESTService) private$REST <- newRESTService
    ),
    private = list(

        REST        = NULL,
        #' @tree beautiful tree of sth
        tree        = NULL,
        fileContent = NULL,

        generateCollectionTreeStructure = function(relativePath = NULL)
        {
            if(is.null(self$uuid))
                stop("Collection uuid is not defined.")

            if(is.null(private$REST))
                stop("REST service is not defined.")

            private$fileContent <- private$REST$getCollectionContent(self$uuid, relativePath)
            private$tree <- CollectionTree$new(private$fileContent, self)
        }
    ),

    cloneable = FALSE
)

#' print.Collection
#'
#' Custom print function for Collection class
#'
#' @param x Instance of Collection class
#' @param ... Optional arguments.
#' @export
print.Collection = function(x, ...)
{
    cat(paste0("Type: ", "\"", "Arvados Collection", "\""), sep = "\n")
    cat(paste0("uuid: ", "\"", x$uuid,               "\""), sep = "\n")
}







