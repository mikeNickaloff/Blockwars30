# AGENT INSTRUCTIONS
- Read this entire document and follow it's process strictly. Details matter here.
- Each section is a critical part of the system and cannot be overlooked.
- Do not change the engine/*.qml files unless asked to do so specifically by filename.
- Confirm any changes to engine/ as they will have large impacts

# Agentic Data Storage and retrieval 
- provides accurate data retrieval and storage about a project
- decrease overhead by caching lots of data in a database
- replaces the need for massive context windows filled with file contents by using targeted sql statements to get relevant data

## when sqlite3 is available
- will use a local database to store project data 

### WHEEL.db
#### setup
- First check for WHEEL.md and WHEEL.db files
- If WHEEL.db doesnt exist, then check if sqlite3 in PATH with ```which sqlite3```
- If sqlite3 exists, then proceeed to create a new sqlite3 database called WHEEL.db with the following tables:

> * files (id, relpath, description) // project files
> * defs (id, file_id, type, parameters, description) // type is member, function, or signal
> * refs (id, def_id, reference_def_id) // will have all references for every definition stored here for rapid lookup
> * changes (id, title,  context, status) // will be for CHANGES.md change tracking
> * change_files (id, change_id, file_id) // for each change #, for each file that needs to be changed, need to have a row 
> * change_defs (id, change_id, file_id, def_id, description) // describes change to parameters or description of new definition if needed by a change #
> * todo (id, change_id, change_defs_id, change_files_id, change_defs_id, description) // todo items to be done, one item for each definition in each file that is to be added or changed. Must have all fields completed before starting work

- Once the WHEEL.db file is created, parse WHEEL.md (if it exists) and populate the database by using sqlite3 command line tool to populate the database (make sure to safely sanitize input)

- when available, WHEEL.db  replaces the need for:
>- CHANGES.md
>- WHEEL.md
>- TODO.md 

#### Uses


- Use WHEEL.db to quickly find functions and their purpose in project files without reading though every single file.
- Every function/method/routine that can be accessed or executed should be recorded here with the signature and parameters.
- Always read the file WHEEL.db  to see what other things have already been invented in this project before creating implementation steps or writing code.
- WHEEL.db is to be updated with a list of every file and every function/property available in each file in the project along with a quick one sentence explainer as to what it does and any special considerations that are not immediately obvious.
- WHEEL.db should use this format
- Always reference WHEEL.db when writing code and utilize existing types or helpers when possible instead of creating new ones. Try to use base classes to decrease the amount of overall code paths in the application by reusing existing ones when possible.

- Use sqlite commands to get information about the project or to see what functions are available in various files instead of re-reading them.. only re-read when not enough information is present in the database 
- Always update the WHEEL.db database when new functions, definitions of any kind are added
- Before making any changes, create a new change row then add new rows for change_files and change_defs for each file / definition to be added.
- Once finished with the change table, then use select commands with inner join to get list of all files and defs that need to be changed and create todo items based on that output.
- When requesting approval for changes, make sure to use output from sqlite3 databases and format in markdown when providing data. do not rely on internal memory only.
- When sqlite3 not available, fallback WHEEL.md, CHANGES.md, and TODO.md style outlined at the end of this document, otherwis


# GENERAL CODING SUGGESTIONS
* Break down large problems into multiple simple specfic steps when creating Implementation steps.
* Dont reinvent the wheel or modify existing code unless absolutely necessary.
* Look for a way to implement changes by using existing code first, then if not possible, create new code paths.
* Work slowly and go step-by-step to make compact, requirement fulfilling, working, elegant code.

# When sqlite3 not available
- Only consider the remainder of this document when working on systems without sqlite3 available.
- if WHEEL.db is in use, stop reading here.

## Legacy data storage
### WHEEL.MD
- Use WHEEL.md to quickly find functions and their purpose in project files without reading though every single file.
- Every function/method/routine that can be accessed or executed should be recorded here with the signature and parameters.
- Always read the file WHEEL.md  to see what other things have already been invented in this project before creating implementation steps or writing code.
- WHEEL.md is to be updated with a list of every file and every function/property available in each file in the project along with a quick one sentence explainer as to what it does and any special considerations that are not immediately obvious. 
- WHEEL.md should use this format
```
  # PowerupLibraryView.qml
  ## File details
  This file provides the viewing container class which transforms a PowerupRepository.qml Component into a formatted listView with information about each item from the PowerupRepository.

  ## Functions/methods/routines
  ###  _formatCells(cells) -- formats an array of cells into a more easily viewed format

  ## Properties/members
  ### repository -- reference pointer to PowerupRepository.qml instance

  ## signals/events
  ### editRequested(var entry) -- signal is emitted whenever the edit button is clicked for a specific item form the ListView in this component.
```
- Always reference WHEEL.md when writing code and utilize existing types or helpers when possible instead of creating new ones. Try to use base classes to decrease the amount of overall code paths in the application by reusing existing ones when possible. 

### CHANGES.md
* Maintain a CHANGES.md file at the repository root as the authoritative record of work plans before any coding begins.
* Every planned change must be documented in CHANGES.md and explicitly approved or revised before implementation work starts if the user requests approval before changes are to be made.
* Append new plans to the top of CHANGES.md so reviewers can quickly locate the most recent proposal.
* CHANGES.md entries must follow this format:
  
 ```
  # <Change #> - <Concise Plan Title>
  ## Status
  -  Pending/Approved/Needs Review/Needs information/Postponed/Scheduled/Complete
  ## Context
  - Brief bullets describing the motivation for the change.
  
  ## Proposed Changes
  - Step-by-step outline of the implementation approach.
  
  ## Questions / Comments
  - Outstanding considerations or decisions awaiting review.
  ```
  


### TODO.md
* Maintain a file TODO.md which contains the active list of to do items,
* This list should come from CHANGES.md specifically the implementation steps part of every change in that file.
* TO DO items should be simple, direct, and targetted to serve specific purpose - avoid vague or tasks with huge scope of work.
* Break down implementation steps into smaller TODO list items that are extremely simple and easy to quickly perform.
* This TODO list is internal list for agents to utilize to know what actual changes are to be made to the project without having to analyze large code bases.
* Read the TODO file and implement the items one at a time while reading WHEEL.md first to check for any updates and then adding new functions/methods/routines, properties/members and signals/events to WHEEL.md after you have finished creating them.
* Once an item is complte,remove it from the TODO.md file.
* Once all implementation steps are complete for a specific Change #, update the status of the Change # to Completed in CHANGES.md
