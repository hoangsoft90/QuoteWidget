# Restore rollback safety (H6)

## Requirements

- Prove the restore path is atomic-in-practice: if `restoreFromBackup()`
  throws mid-way (e.g. item N has a null required field / wrong type causing
  insert failure), the entire Hive database returns to the state it had
  BEFORE the restore started.
- Prove the safety snapshot is created BEFORE `clearAll()` (the rollback
  source must be the old, complete state — never a half-cleared DB).
- No mixed state allowed: never old+new interleaved after a failed restore.

## Test

- Seed: 2 collections + items in Hive.
- Backup file: valid JSON header + collections + items where one item is
  malformed such that `Item.fromJson` succeeds but the Hive insert throws
  (e.g. a `createdAt` that parses but a null text — depends on model; if
  fromJson rejects, use an item whose required field is missing at the Hive
  adapter level).
- Run `restoreFromBackup` (or BackupService.importBackup overwrite path) →
  assert exception → assert DB == pre-restore state (old collections present,
  no partial new data).
- Assert snapshot file existed before the restore call (order check).