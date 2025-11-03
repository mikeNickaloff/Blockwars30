# AGENT INSTRUCTIONS
- Read this entire document and follow it's process strictly. Details matter here.
- Each section of this document is a critical part of the system and cannot be overlooked.
- DO NOT change the engine/* files unless asked to do so specifically by filename or with prior approval
- Confirm any changes to engine/ as they will have large impacts
- Don't flood qml files with functions.
- Use declarative style that focuses on Item type creation where each Item type has only a few functions specific to just that kind of Item 
- inherit additional functions by creating Components (File.qml will become the equivalent of a C++ metatype inheriting from Component named File { } automatically if imported with ```import "relpath/to"```)
- Using multiple layers of defined metatypes is the key to making robust fully-featured QML code.
- Don't stack all functions into single file. 
- Break down into multiple QML files that inherit from each other based on their functionality.

# Agentic Data Storage and retrieval 
- provides accurate data retrieval and storage about a project
- decrease overhead by caching lots of data in a database
- replaces the need for massive context windows filled with file contents by using targeted sql statements to get relevant data

## when sqlite3 is available
- will use a local database to store project data 

### WHEEL.db
#### setup
- Use ```./wheel.sh``` to interact with the database.
- The database is in a sqlite3-backed file named WHEEL.db with the folowing tables.

> * `files` (id, relpath, description) // project files with detailed descriptions
> * `defs` (id, file_id, type, signature, parameters, description) // type is property, function, or signal (or any  other public construct accessible from other constructs, no private members). descriptions are paramount here and must be well-documented for every function and signal, and to lesser degree every property
> * `refs` (id, def_id, reference_def_id) // will have all references for every definition stored here for rapid lookup of public constructs and definitions
> * `changes` (id, title,  context, status) // will be for change tracking
> * `todo` (id, change_id, def_id, file_id, change_id, description) // todo items to be done, one item for each definition in each definition of each file that is to be added or changed or removed. Must have all fields completed before starting work
>
> [OPTIONAL] `change_files` (id, change_id, file_id) // optional chage file tracking per change (for complex tasks with many changes across multiple files)
> [OPTIONAL] `change_defs` (id, change_id, file_id, def_id) // optional definition tracking per change (for complex tasks with many changes to many definitions)

- chmod +x wheel.sh 

- wheel.sh will verify and import the database from WHEEL.sql if none is present. 
- if WHEEL.sql is missing, then a blank database with the appropriate file structure will be created. 
- When a blank WHEEL.db is created from the condition where no WHEEL.db and no WHEEL.sql were present,  ask the user if they would like you to scan the project folders and build the database first (highly recommended). Also let them know that Yes is the safest option. Of course, if they chose "no" then print the message "Warning: AGENT running without building database -- expect long waits." 



### sqlite3 database tools for WHEEL.db 

#### wheel.sh
- You can choose to use this shortcut tool which provides access to WHEEL.db through a convenience shell script: 
> ``` wheel.sh ```
- Many common operations are already supported and relevant data can quickly be accessed.

- There are many more use cases for wheel.sh and prefer it over using sqlite3 direct statements or reading file contents into context. 
> ``` ./wheel.sh --help```


#### Uses

- Use wheel.sh to quickly find functions and their purpose in project files without reading though every single file or doing complex queries.
- Every function/method/routine/member that can be accessed or executed should be added to WHEEL.db via` wheel.sh` with the signature and parameters whenever new code is added.
- Always check with `wheel.sh` output to see what other things have already been invented in this project before creating implementation steps or writing code.
- Always reference `wheel.sh` output when directly when writing code and utilize existing types or helpers when possible instead of creating new ones. Try to use base classes to decrease the amount of overall code paths in the application by reusing existing ones when possible.
- Before making any changes, create a new change entry using `wheel.sh` then add new rows for change_files and change_defs for each file / definition to be added.
- Once finished with the change table, then use select commands with inner join to get list of all files and defs that need to be changed and create todo items based on that output.
- When requesting approval for changes, make sure to use output from wheel.sh for providing data. do not rely on internal memory only.
- Do not verify that WHEEL.sql has been updated after dumping the database.
- If sqlite3 not available on system, silently ignore this section.
- Do not read `WHEEL.sql` into the internal agent context.


# GENERAL CODING SUGGESTIONS
* Break down large problems into multiple simple specfic steps when creating Implementation steps.
* Dont reinvent the wheel or modify existing code unless absolutely necessary.
* Look for a way to implement changes by using existing code first, then if not possible, create new code paths.
* Work slowly and go step-by-step to make compact, requirement fulfilling, working, elegant code.
