# Critical means Needs immediate attention

Stored Importance is one of two strings: "Needs immediate attention" or "Monitor". Older records, and CloudKit values the web already reads, can also say Critical, Repair, or Urgent. iOS used to treat every string except the exact "Needs immediate attention" as Monitor, so a stored Critical was Monitor on iOS and Needs immediate attention on the web.

Both platforms read Critical as Needs immediate attention. A missing value, Repair, Urgent, or any other word is Monitor. There is no batch rewrite of stored records. Persist writes only the two glossary strings, so the next iOS save of a Critical record stores "Needs immediate attention". A record that is never saved stays Critical on disk and still reads as Needs immediate attention.

**Considered options:** leave iOS matching only the exact "Needs immediate attention" string; add a third Importance; write the word Critical back on save.

**Consequences:** Callers use Importance and do not compare the raw strings. Screens keep their own marks. A report still breaks an Importance tie by location. Do not migrate stored rows in bulk. Do not write Critical, Repair, or Urgent back.
