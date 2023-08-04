[comment]: # (Copyright © The Arvados Authors. All rights reserved.)
[comment]: # ()
[comment]: # (SPDX-License-Identifier: CC-BY-SA-3.0)

# R SDK for Arvados

This SDK focuses on providing support for accessing Arvados projects, collections, and the files within collections. The API is not final and feedback is solicited from users on ways in which it could be improved.

## Key Topics
* Installation
* Usage
  * Initializing API
  * Working with collections
  * Manipulating collection content
  * Working with Arvados projects
  * Help
* Building the ArvadosR package

## Installation

Minimum R version required to run ArvadosR is 3.3.0.

```r
install.packages("ArvadosR", repos=c("https://r.arvados.org", getOption("repos")["CRAN"]), dependencies=TRUE)
library('ArvadosR')
```

> **Note**
> On Linux, you may have to install supporting packages.
>
> On Centos 7, this is:
> ```
> yum install libxml2-devel openssl-devel curl-devel
> ```
>
> On Debian, this is:
> ```
> apt-get install build-essential libxml2-dev libssl-dev libcurl4-gnutls-dev
> ```


## Usage

### Initializing API

```r
# use environment variables ARVADOS_API_TOKEN and ARVADOS_API_HOST
arv <- Arvados$new()

# provide them explicitly
arv <- Arvados$new("your Arvados token", "example.arvadosapi.com")
```

Optionally, add `numRetries` parameter to specify number of times to retry failed service requests. Default is 0.

```r
arv <- Arvados$new("your Arvados token", "example.arvadosapi.com", numRetries = 3)
```

This parameter can be set at any time using `setNumRetries`

```r
arv$setNumRetries(5)
```

### Working with Aravdos projects

#### Create project:

##### Basic creation of the project:

```r
Properties <- list("key_1"="value_1", "key_2"="value_2")
newProject <- arv$project_create(name = "NewDocumentationProject", description = "This is a test project", ownerUUID = "HeadProjectUUID", properties = Properties)
```

##### Grant access rights for a project:

```r
arv$project_permission_give(type = "can_read", uuid = "projectUUID", user = "personUUID")
arv$project_permission_give(type = "can_write", uuid = "projectUUID", user = "personUUID") 
arv$project_permission_give(type = "can_manage", uuid = "projectUUID", user = "personUUID") 
```

##### Set properties for a project:

```r
Properties <- list("key_1" = "value_1")
arv$project_properties_set(Properties, "projectUUID")
```

#### Update project:

##### Basic update of the project:

```r
newProperties <- list("key_1"="value_1", "key_2"="value_2")
updatedProject <- arv$project_update(name = "NewDocumentationProject", properties = newProperties, uuid = "projectUUID")
```

##### Update access rights for a project:

```r
# update access
arv$project_permission_update(typeOld = "can_read", typeNew = 'can_write', uuid = "projectUUID", user = "personUUID")
# refuse access
arv$project_permission_refuse(type = "can_write", uuid = "projectUUID", user = "personUUID") 
```

##### Change properties for  a project:

```r
newProperties <- list("key_1"="value_1")
# delete one property
arv$project_properties_delete(oneProp = newProperties, uuid = "projectUUID")
# append properties
arv$project_properties_append(properties = newProperties, uuid = "projectUUID") 
```

#### Delete a project:

##### Delete

```r
arv$project_delete(uuid = "projectUUID")
```

##### Trash and untrash

```r
untrashedProject <- arv$project_untrash(uuid = "projectUUID")
arv$project_trash(uuid = "projectUUID")
```

#### Find a project:

##### Get a project:

```r
project <- arv$project_get("projectUUID")
```

##### List projects:

```r
## list subprojects of a project
projects <- arv$project_list(list(list("owner_uuid", "=", "aaaaa-j7d0g-ccccccccccccccc")))
## list projects which have names beginning with Example
examples <- arv$project_list(list(list("name","like","Example%")))
```

##### List all projects even if the number of items is greater than maximum API limit:

```r
projects <- listAll(arv$project_list, list(list("name","like","Example%")))
```

> **Note**
> Check method of filtering
> [Filtering methods:](https://doc.arvados.org/main/api/methods.html)

#### Other useful features:

# Check whether the project exists or not

```
arv$project_exist(uuid = newProject$uuid)
```

# Also check for given permissions

```
arv$project_permission_check(uuid = newProject$uuid, user =  'arlog-tpzed-wlzptadvp43l1xe', type = "can_read") # check access
```

# And project properties

```
arv$project_properties_get(uuid = newProject$uuid)
```

### Working with collections

#### Create a new collection:

##### Basic creation of the collection:

```r
Properties <- list("key_1" = "value_1")
newCollection <- arv$collections_create(name = "collectionTitle", description = "collectionDescription", ownerUUID = "HeadProjectUUID", properties = Properties)
```

##### Grant access rights for a collection:

```r
arv$collection_permission_give(type = "can_read", uuid = "collectionUUID", user = "personUUID") 
arv$collection_permission_give(type = "can_read", uuid = "collectionUUID", user = "personUUID") 
arv$collection_permission_give(type = "can_read", uuid = "collectionUUID", user = "personUUID") 
```

##### Set properties for a collection:

```r
newProperties <- list("key_1"="value_1", "key_2"="value_2")
arv$collections_properties_set(newProperties, "collectionUUID")
```

#### Update a collection’s metadata:

##### Basic update of the collection:

```r
newProperties <- list("key_1" = "value_1")
collection <- arv$collections_update(name = "newCollectionTitle", description = "newCollectionDescription", properties = newProperties, uuid = "collectionUUID")
```

##### Update access rights for a collection:

```r
# update access # not working yet
#arv$collection_permission_update(typeOld = "can_read", typeNew = 'can_write', uuid = "collectionUUID", user = "personUUID")
# refuse access # not working yet
#arv$collection_permission_refuse(type = "can_write", uuid = "collectionUUID", user = "personUUID") 
```

##### Change properties for  a collection:

```r
# delete property
toDel <- list("key_1"="value_1")
collection <- arv$collections_properties_delete(toDel, "collectionUUID")
# append properties
basicList <- list("key_1"="value_1")
collection <- arv$collections_properties_append(basicList, "collectionUUID") 
```

#### Delete a project:

##### Delete

```r
arv$collections_delete(newCollection$uuid)
```

##### Trash and untrash

```r
# not written yet
```

#### Find a project:

##### Get a project:

```r
newCollection <- arv$collections_get(newCollection$uuid)
```

##### List projects:

```r
# offset of 0 and default limit of 100
collectionList <- arv$collections_list(list(list("name", "like", "Test%")))
collectionList <- arv$collections_list(list(list("name", "like", "Test%")), limit = 10, offset = 2)
# count of total number of items (may be more than returned due to paging)
collectionList$items_available
# items which match the filter criteria
collectionList$items
```

##### List all collections even if the number of items is greater than maximum API limit:

```r
collectionList <- listAll(arv$collections_list, list(list("name", "like", "Test%")))
```

#### Other useful features:

# Check whether the collection exists or not

```
# not written yet
```

# Also check for given permissions

```
# not working yet
arv$collection_permission_check(uuid = newCollection$uuid, user =  'arlog-tpzed-wlzptadvp43l1xe', type = "can_read") 
```

# And project properties

```
arv$collections_properties_get(newCollection$uuid)
```

### Manipulating collection content

#### Initialize a collection object:

```r
collection <- Collection$new(arv, "uuid")
```

#### Find file :

##### Get list of files:

```r
files <- collection$getFileListing()
```

##### Get ArvadosFile or Subcollection from internal tree-like structure:

```r
arvadosFile <- collection$get("location/to/my/file.cpp")
arvadosSubcollection <- collection$get("location/to/my/directory/")
```

#### Read various file types:

##### The preferred and recommended way to read large files and files with unknown format:

```r
readFile <- collection$readArvFile(arvadosFile, istable = 'yes')                    # table
readFile <- collection$readArvFile(arvadosFile, istable = 'no')                     # text
readFile <- collection$readArvFile(arvadosFile)                                     # xlsx, csv, tsv, rds, rdata
readFile <- collection$readArvFile(arvadosFile, fileclass = 'fasta')                # fasta
readFile <- collection$readArvFile(arvadosFile, Ncol= 4, Nrow = 32)                 # binary data.frame, only numbers
readFile <- collection$readArvFile(arvadosFile, Ncol = 5, Nrow = 150, istable = "factor") # binary data.frame with factor or text
```

##### Read a table:

```r
arvadosFile   <- collection$get("myinput.txt")
arvConnection <- arvadosFile$connection("r")
mytable       <- read.table(arvConnection)
```

##### Read whole file or just a portion of it:

```r
fileContent <- arvadosFile$read()
fileContent <- arvadosFile$read("text")
fileContent <- arvadosFile$read("raw", offset = 1024, length = 512)
```

##### Read a gzip compressed R object:
```r
obj <- readRDS(gzcon(coll$get("abc.RDS")$connection("rb")))
```

#### Read various file types:

##### Write various file types: 

```r
writeFile <- collection$writeFile(name = "myoutput.csv", file = file, fileFormat = "csv", istable = NULL, collectionUUID = collectionUUID)             # csv
writeFile <- collection$writeFile(name = "myoutput.tsv", file = file, fileFormat = "tsv", istable = NULL, collectionUUID = collectionUUID)             # tsv
writeFile <- collection$writeFile(name = "myoutput.fasta", file = file, fileFormat = "fasta", istable = NULL, collectionUUID = collectionUUID)         # fasta
writeFile <- collection$writeFile(name = "myoutputtable.txt", file = file, fileFormat = "txt", istable = "yes", collectionUUID = collectionUUID)       # txt table
writeFile <- collection$writeFile(name = "myoutputtext.txt", file = file, fileFormat = "txt", istable = "no", collectionUUID = collectionUUID)         # txt text
writeFile <- collection$writeFile(name = "myoutputbinary.dat", file = file, fileFormat = "dat", collectionUUID = collectionUUID)                       # binary
writeFile <- collection$writeFile(name = "myoutputxlsx.xlsx", file = file, fileFormat = "xlsx", collectionUUID = collectionUUID)                       # xlsx
```

##### Write a table:

```r
arvadosFile   <- collection$create("myoutput.txt")[[1]]
arvConnection <- arvadosFile$connection("w")
write.table(mytable, arvConnection)
arvadosFile$flush()
```

##### Write to existing file (overwrites current content of the file):

```r
arvadosFile <- collection$get("location/to/my/file.cpp")
arvadosFile$write("This is new file content")
```

#### Get ArvadosFile or Subcollection size: 

```r
size <- arvadosFile$getSizeInBytes()
size <- arvadosSubcollection$getSizeInBytes()
```

#### Create new file in a collection (returns a vector of one or more ArvadosFile objects): 

```r
mainFile <- collection$create("cpp/src/main.cpp")[[1]]
fileList <- collection$create(c("cpp/src/main.cpp", "cpp/src/util.h"))
```

#### Delete file from a collection:

```r
collection$remove("location/to/my/file.cpp")
```

You can remove both Subcollection and ArvadosFile. If subcollection contains more files or folders they will be removed recursively.

> **Note**
> You can also remove multiple files at once:
> ```
> collection$remove(c("path/to/my/file.cpp", "path/to/other/file.cpp"))
> ```

#### Delete file or folder from a Subcollection:

```r
subcollection <- collection$get("mySubcollection/")
subcollection$remove("fileInsideSubcollection.exe")
subcollection$remove("folderInsideSubcollection/")
```

#### Move or rename a file or folder within a collection (moving between collections is currently not supported):

##### Directly from collection

```r
collection$move("folder/file.cpp", "file.cpp")
```

##### Or from file

```r
file <- collection$get("location/to/my/file.cpp")
file$move("newDestination/file.cpp")
```

##### Or from subcollection

```r
subcollection <- collection$get("location/to/folder")
subcollection$move("newDestination/folder")
```

> **Note**
> Make sure to include new file name in destination. In second example `file$move(“newDestination/”)` will not work.

#### Copy file or folder within a collection (copying between collections is currently not supported):

##### Directly from collection

```r
collection$copy("folder/file.cpp", "file.cpp")
```

##### Or from file

```r
file <- collection$get("location/to/my/file.cpp")
file$copy("destination/file.cpp")
```

##### Or from subcollection

```r
subcollection <- collection$get("location/to/folder")
subcollection$copy("destination/folder")
```


### Help

#### View help page of Arvados classes by puting `?` before class name:

```r
?Arvados
?Collection
?Subcollection
?ArvadosFile
```

#### View help page of any method defined in Arvados class by puting `?` before method name:

```r
?collections_update
?jobs_get
```

 <!-- Taka konwencja USAGE -->

## Building the ArvadosR package

```r
cd arvados/sdk && R CMD build R
```

This will create a tarball of the ArvadosR package in the current directory.

 <!-- Czy dodawać Documentation / Community / Development and Contributing / Licensing? Ale tylko do części Rowej? Wszystko? Wcale? -->

## Documentation

Complete documentation, including the [User Guide](https://doc.arvados.org/user/index.html), [Installation documentation](https://doc.arvados.org/install/index.html), [Administrator documentation](https://doc.arvados.org/admin/index.html) and
[API documentation](https://doc.arvados.org/api/index.html) is available at http://doc.arvados.org/

## Community

Visit [Arvados Community and Getting Help](https://doc.arvados.org/user/getting_started/community.html).

## Reporting bugs

[Report a bug](https://dev.arvados.org/projects/arvados/issues/new) on [dev.arvados.org](https://dev.arvados.org).

## Licensing

Arvados is Free Software.  See [Arvados Free Software Licenses](https://doc.arvados.org/user/copying/copying.html) for information about the open source licenses used in Arvados.
