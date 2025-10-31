# AGENT INSTRUCTIONS
- Read this entire document and follow it's process strictly. Details matter here.
- Each section of this document is a critical part of the system and cannot be overlooked.
- DO NOT change the engine/* files unless asked to do so specifically by filename or with prior approval
- Confirm any changes to engine/ as they will have large impacts
- Don't flood qml files with functions. Use declarative style that focuses on Item creation where each Item type has only a few functions specific to just that kind of Item and inherit additional functions by sub-classing

# Agentic Data Storage and retrieval 
- provides accurate data retrieval and storage about a project
- decrease overhead by caching lots of data in a database
- replaces the need for massive context windows filled with file contents by using targeted sql statements to get relevant data

## when sqlite3 is available
- will use a local database to store project data 

### WHEEL.db
#### setup
- First check for WHEEL.db files
- If WHEEL.db doesnt exist, then check if sqlite3 is in PATH with ```which sqlite3```
- If sqlite3 exists, use the following command to build the database into WHEEL.db
``` sqlite3 ./WHEEL.db < WHEEL.sql ```

- The database structure of WHEEL.db is as follows:

> * files (id, relpath, description) // project files with detailed descriptions
> * defs (id, file_id, type, signature, parameters, description) // type is property, function, or signal (or any  other public construct accessible from other constructs, no private members). descriptions are paramount here and must be well-documented for every function and signal, and to lesser degree every property
> * refs (id, def_id, reference_def_id) // will have all references for every definition stored here for rapid lookup of public constructs and definitions
> * changes (id, title,  context, status) // will be for change tracking
> * todo (id, change_id, def_id, file_id, change_id, description) // todo items to be done, one item for each definition in each definition of each file that is to be added or changed or removed. Must have all fields completed before starting work

- chmod +x wheel.sh 

- After making changes to WHEEL.db, use sqlite3 to dump the database to WHEEL.sql with the command
``` sqlite3 WHEEL.db .dump > WHEEL.sql ```


### sqlite3 database tools for WHEEL.db 

#### wheel.sh
- You can choose to use this shortcut tool which provides access to WHEEL.db through a convenience shell script: ``` wheel.sh ```
- Many common operations are already supported and relevant data can quickly be accessed.

##### List all functions in the game/ui directory
``` ./wheel.sh --relpath "game/ui" --type function ```

##### Show all members from engine/Game*
``` ./wheel.sh --relpath engine/Game --type member ```


- There are many more use cases for wheel.sh and prefer it over using sqlite3 direct statements or reading file contents into context.


#### Uses

- Use wheel.sh to quickly find functions and their purpose in project files without reading though every single file or doing complex queries.
- Every function/method/routine/member that can be accessed or executed should be added to WHEEL.db (sqlite database) with the signature and parameters whenever new code is added.
- Always check with wheel.sh to see what other things have already been invented in this project before creating implementation steps or writing code.
- WHEEL.db is to be updated with a list of every file and every function/property available in each file in the project along with a descriptive paragraph between one and 3 sentences explainer as to what it does, what it effects, and any special considerations that are not immediately obvious.
- Always reference wheel.sh or WHEEL.db directly when writing code and utilize existing types or helpers when possible instead of creating new ones. Try to use base classes to decrease the amount of overall code paths in the application by reusing existing ones when possible.

- Before making any changes, create a new change row in WHEEL.db then add new rows for change_files and change_defs for each file / definition to be added.
- Once finished with the change table, then use select commands with inner join to get list of all files and defs that need to be changed and create todo items based on that output.
- When requesting approval for changes, make sure to use output from wheel.sh for providing data. do not rely on internal memory only.
- If sqlite3 not available on system, silently ignore this section.


# GENERAL CODING SUGGESTIONS
* Break down large problems into multiple simple specfic steps when creating Implementation steps.
* Dont reinvent the wheel or modify existing code unless absolutely necessary.
* Look for a way to implement changes by using existing code first, then if not possible, create new code paths.
* Work slowly and go step-by-step to make compact, requirement fulfilling, working, elegant code.
