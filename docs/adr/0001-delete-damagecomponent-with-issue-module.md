# Delete DamageComponent in the same pass as the Issue module

The Issue module owns the catalog tree and recorded projection. We considered keeping `DamageComponent` as a private UI adapter so the picker rewrite could wait. That would have left the avoided name on the selection seam and a second mutable tree beside the immutable catalog. We delete `DamageComponent` in this pass and give the picker Issue-owned nodes plus a selected set of path identities.

**Considered options:** keep `DamageComponent` as an internal adapter and rename later; delete it now.

**Consequences:** the picker is rewritten with the Issue module, not adapted in place. Future reviews should not reintroduce a parallel selectable tree.
