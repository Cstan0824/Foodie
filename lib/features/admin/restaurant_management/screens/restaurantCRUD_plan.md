

# Restaurant CRUD Plan

## Goal
Build the admin-side Restaurant CRUD flow for Taste Spot.

This module is meant to let admin:
- view restaurants
- search and filter restaurants
- manually add restaurants
- edit restaurant details
- upload and manage restaurant images
- disable restaurants with soft delete
- re-enable disabled restaurants
- refresh restaurant data list from the management screen

This CRUD flow should support the current database design, including:
- `Restaurant`
- `Cuisine`
- `Restaurant_Cuisine`
- `restaurant_image`

This plan uses a **3 screen CRUD flow**:
1. Restaurant Management Screen
2. View Restaurant Screen
3. Add/Edit Restaurant Screen

---

# Shared Rules and Behavior

## Restaurant image rules
- A restaurant can have **multiple images**.
- Images are stored in Supabase Storage.
- Image metadata is stored in `restaurant_image`.
- `restaurant_image` includes:
  - `image_id`
  - `restaurant_id`
  - `image_url`
  - `isCover`
- `isCover = true` means the image is the restaurant cover image.
- For each restaurant, **only one image can be the cover image**.
- The cover image is shown in:
  - restaurant list row thumbnail
  - restaurant detail header
- All restaurant images are shown in:
  - View Restaurant Screen
  - Add/Edit Restaurant Screen

## Restaurant status rules
- Restaurant soft delete uses `isDisabled = true`.
- Disabled restaurants are not physically deleted.
- If a restaurant is disabled:
  - the action button should become **Re-enable** instead of Disable
  - re-enable should set `isDisabled = false`

## Navigation rules
- Restaurant list uses **row tap only** to enter detail screen.
- Edit should navigate to a **new screen**, not a popup/dialog.
- Add and Edit should use **one reusable form screen**.

## UX / state rules
All screens should support:
- loading state
- empty state where relevant
- error state
- success feedback where relevant
- proper validation where relevant

## Confirmation rules
- Disabling a restaurant must require confirmation.
- Re-enabling a restaurant may also use confirmation, depending on implementation preference.

---

# Screen 1: Restaurant Management Screen

## Purpose
This is the main admin entry screen for restaurant management.

It allows admin to:
- browse restaurants
- search restaurants
- filter restaurants
- refresh the restaurant list
- go to add restaurant flow
- tap a row to view full restaurant details

## Main UI sections

### 1. Page header / app bar
Should clearly indicate this is the restaurant management screen.

Suggested elements:
- title: `Restaurant Management`
- optional subtitle or description
- back button if this is not a top-level admin page

### 2. Action buttons area
This area should contain the main actions for the screen.

Required actions:
- **Add Restaurant** button
- **Refresh Restaurant** button

#### Add Restaurant button
Purpose:
- navigate to Add/Edit Restaurant Screen in **add mode**

Expected behavior:
- open empty form
- allow admin to create a new restaurant manually

#### Refresh Restaurant button
Purpose:
- refresh the displayed restaurant list from database
- in future, this may also be connected to manual retrieval automation if needed

Expected behavior:
- trigger loading state
- reload latest restaurant list
- preserve search/filter state if possible
- show feedback if refresh fails

### 3. Search section
A search bar should be provided.

#### Search purpose
Allow admin to quickly find restaurants from the list.

#### Searchable fields
At minimum, search should support:
- restaurant name
- address

Optional later:
- source
- main cuisine
- area keywords

#### Search behavior
- search should update the visible list
- debounced search is preferred, but not mandatory for first version
- empty search text shows full list again

### 4. Filter section
Admin should be able to filter restaurant list.

#### Required filters
At minimum:
- status filter
  - active
  - disabled
  - all
- source filter
  - admin
  - API
  - user-approved
  - all
- main cuisine filter

#### Filter behavior
- filters should work together with search
- filters should update visible rows only
- reset / clear filter option is recommended

### 5. Restaurant list section
This is the main scrollable content area.

#### List requirements
- scrollable list
- each row represents one restaurant
- row tap navigates to View Restaurant Screen

#### What each row should show
Each row should display concise but useful information:
- cover image thumbnail
- restaurant name
- main cuisine name
- short address or area
- source
- status badge
  - active
  - disabled

Optional later:
- created date
- number of images

#### Row behavior
- tapping the row opens View Restaurant Screen for the selected restaurant
- no inline edit/disable buttons are required for first version since row tap is the chosen interaction

## States required

### Loading state
When restaurants are being fetched:
- show loader / progress indicator
- do not leave the page blank without explanation

### Empty state
When no restaurants exist:
- show message like `No restaurants found`
- optionally suggest using Add Restaurant

### No search results state
When search/filter returns no matches:
- show message like `No matching restaurants found`

### Error state
If list fetch fails:
- show error message
- offer retry action

---

# Screen 2: View Restaurant Screen

## Purpose
This screen shows the full details of one selected restaurant.

It allows admin to:
- view all restaurant data from database
- see cover image and full image gallery
- inspect cuisine data
- inspect metadata such as source/status
- disable restaurant
- re-enable restaurant if already disabled
- go to edit flow

## Main UI sections

### 1. Detail header
This is the top section of the screen.

#### Header should show
- cover image
- restaurant name
- main cuisine
- status badge
  - active or disabled

Optional later:
- source badge
- short address preview under title

### 2. Action buttons area
Required buttons:
- **Edit** button
- **Disable** button if active
- **Re-enable** button if disabled

#### Edit button
Purpose:
- navigate to Add/Edit Restaurant Screen in **edit mode**
- pass the selected restaurant data into the form

Why a new screen is chosen:
- easier form handling
- easier image upload flow
- easier multiple image management
- cleaner UX than dialog-based editing

#### Disable button
Purpose:
- soft delete restaurant
- set `isDisabled = true`

Behavior:
- show confirmation dialog first
- if confirmed, update restaurant status
- refresh UI after success
- button should disappear or switch to Re-enable afterward

#### Re-enable button
Purpose:
- restore disabled restaurant
- set `isDisabled = false`

Behavior:
- optional confirmation dialog
- refresh UI after success

### 3. Restaurant information section
This section should show all important database fields for the selected restaurant.

At minimum, display:
- `restaurant_Id`
- `restaurant_name`
- `address`
- `latitude`
- `longitude`
- `maps_url`
- `info_url`
- `source`
- `created_At`
- `main_cuisine_id` (preferably displayed as cuisine name)
- `isDisabled`

Recommended display approach:
- label-value format
- readable grouping
- clickable link behavior for URLs if convenient

### 4. Cuisine section
Show cuisine-related classification.

Should display:
- main cuisine
- extra cuisine tags from `Restaurant_Cuisine`

Purpose:
- allow admin to review restaurant classification clearly

### 5. Image gallery section
This screen should show **all images** for the restaurant.

#### Gallery behavior
- cover image shown prominently at header or top
- all images shown in gallery below
- clearly indicate which image is cover image

Optional later:
- tap image to preview larger version

## States required

### Loading state
When restaurant detail is being fetched:
- show loader
- do not show partial broken UI without explanation

### Missing image state
If no images exist:
- show placeholder or `No image available`

### Error state
If detail fetch fails:
- show error message
- allow retry or back navigation

---

# Screen 3: Add/Edit Restaurant Screen

## Purpose
This is a reusable form screen for both:
- adding a new restaurant
- editing an existing restaurant

This screen should support:
- restaurant basic info
- cuisine assignment
- image upload and image management
- setting cover image
- save/update submission

## Modes

### Add mode
Used when admin clicks **Add Restaurant**.

Behavior:
- form starts empty
- admin enters new restaurant data
- admin uploads image(s)
- admin chooses main cuisine and extra tags
- on save, create new restaurant and image rows

### Edit mode
Used when admin clicks **Edit** from View Restaurant Screen.

Behavior:
- existing restaurant data is prefilled
- existing images are shown
- admin can update fields
- admin can upload new images
- admin can change cover image
- admin can update cuisines

## Main form sections

### 1. Basic restaurant information
Fields should include:
- restaurant name
- address
- latitude
- longitude
- maps URL
- info URL
- source

#### Notes
- source may be editable or fixed depending on your admin policy
- if admin-created restaurant always uses source=`admin`, this can be hidden or preset instead of manual input

### 2. Cuisine section
This section handles restaurant classification.

#### Main cuisine
- required field
- choose from cuisines where `isPrimaryOption = true`
- should use dropdown / searchable dropdown / picker

#### Extra cuisine tags
- optional field
- allow multiple selection
- used to populate `Restaurant_Cuisine`

### 3. Image management section
This is one of the most important sections.

#### Required features
- upload one or more images
- preview selected/uploaded images
- show all existing images in edit mode
- mark exactly one image as cover image
- remove image from current form state if needed

#### Cover image behavior
- only one image can have `isCover = true`
- changing cover image should unset previous cover image for that restaurant
- cover image should be visually labeled in the UI

#### Suggested UI behavior
For each image card:
- preview image
- `Set as Cover` action
- `Remove` action
- cover badge if currently cover image

#### Upload behavior
- upload image file to Supabase Storage bucket
- store returned/public path/URL in `restaurant_image`
- associate image row with restaurant ID

### 4. Submission section
Buttons:
- Save / Create
- Update
- Cancel / Back

Behavior:
- add mode uses create action
- edit mode uses update action
- disable submit while request is in progress

## Validation rules

### Required validations
At minimum:
- restaurant name is required
- address is required
- main cuisine is required
- latitude and longitude must be valid numbers if entered
- if one of latitude / longitude is provided, the other should also be required

### URL validations
If `maps_url` or `info_url` is filled:
- validate as URL format if possible
- otherwise allow empty

### Image validation
For first version:
- image upload is allowed but not strictly required
- form should still be able to save without images unless product decision changes later

### Cover image validation
If images exist:
- exactly one should be marked cover
- if admin uploads first image and no cover selected yet, system may auto-assign first image as cover

## States required

### Loading state
When screen is initializing in edit mode:
- load restaurant info
- load images
- load cuisine options

### Submission loading state
When create/update is in progress:
- disable repeated submission
- show progress indicator

### Error state
If create/update/upload fails:
- show clear error message
- do not silently fail

### Success behavior
After successful save/update:
- navigate back appropriately or show success feedback
- ensure previous screens refresh their data

---

# Data / CRUD Behavior Summary

## Create restaurant
Should do:
1. insert restaurant basic data into `Restaurant`
2. set main cuisine
3. insert extra cuisine tags into `Restaurant_Cuisine`
4. upload images to Supabase Storage
5. insert `restaurant_image` rows
6. ensure one image is marked as cover if images exist

## Update restaurant
Should do:
1. update restaurant basic data
2. update main cuisine
3. update extra cuisine tags
4. upload newly added images
5. remove deleted images if needed
6. maintain exactly one cover image

## Disable restaurant
Should do:
1. show confirmation dialog
2. set `isDisabled = true`
3. update UI and dependent screens

## Re-enable restaurant
Should do:
1. optionally show confirmation dialog
2. set `isDisabled = false`
3. update UI and dependent screens

---

# Minimum Implementation Checklist

## Restaurant Management Screen
- [ ] header/app bar
- [ ] add restaurant button
- [ ] refresh button
- [ ] search bar
- [ ] filter controls
- [ ] scrollable list
- [ ] row thumbnail
- [ ] row status badge
- [ ] row tap to detail
- [ ] loading state
- [ ] empty state
- [ ] no-result state
- [ ] error state

## View Restaurant Screen
- [ ] cover image header
- [ ] full detail display
- [ ] all images gallery
- [ ] main cuisine display
- [ ] extra cuisine tags display
- [ ] edit button
- [ ] disable button
- [ ] re-enable button when disabled
- [ ] confirmation dialog for disable
- [ ] loading state
- [ ] missing image fallback
- [ ] error state

## Add/Edit Restaurant Screen
- [ ] reusable form for add and edit
- [ ] restaurant name field
- [ ] address field
- [ ] latitude field
- [ ] longitude field
- [ ] maps URL field
- [ ] info URL field
- [ ] source handling
- [ ] main cuisine selector
- [ ] extra cuisine multi-select
- [ ] image upload
- [ ] image preview
- [ ] set cover image
- [ ] remove image
- [ ] create/update submit
- [ ] validation
- [ ] loading state
- [ ] submission loading state
- [ ] error handling

---

# Notes
- This plan is focused on admin restaurant CRUD only.
- Restaurant approval list / conflict review belongs to the approval flow and can be handled separately.
- Search / BlindBox / home feed depend on this CRUD flow being stable first.
- The add/edit screen should be implemented in a way that is reusable and not duplicated.