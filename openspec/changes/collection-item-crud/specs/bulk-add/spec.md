# Spec: Bulk Add

## Input
- Multi-line text field
- Each line separated by newline character
- Support paste from clipboard

## Processing
- Split input by newline
- Trim whitespace from each line
- Skip empty lines (after trimming)
- Deduplicate: if same text already exists in collection, skip (optional, user can override)

## Preview
- Show list of items to be created before confirming
- Show count: "X items will be added"
- Allow user to remove individual items from preview before confirming

## Creation
- Create Item for each valid line
- Set order values sequentially (append after existing items)
- Set collectionId to current collection
- Show success message: "X items added to [collection name]"
- Navigate back to collection detail screen
