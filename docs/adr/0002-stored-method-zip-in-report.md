# Store CSV photo companions as uncompressed ZIP inside Report

CSV `companionData` must be a real ZIP when photos exist. We considered adding ZIPFoundation. That would pull an SPM package into a CocoaPods app for STORE-only archives. `Compression.framework` cannot write ZIP. Report owns a stored-method writer: local file headers, central directory, end-of-central-directory, uncompressed entries, CRC-32. No ZIPFoundation, no new CocoaPods.

**Considered options:** ZIPFoundation; stop emitting a companion; Compression.framework (cannot write ZIP).

**Consequences:** photos are uncompressed in the archive. Do not add a zip package for this companion. Compressed ZIP would be a new decision.
