# ADDITIONAL AGENT INSTRUCTIONS
- Read this entire document and follow it's process strictly. Details matter here.
- Each section is a critical part of the system and cannot be overlooked.

## CHANGES.md
- Maintain a CHANGES.md file at the repository root as the authoritative record of work plans before any coding begins.
- Every planned change must be documented in CHANGES.md and explicitly approved or revised before implementation work starts if the user requests approval before changes are to be made.
- Append new plans to the top of CHANGES.md so reviewers can quickly locate the most recent proposal.
- CHANGES.md entries must follow this format:
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
  
## WHEEL.MD
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


## TODO.md
- Maintain a file TODO.md which contains the active list of to do items,
- This list should come from CHANGES.md specifically the implementation steps part of every change in that file.
- TO DO items should be simple, direct, and targetted to serve specific purpose - avoid vague or tasks with huge scope of work.
- Break down implementation steps into smaller TODO list items that are extremely simple and easy to quickly perform.
- This TODO list is internal list for agents to utilize to know what actual changes are to be made to the project without having to analyze large code bases.
- Read the TODO file and implement the items one at a time while reading WHEEL.md first to check for any updates and then adding new functions/methods/routines, properties/members and signals/events to WHEEL.md after you have finished creating them.
- Once an item is complte,remove it from the TODO.md file.
- Once all implementation steps are complete for a specific Change #, update the status of the Change # to Completed in CHANGES.md

## DEV_NOTES.md
- This file captures engineering rationale and guardrails for non-obvious behaviors.
- This file gives the Agentic-based code generator an easy to follow reference guide which will allow it to use pointers, members, functions, and ultimately combine complex files with large codebase functionality together to create code quickly and more accurately than a standard Agent can.
- Consult DEV_NOTES.md before changing core flows or timings so that future work stays consistent with intended gameplay feel and avoids reintroducing previously fixed issues.

# CODING GUIDELINES

- Follow the guidelines by using CHANGES.md, TODO.md and WHEEL.md to keep everything in a strict and controlled environment so we don't end up with a disaster and a huge mess to clean up. 
- Break down large problems into multiple simple specfic steps when creating Implementation steps.
- Don't re-invent the wheel or modify existing code unless absolutely necessary.
- Look for a way to implement changes by using existing code first, then if not possible, create new code paths.
- Work slowly and go step-by-step to make compact yet full featured code.
