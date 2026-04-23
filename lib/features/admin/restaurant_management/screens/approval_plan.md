

# Restaurant Approval Flow Plan

## Goal
Build the admin-side restaurant approval flow for Taste Spot.

This flow is responsible for reviewing restaurant approval records created from:
- user-submitted new restaurants
- API-detected restaurant conflicts / replacement cases

The approval flow must allow admin to:
- see a list of approval records
- filter and inspect approval records
- open a full-screen approval review screen
- edit all approval fields before making a decision
- fully manage images during approval review
- accept an approval and create a real `Restaurant`
- reject an approval and block linked pending posts
- keep approved/rejected approvals visible in history

This plan is intended to be read by Codex and used as implementation guidance.

---

# Core Data / Table Context

## `RestaurantApproval`
This is the pending/reviewable restaurant candidate table.

Important fields include:
- `approval_Id`
- `curr_restaurant_id`a
- `restaurant_name`
- `address`
- `latitude`
- `longitude`
- `maps_url`
- `source`
- `status`
- `detectedAt`
- `main_cuisine_id`
- any approval-side image support now used in the project

### Approval status meaning
- `0 = pending / not reviewed`
- `1 = accepted`
- `2 = rejected`

## `Post`
Posts may now be linked to a restaurant approval when a user creates a post for a restaurant that does not yet exist in the main `Restaurant` table.

Important fields involved in this flow:
- `post_Id`
- `restaurant_Id`
- `restaurant_approval_id`
- `isPending`
- `isBlocked`

### Post linkage rules
When a user creates a post with a brand new restaurant:
1. insert `RestaurantApproval`
2. get `approval_Id`
3. insert `Post` with:
   - `restaurant_approval_id = approval_Id`
   - `restaurant_Id = null`
   - `isPending = true`

## `Restaurant`
This is the real main restaurant table.

When approval is accepted:
- a new `Restaurant` row is created
- if `curr_restaurant_id` exists, the current restaurant is always disabled on accept

## `restaurant_image`
Image metadata is stored separately.

Important fields:
- `image_id`
- `restaurant_id`
- `image_url`
- `isCover`

Approval review must support image editing/upload similar to restaurant edit flow.

---

# High-Level Approval Flow

## Approval list screen
Admin opens the approval list screen to see restaurant approval records.

This screen should not only show pending approvals. It should also act as an approval history screen.

Admin can:
- browse approval records
- filter by approval status
- search approval rows
- tap one approval row to enter full-screen review mode

## Approval review screen
Admin taps an approval row and opens a full-screen review page.

This screen uses the same restaurant form structure as the add/edit restaurant screen, but in a different mode:
- `approval_review_mode`

This mode is separate from normal add/edit restaurant mode.

Admin can:
- review all approval fields
- edit all approval fields
- edit cuisines
- fully manage images
- accept approval
- reject approval

## Accept / Reject decision
At the bottom of the approval review screen:
- `Reject`
- `Accept`

Both actions must require confirmation dialogs.

---

# Main Screens We Will Build

## 1. Approval List Screen

### Purpose
Show all restaurant approval records.

This screen should support:
- pending approvals
- accepted approvals
- rejected approvals
- history-style visibility for closed cases

### Main features
- list of approval records
- status filter:
  - pending
  - accepted
  - rejected
  - all
- search bar
- optional sorting
- tap row to open approval review screen

### Searchable fields
At minimum:
- restaurant name
- address

Optional later:
- source

### Filters
Required:
- status filter

Optional later:
- source
- detected time sort

### Row display suggestions
Each approval row should show useful summary info, such as:
- restaurant name
- source
- status badge
- detectedAt
- maybe address snippet
- maybe current restaurant indicator when `curr_restaurant_id` is not null

### States required
- loading state
- empty state
- no-result state
- error state

---

## 2. Approval Review Screen (`approval_review_mode`)

### Purpose
Review one `RestaurantApproval` record in full-screen editable mode.

This screen should use the same general form structure as restaurant add/edit, but must behave differently because the final actions are:
- Accept
- Reject

This is not a normal restaurant update screen.

### Key behavior
- full screen only
- all edits remain temporary in local screen/form state until final `Accept` or `Reject`
- editable reviewed form only
- no separate raw/original vs reviewed comparison section inside the main screen
- if `curr_restaurant_id` exists, show current restaurant basic info at the top

### Current restaurant info block
Only shown when:
- `curr_restaurant_id != null`

This block should show basic info of the currently existing restaurant, such as:
- current restaurant name
- current address
- current main cuisine
- current status
- optional cover image thumbnail
- optional source

Purpose:
- give admin context that this approval may replace or conflict with an existing restaurant
- help admin understand what currently exists before accepting the new record

### Editable form content
Admin should be able to edit **all approval fields**.

That includes:
- restaurant name
- address
- latitude
- longitude
- maps URL
- info URL if supported in the flow
- source
- main cuisine
- extra cuisine tags
- image data / image set
- cover image selection

### Image editing behavior
Approval review must fully support image editing and upload just like restaurant edit flow.

That means admin can:
- upload one or more images
- preview images
- remove images
- set exactly one cover image
- edit the image set before accepting or rejecting

Images edited during approval review are **not persisted immediately**.
Approval-review images stay only in local form state until final `Accept` or `Reject`.
If admin leaves the screen without taking either final action, all image edits are discarded.

### Cover image rules
- multiple images are allowed
- exactly one image can be cover when images exist
- `isCover = true` marks the cover image
- cover image should be visually labeled

### Buttons at the bottom
Required actions:
- `Reject`
- `Accept`

Both must show confirmation dialogs.

---

# Accept Flow

## Main rule
When admin accepts an approval, the new `Restaurant` must be created from the **edited form values**, not from stale original raw values.

At the same time, the approval row itself must also be updated with those edited values during the same flow.

This means:
- the approval row becomes the final reviewed case record
- the created `Restaurant` is based on the same final reviewed data

## Accept flow steps

### Step 1: Validate edited approval form
Before admin can accept:
- validate required fields
- validate cuisine selection
- validate coordinate values if required
- validate image / cover image rules

### Step 2: Show Accept confirmation dialog
If `curr_restaurant_id == null`:
- show a normal confirmation dialog

If `curr_restaurant_id != null`:
- show a confirmation dialog with side-by-side comparison UI

#### Side-by-side comparison in Accept dialog
This comparison UI is only needed in the Accept confirmation dialog for conflict/replacement cases.

Show a compact comparison between:

##### Current restaurant
- current restaurant name
- current address
- current main cuisine
- optional current cover image thumbnail
- current status

##### Final edited approval version
- edited restaurant name
- edited address
- edited main cuisine
- optional edited cover image thumbnail
- source

Purpose:
- prevent accidental approval of the wrong replacement/conflict case
- give admin a final review moment before disabling the existing restaurant and creating the new one

### Step 3: Persist edited approval values
Approval review does **not** autosave.
Edited values remain only in local form state while admin is reviewing.

Only when admin confirms `Accept` should the system persist the final reviewed values back into the approval row.

This ensures:
- the approval record reflects the final reviewed state
- accepted approvals remain meaningful in history
- leaving the screen before final action does not save partial edits

### Step 4: Create the real `Restaurant`
Create a new `Restaurant` row using the final edited form values.

This includes:
- restaurant basic fields
- main cuisine
- source
- URLs
- coordinates
- any other supported fields in the final restaurant schema

### Step 5: Persist cuisine tags
After creating the new restaurant:
- set main cuisine in `Restaurant.main_cuisine_id`
- insert extra cuisine tags into `Restaurant_Cuisine`

### Step 6: Persist images
Use the final edited image set from approval review.

Expected behavior:
- approval-review images are temporary in local form state only
- do not upload them earlier during screen editing
- only after the new `Restaurant` is created and `restaurant_Id` is available:
  - upload the final selected images to Supabase Storage
  - write image metadata into `restaurant_image`
  - ensure only one image has `isCover = true`

If admin leaves the screen before final `Accept`, no image should be uploaded or persisted.

### Step 7: Disable old restaurant if `curr_restaurant_id` exists
Rule confirmed:
- if `curr_restaurant_id` exists, old restaurant is always disabled on accept

So on acceptance of a replacement/conflict case:
- set `isDisabled = true` on the current existing restaurant

### Step 8: Update linked pending posts
Find all posts where:
- `restaurant_approval_id = this approval_Id`
- `isPending = true`

Then update them to:
- `restaurant_Id = new restaurant_Id`
- `isPending = false`
- `restaurant_approval_id = null`

This is the rule for un-pending posts after approval.

### Step 9: Update approval status
Set:
- `status = 1`

### Step 10: Close case / navigate back
After successful accept:
- treat this approval as closed case
- no further editing needed in approval flow
- navigate back appropriately
- refresh approval list
- refresh restaurant list if needed

---

# Reject Flow

## Main rule
Rejection closes the approval case without creating a restaurant.

Related pending posts must be blocked from publication.

The approval ID should remain on the posts.

## Reject flow steps

### Step 1: Persist reviewed approval values only at final rejection
Approval review does **not** autosave.
Edited values remain only in local form state while admin is reviewing.

Only when admin confirms `Reject` should the system persist the final reviewed values into the approval row.

This keeps the rejected approval record as a meaningful reviewed record in history while ensuring that leaving the screen without final action does not save partial edits.

### Step 2: Show Reject confirmation dialog
Show confirmation dialog before applying rejection.

### Step 3: Update linked posts
Find all posts where:
- `restaurant_approval_id = this approval_Id`
- `isPending = true`

Update them to:
- `isBlocked = true`
- `isPending = false`

Do not set `restaurant_Id`.

Keep:
- `restaurant_approval_id`

This preserves traceability of which rejected approval the post belonged to.

### Step 4: Update approval status
Set:
- `status = 2`

### Step 5: Close case / navigate back
After successful rejection:
- approval becomes closed case
- it remains visible in history lists
- navigate back appropriately
- refresh approval list

---

# Approval Record Lifecycle Rules

## Pending
- `status = 0`
- editable in approval review mode
- can be accepted or rejected

## Accepted
- `status = 1`
- closed case
- remains visible in approval history / filtered lists
- not intended for further editing later

## Rejected
- `status = 2`
- closed case
- remains visible in approval history / filtered lists
- not intended for further editing later

---

# Why Approval Review Uses Its Own Mode

Even though approval review reuses the same restaurant form structure, it must be its own mode because:
- it loads from `RestaurantApproval`, not `Restaurant`
- it may show current restaurant context at top
- it uses Accept / Reject actions instead of Save / Update
- acceptance creates a new `Restaurant`
- rejection blocks linked posts
- replacement cases disable old restaurants

So this is not just a button-label change. It is a different review workflow.

---

# Shared Form Reuse Expectations

## Shared UI sections that can be reused from restaurant add/edit flow
- basic restaurant fields
- cuisine section
- image section
- cover image selection UI
- validation styling / error messaging

## Approval-mode-specific behavior
- load from approval record
- show current restaurant info block when `curr_restaurant_id` exists
- show Accept / Reject buttons
- use approval confirmation logic
- save edited values into approval row
- run accept/reject workflow instead of normal save/update

---

# State / UX Requirements

## Approval List Screen
Must support:
- loading
- empty state
- no search/filter result state
- error state

## Approval Review Screen
Must support:
- loading approval data
- leaving the screen without final `Accept` or `Reject` discards all unsaved edited values and image changes
- loading current restaurant basic info when needed
- loading cuisines/images
- image placeholder / missing image fallback
- submission loading state during accept/reject
- validation messages
- error handling for failed accept/reject

## Confirmation dialogs
Required:
- Reject confirmation dialog
- Accept confirmation dialog
- side-by-side comparison inside Accept confirmation dialog only when `curr_restaurant_id` exists

---

# Minimum Feature Checklist

## Approval List Screen
- [ ] approval list fetch
- [ ] status filter (pending/accepted/rejected/all)
- [ ] search support
- [ ] sort support if needed
- [ ] row summary display
- [ ] tap row to open approval review
- [ ] loading state
- [ ] empty state
- [ ] no-result state
- [ ] error state

## Approval Review Screen
- [ ] full-screen review form
- [ ] editable reviewed form
- [ ] current restaurant info block when `curr_restaurant_id` exists
- [ ] all editable restaurant fields
- [ ] main cuisine selector
- [ ] extra cuisine tags
- [ ] image upload/edit/remove
- [ ] cover image support
- [ ] Reject button
- [ ] Accept button
- [ ] reject confirmation dialog
- [ ] accept confirmation dialog
- [ ] side-by-side comparison in accept dialog for conflict/replacement
- [ ] loading state
- [ ] validation
- [ ] submission loading state
- [ ] error state

## Accept Workflow
- [ ] save edited approval values
- [ ] create new restaurant from edited values
- [ ] save cuisines
- [ ] save images
- [ ] disable old restaurant when `curr_restaurant_id` exists
- [ ] update linked pending posts
- [ ] clear `restaurant_approval_id` on approved posts
- [ ] set approval status to accepted

## Reject Workflow
- [ ] save edited approval values
- [ ] set linked posts `isBlocked = true`
- [ ] set linked posts `isPending = false`
- [ ] keep approval ID on linked posts
- [ ] set approval status to rejected

---

# Notes
- Do not treat approval review as the same backend behavior as restaurant edit.
- Reuse UI/form structure where helpful, but keep approval workflow logic separate.
- Accepted and rejected approvals remain visible in list/history.
- Accepted/rejected approvals are treated as closed cases.
- Approval review screen should show only the editable reviewed form, not a complex dual raw-vs-reviewed editor.
- The side-by-side comparison is only needed in the Accept confirmation dialog when `curr_restaurant_id` exists.
- When accepting, create the restaurant from final edited form values and persist those same values back into the approval row during the same flow.
- When rejecting, persist reviewed edits to the approval row as well before finalizing the case.
- Approval review is **not** a persistent draft editor. It is a temporary review form.
- If admin leaves the approval review screen without final `Accept` or `Reject`, all edited values are discarded.
- Approval-review images are not stored in a separate approval-image table and are not uploaded/persisted until final `Accept`.
- Only the final reviewed values at `Accept` or `Reject` are written back into `RestaurantApproval`.